local ResolveDirection = require("flight/lumine_wind_aim")
local M = {STATE = "lumine_wind_dash", DISTANCE = 5, COOLDOWN = 6}

local SPEED = 25
local SAMPLE = .25
local BLOCKERS = {"wall", "structure", "largecreature", "epic", "tree", "boulder"}
local EXCLUDE = {"INLIMBO", "FX"}

local function IsBlocked(inst, x, z)
    local map = TheWorld.Map
    if not map:IsPassableAtPoint(x, 0, z) or not map:IsVisualGroundAtPoint(x, 0, z) then
        return true
    end
    local clearance = inst:GetPhysicsRadius(.5)
    for _, blocker in ipairs(TheSim:FindEntities(x, 0, z, MAX_PHYSICS_RADIUS + clearance, nil, EXCLUDE, BLOCKERS)) do
        if blocker ~= inst and blocker:IsValid() and blocker.Physics and blocker.Physics:IsActive() then
            local radius = blocker:GetPhysicsRadius(0)
            local bx, _, bz = blocker.Transform:GetWorldPosition()
            if radius > 0 and (bx - x)^2 + (bz - z)^2 < (radius + clearance)^2 then return true end
        end
    end
    return false
end

local function Scan(inst, x, z, dx, dz, distance)
    local clear = 0
    while clear < distance do
        local next_step = math.min(distance, clear + SAMPLE)
        if IsBlocked(inst, x + dx * next_step, z + dz * next_step) then break end
        clear = next_step
    end
    return clear
end

function M.Plan(inst, aim_x, aim_z)
    local x, y, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, inst.Transform:GetRotation(), aim_x, aim_z)
    local distance = Scan(inst, x, z, dx, dz, M.DISTANCE)
    if distance < .5 then return nil end
    return {x = x, y = y, z = z, dx = dx, dz = dz, distance = distance, safe = 0}
end

local function CheckPosition(inst, dash)
    local x, _, z = inst.Transform:GetWorldPosition()
    local travelled = (x - dash.x) * dash.dx + (z - dash.z) * dash.dz
    local progress = math.min(dash.distance, math.max(dash.safe, travelled))
    local safe_x, safe_z = dash.x + dash.dx * dash.safe, dash.z + dash.dz * dash.safe
    local step = progress - dash.safe
    local clear = Scan(inst, safe_x, safe_z, dash.dx, dash.dz, step)
    dash.safe = dash.safe + clear
    if clear >= step and travelled <= dash.distance + .001 and not IsBlocked(inst, x, z) then
        return x, z
    end
    -- Normal movement uses the physics motor. Correct only an unsafe or overshot position.
    local recovery = dash.safe
    repeat
        local rx, rz = dash.x + dash.dx * recovery, dash.z + dash.dz * recovery
        if not IsBlocked(inst, rx, rz) then
            inst.Physics:Teleport(rx, dash.y, rz)
            return
        end
        if recovery == 0 then return end
        recovery = math.max(0, recovery - SAMPLE)
    until false
end

local function Update(inst)
    local dash = inst.sg.statemem.dash
    local journey = inst.components.luminejourney
    if not journey or journey.active_element ~= "wind" or not journey:CanResonate("wind")
        or inst.components.health:IsDead() or inst:HasTag("playerghost") then
        inst.sg:GoToState("idle")
        return
    end

    local x, z = CheckPosition(inst, dash)
    if x == nil then
        inst.sg:GoToState("idle")
        return
    end
    local remaining = dash.distance - dash.safe
    local available = Scan(inst, x, z, dash.dx, dash.dz, math.min(remaining, SPEED * FRAMES))
    if remaining < .025 or available < .025 then
        inst.sg:GoToState("idle")
    else
        inst.Physics:SetMotorVelOverride(available / FRAMES, 0, 0)
    end
end

function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nopredict", "nomorph", "lumine_wind_dodging"},
        onenter = function(inst, dash)
            inst.sg.statemem.dash = dash
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst:ForceFacePoint(dash.x + dash.dx, dash.y, dash.z + dash.dz)
            inst.AnimState:PlayAnimation("atk_leap_lag")
            inst.Physics:SetMotorVelOverride(math.min(SPEED, dash.distance / FRAMES), 0, 0)
            inst.sg:SetTimeout(dash.distance / SPEED + 3 * FRAMES)
        end,
        onupdate = Update,
        ontimeout = function(inst)
            CheckPosition(inst, inst.sg.statemem.dash)
            inst.sg:GoToState("idle")
        end,
        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
        end,
    })
end

function M.AttachDodge(inst)
    local combat = inst.components.combat
    local attack = combat.GetAttacked_Internal
    -- Keep the normal damage pipeline for other states, including environmental health deltas.
    function combat:GetAttacked_Internal(attacker, damage, weapon, stimuli, spdamage, ...)
        if inst.sg and inst.sg:HasStateTag("lumine_wind_dodging")
            and attacker ~= nil and damage ~= nil and (damage > 0 or spdamage ~= nil) then
            inst:PushEvent("attackdodged", attacker)
            return false
        end
        return attack(self, attacker, damage, weapon, stimuli, spdamage, ...)
    end
end

return M
