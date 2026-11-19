local M = {STATE = "lumine_wind_tornado_cast", COOLDOWN = 35}

local STAFF_FRAMES = 4
-- A normal spear uses atk_pre/atk and applies its hit on frame 8.
-- At 1.6x speed, that frame arrives five ticks after the spear motion starts.
local SPEAR_SPEED = 1.6
local CONTACT_FRAME = STAFF_FRAMES + 8 / SPEAR_SPEED
local RECOVERY_SPEED = 2.4
local RECOVERY_FRAME = 17

local function Finish(inst)
    inst.sg:GoToState("idle")
end

function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nopredict", "nomorph", "lumine_wind_tornado_casting"},
        onenter = function(inst, aim)
            inst.sg.statemem.aim = aim
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            local x, y, z = inst.Transform:GetWorldPosition()
            inst:ForceFacePoint(x + aim.dx, y, z + aim.dz)
            inst.AnimState:PlayAnimation("staff_pre")
            inst.AnimState:SetDeltaTimeMultiplier(2)
            inst.sg:SetTimeout(RECOVERY_FRAME * FRAMES)
        end,
        timeline = {
            FrameEvent(STAFF_FRAMES, function(inst)
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                inst.AnimState:SetDeltaTimeMultiplier(SPEAR_SPEED)
            end),
            FrameEvent(CONTACT_FRAME, function(inst)
                inst.AnimState:SetDeltaTimeMultiplier(RECOVERY_SPEED)
                local aim = inst.sg.statemem.aim
                inst.sg.statemem.aim = nil
                local wind = inst.components.luminewind
                if not wind or not aim then return end
                local success, reason = wind:ReleaseTornado(aim)
                if success then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
                elseif reason and inst.components.talker then
                    inst.components.talker:Say(reason)
                end
            end),
        },
        ontimeout = Finish,
        onexit = function(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1)
        end,
    })
end

return M
