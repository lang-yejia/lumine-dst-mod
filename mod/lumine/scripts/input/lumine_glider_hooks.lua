local G = GLOBAL
local Glider = G.require("flight/lumine_glider")
Glider.Install(G, AddStategraphState)
AddModRPCHandler("LumineMod", "GliderToggle", Glider.Toggle)
AddModRPCHandler("LumineMod", "GliderMove", Glider.SetDirection)
AddModRPCHandler("LumineMod", "GliderEat", Glider.Eat)

local function Active(inst)
    return inst.lumine_glider_phase ~= nil and inst.lumine_glider_phase:value() > 0
end

local function InGame(player)
    if player == nil or not player:IsValid() or player.prefab ~= "lumine"
        or player:HasTag("playerghost") or player:HasTag("INLIMBO") or G.IsPaused()
        or (player.replica and player.replica.health and player.replica.health:IsDead())
        or G.TheFrontEnd.textProcessorWidget ~= nil then return false end
    local screen = G.TheFrontEnd:GetActiveScreen()
    local controller = player.components.playercontroller
    return screen ~= nil and screen.name == "HUD" and controller ~= nil and controller:IsEnabled()
end

-- Inventory tiles call the replica before the native busy-state checks. Route
-- food through a validated server request without entering grounded eat states.
AddClassPostConstruct("components/inventory_replica", function(self)
    for _, method in ipairs({ "UseItemFromInvTile", "ControllerUseItemOnSelfFromInvTile" }) do
        local old = self[method]
        self[method] = function(inventory, item, ...)
            local owner = inventory.inst
            if Active(owner) then
                if owner.lumine_glider_phase:value() == 2 and item ~= nil and item:IsValid()
                    and inventory:GetActiveItem() == nil then
                    if G.TheWorld.ismastersim then return Glider.Eat(owner, item) end
                    if owner == G.ThePlayer and InGame(owner) then
                        G.SendModRPCToServer(G.GetModRPC("LumineMod", "GliderEat"), item)
                    end
                end
                return
            end
            return old(inventory, item, ...)
        end
    end
end)

-- Native prediction/ground walking must not race the authoritative flight motor.
-- Only the local owner samples controls; remote clients just display server poses.
AddClassPostConstruct("components/playercontroller", function(self)
    local update, control = self.OnUpdate, self.OnControl
    self.OnControl = function(controller, ...)
        if Active(controller.inst) then return true end
        return control(controller, ...)
    end
    self.OnUpdate = function(controller, dt)
        local inst = controller.inst
        if not Active(inst) then
            controller._lumine_flight_input = nil
            return update(controller, dt)
        end
        controller.attack_buffer = nil
        -- Native OnUpdate/OnLeftUp normally release drag focus. Both are
        -- bypassed in flight, so discard held actions and unlock inventory here.
        if controller.actionholding or controller.actionholdtime ~= nil then
            controller:ClearActionHold()
        end
        if controller.draggingonground then
            controller.draggingonground = false
            if inst == G.ThePlayer and not G.TheNet:IsDedicated() then
                G.TheFrontEnd:LockFocus(false)
            end
        end
        controller.startdragtime = nil
        -- Drop ground movement queued before takeoff, including a remote key-up
        -- swallowed while flying. Landing must not resume an old walk command.
        controller.remote_vector.y = 0
        controller.remote_controls = {}
        controller.directwalking, controller.dragwalking, controller.predictwalking = false, false, false
        controller.recent_bufferedaction.act = nil
        controller:ClearRemotePredictData()
        if inst ~= G.ThePlayer or G.TheNet:IsDedicated() then return end
        local x, z = 0, 0
        if inst.lumine_glider_phase:value() == 2 and InGame(inst) then
            local right = G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_RIGHT)
                - G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_LEFT)
            local up = G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_UP)
                - G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_DOWN)
            if math.abs(right) >= G.TUNING.CONTROLLER_DEADZONE_RADIUS or math.abs(up) >= G.TUNING.CONTROLLER_DEADZONE_RADIUS then
                local dir = (G.TheCamera:GetRightVec() * right - G.TheCamera:GetDownVec() * up):GetNormalized()
                x, z = dir.x, dir.z
            end
        end
        local last, now = controller._lumine_flight_input, G.GetTime()
        if not last or math.abs(last.x - x) + math.abs(last.z - z) > .001 or now - last.t >= .2 then
            controller._lumine_flight_input = { x = x, z = z, t = now }
            if G.TheWorld.ismastersim then Glider.SetDirection(inst, x, z)
            else G.SendModRPCToServer(G.GetModRPC("LumineMod", "GliderMove"), x, z) end
        end
    end
end)

-- The exploration skill button in our HUD sends GliderToggle.
