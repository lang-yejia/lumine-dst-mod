local Rules = require("cryo/rules")
local Targets = require("lumine_dendro_targets")
local Freeze = require("cryo/freeze")
local DirectDamage = require("lumine_direct_damage")
local M = {}

function M.Area(caster, x, z, radius, damage, duration)
    for _, target in ipairs(Targets.Find(x, z, radius + MAX_PHYSICS_RADIUS)) do
        local reach = radius + target:GetPhysicsRadius(0)
        if Targets.IsWaveTarget(caster.inst, target) and target:GetDistanceSqToPoint(x, 0, z) <= reach * reach then
            if damage > 0 then DirectDamage(caster.inst, target, damage, nil, "lumine_cryo") end
            if target:IsValid() and not target.components.health:IsDead() then Freeze(caster, target, duration) end
        end
    end
end

function M.Pillars(caster, x, z)
    for index = 1, 3 do
        local angle = index * TWOPI / 3
        local fx = SpawnPrefab("deerclops_icespike_fx")
        if fx then
            fx.Transform:SetPosition(x + .65 * math.cos(angle), 0, z + .65 * math.sin(angle))
            fx:RestartFX(index == 1, index)
            caster:TrackFX(fx)
        end
    end
    caster.inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/ice_small")
    M.Area(caster, x, z, Rules.infusion.radius, Rules.infusion.damage, Rules.infusion.freeze)
end

function M.Impact(caster, projectile, point)
    projectile:Remove()
    if not caster:CanUse() then return end
    local impact = SpawnPrefab("lumine_cryo_impact")
    if impact then
        impact.Transform:SetPosition(point.x, 0, point.z)
        caster:TrackFX(impact)
    end
    caster.inst.SoundEmitter:PlaySound("dontstarve/common/break_iceblock")
    M.Area(caster, point.x, point.z, Rules.meteor.radius, Rules.meteor.damage, Rules.meteor.freeze)
    if not caster:CanUse() then return end
    caster:EndField()
    local field = SpawnPrefab("lumine_cryo_field")
    if not field then return end
    field.Transform:SetPosition(point.x, 0, point.z)
    caster:TrackFX(field)
    caster.field = field
    caster.field_until = GetTime() + Rules.field.duration
    caster.inst._lumine_cryo_field_until:set(caster.field_until)
    field:ListenForEvent("onremove", function()
        if caster.field == field then
            caster.field = nil
            caster.field_until = 0
            caster.inst._lumine_cryo_field_until:set(0)
        end
    end)
    field:DoTaskInTime(Rules.field.duration, field.Remove)
end

function M.Launch(caster, projectile, point)
    local x, y, z = caster.inst.Transform:GetWorldPosition()
    local distance = math.sqrt((point.x - x)^2 + (point.z - z)^2)
    local duration = math.max(.35, distance / 18)
    local elapsed = 0
    projectile.Transform:SetPosition(x, y + 1.7, z)
    projectile.Transform:SetRotation(caster.inst.Transform:GetRotation())
    projectile:DoPeriodicTask(FRAMES, function()
        if not caster:CanUse() then projectile:Remove() return end
        elapsed = elapsed + FRAMES
        local t = math.min(1, elapsed / duration)
        projectile.Transform:SetPosition(x + (point.x - x) * t,
            (y + 1.7) * (1 - t) + 2 * math.sin(t * PI), z + (point.z - z) * t)
        if t >= 1 then M.Impact(caster, projectile, point) end
    end)
end

return M
