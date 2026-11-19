local DirectDamage = require("lumine_direct_damage")
local Rules = require("hydro/rules").bubble
local Travel = require("hydro/travel")
local Taunt = require("hydro/taunt")
local Targets = require("lumine_dendro_targets")
local STEP = .1

local function SetCondition(bubble, percent)
    if percent <= .25 then
        bubble.AnimState:SetMultColour(.86, .94, 1, .85)
        bubble.AnimState:SetDeltaTimeMultiplier(1.9)
    elseif percent <= .55 then
        bubble.AnimState:SetMultColour(.94, .98, 1, .93)
        bubble.AnimState:SetDeltaTimeMultiplier(1.4)
    else
        bubble.AnimState:SetMultColour(1, 1, 1, 1)
        bubble.AnimState:SetDeltaTimeMultiplier(1)
    end
end

local function StopMoving(bubble)
    local data = bubble.hydro
    if data.move_task then
        data.move_task:Cancel()
        data.move_task = nil
    end
    bubble.Physics:ClearMotorVelOverride()
    bubble.Physics:Stop()
end

local function Move(bubble)
    local data = bubble.hydro
    if not data.caster:CanUse() then bubble:Remove() return end
    local fraction = 1 - (GetTime() - data.started) / Rules.brake_time
    if fraction <= .0001 then StopMoving(bubble) return end
    local x, _, z = bubble.Transform:GetWorldPosition()
    local dx, dz = data.aim.dx, data.aim.dz
    local step = Travel.SafeStep(x, z, dx, dz, STEP * Rules.speed * fraction, .65)
    if step > 0 then
        bubble.Physics:SetMotorVelOverride(step / STEP, 0, 0)
    else
        StopMoving(bubble)
    end
end

local function Splash(name, x, z, scale)
    local fx = SpawnPrefab(name)
    if fx then
        fx.Transform:SetPosition(x, .22, z)
        if scale then fx.Transform:SetScale(scale, scale, scale) end
    end
end

local function Damage(bubble, radius, damage, burst)
    local data = bubble.hydro
    local owner = data.caster.inst
    local x, _, z = bubble.Transform:GetWorldPosition()
    for _, target in ipairs(Targets.Find(x, z, radius + MAX_PHYSICS_RADIUS)) do
        if not bubble:IsValid() or not data.caster:CanUse() or (data.ending and not burst) then return end
        if Targets.IsWaveTarget(owner, target) then
            local reach = radius + target:GetPhysicsRadius(0)
            if target:GetDistanceSqToPoint(x, 0, z) <= reach * reach then
                local combat = target.components.combat
                local previous = combat.target
                DirectDamage(burst and owner or bubble, target, damage, nil,
                    burst and "lumine_hydro_blast" or "lumine_hydro_pulse")
                if not burst and target:IsValid() and combat.target == bubble and data.taunted[target] == nil then
                    data.taunted[target] = (previous ~= bubble and previous) or false
                end
            end
        end
    end
end

local function Pulse(bubble)
    local data = bubble.hydro
    if data.ending then return end
    if not data.caster:CanUse() then bubble:Remove() return end
    Taunt.Scan(bubble)
    local x, _, z = bubble.Transform:GetWorldPosition()
    Splash("waterstreak_burst", x, z, 1.4)
    if bubble.components.health:GetPercent() <= .55 then
        Splash("crab_king_bubble2", x, z, 1.3)
    end
    Damage(bubble, Rules.range, Rules.damage, false)
end

local function Finish(bubble)
    local data = bubble.hydro
    if data.ending then return end
    data.ending = true
    bubble:AddTag("notarget")
    StopMoving(bubble)
    for _, name in ipairs({"pulse_task", "expire_task"}) do
        if data[name] then data[name]:Cancel() data[name] = nil end
    end
    Taunt.Clear(bubble)
    if data.caster:CanUse() then
        local x, _, z = bubble.Transform:GetWorldPosition()
        Splash("waterstreak_burst", x, z, 2.55)
        Splash("crab_king_bubble2", x, z, 2.2)
        Damage(bubble, Rules.blast_range, Rules.blast_damage, true)
    end
    -- A lethal hit is still inside the stock health/combat callback stack.
    if bubble:IsValid() then
        bubble:Hide()
        bubble:DoTaskInTime(0, bubble.Remove)
    end
end

return function(bubble, caster, aim)
    local data = {caster = caster, aim = aim, taunted = {}, started = GetTime()}
    bubble.hydro = data
    caster:Track(bubble)
    local x, _, z = caster.inst.Transform:GetWorldPosition()
    local start = Travel.SafeStep(x, z, aim.dx, aim.dz, 1.15, .65)
    bubble.Physics:Teleport(x + aim.dx * start, 0, z + aim.dz * start)
    bubble.Transform:SetRotation(aim.rotation)
    data.move_task = bubble:DoPeriodicTask(STEP, Move)
    Move(bubble)
    data.expire_task = bubble:DoTaskInTime(Rules.duration, Finish)
    data.pulse_task = bubble:DoPeriodicTask(Rules.interval, Pulse)
    bubble:ListenForEvent("healthdelta", function(_, delta)
        if not data.ending then
            SetCondition(bubble, delta.newpercent)
            caster.inst._lumine_hydro_bubble_hp:set(math.ceil(delta.newpercent * Rules.health))
            local anim = bubble.AnimState
            if delta.newpercent < delta.oldpercent and not anim:IsCurrentAnimation("orb_hit") then
                anim:PlayAnimation("orb_hit")
                anim:PushAnimation("orb", true)
            end
        end
    end)
    bubble:ListenForEvent("death", Finish)
    bubble:ListenForEvent("onremove", function()
        bubble:AddTag("notarget")
        Taunt.Clear(bubble)
    end)
    Taunt.Scan(bubble)
end
