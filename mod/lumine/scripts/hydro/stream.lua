local DirectDamage = require("lumine_direct_damage")
local Rules = require("hydro/rules").stream
local Travel = require("hydro/travel")
local Targets = require("lumine_dendro_targets")
local STEP = 2 / 30

local function ApplyWet(target)
    if target:HasTag("moistureimmunity") then return end
    if target._lumine_hydro_wet then
        target._lumine_hydro_wet:Cancel()
    elseif target:HasTag("wet") then
        return
    else
        -- The vanilla wet multiplier reads this tag before looking for a moisture component.
        target:AddTag("wet")
    end
    target._lumine_hydro_wet = target:DoTaskInTime(Rules.wet_duration, function(inst)
        inst._lumine_hydro_wet = nil
        inst:RemoveTag("wet")
    end)
end

local function Splash(x, y, z)
    local fx = SpawnPrefab("waterstreak_burst")
    if fx then fx.Transform:SetPosition(x, y, z) end
end

local function HitSegment(owner, hit, x, z, dx, dz, moved)
    local half = Rules.width * .5
    local query = moved * .5 + half + MAX_PHYSICS_RADIUS
    for _, target in ipairs(Targets.Find(x + dx * moved * .5, z + dz * moved * .5, query)) do
        if not hit[target] and Targets.IsWaveTarget(owner, target) then
            local tx, ty, tz = target.Transform:GetWorldPosition()
            local ox, oz = tx - x, tz - z
            local ahead = ox * dx + oz * dz
            local along = math.max(0, -ahead, ahead - moved)
            local across = math.max(0, math.abs(ox * dz - oz * dx) - half)
            if along^2 + across^2 <= target:GetPhysicsRadius(0)^2 then
                hit[target] = true
                local health = target.components.health
                local before = health.currenthealth
                DirectDamage(owner, target, Rules.damage, nil, "lumine_hydro_stream")
                -- The public native GetAttacked wrapper does not return its hit result.
                if health.currenthealth < before then
                    if target:IsValid() and not health:IsDead() then ApplyWet(target) end
                    Splash(tx, ty + .45, tz)
                end
            end
        end
    end
end

return function(inst, hydro, aim)
    hydro:Track(inst)
    local owner = hydro.inst
    local x, _, z = owner.Transform:GetWorldPosition()
    local distance, hit = 0, {}
    local y = .6
    inst.Transform:SetPosition(x, y, z)
    inst.Transform:SetRotation(aim.rotation)
    inst:DoPeriodicTask(STEP, function(stream)
        if not hydro:CanUse() then stream:Remove() return end
        local requested = math.min(Rules.speed * STEP, Rules.range - distance)
        local travelled = Travel.SafeStep(x, z, aim.dx, aim.dz, requested, .23)
        if travelled > 0 then HitSegment(owner, hit, x, z, aim.dx, aim.dz, travelled) end
        if not stream:IsValid() then return end
        x, z = x + aim.dx * travelled, z + aim.dz * travelled
        distance = distance + travelled
        stream.Transform:SetPosition(x, y, z)
        if travelled < requested or distance >= Rules.range - .001 then
            Splash(x, y, z)
            stream:Remove()
        end
    end, 0)
end
