local Rules = require("pyro/rules")
local Targets = require("lumine_dendro_targets")
local Travel = require("hydro/travel")
local DirectDamage = require("lumine_direct_damage")
local Scorch = require("pyro/scorch")

local M = {}

local function HitArea(owner, x, z, radius, damage, stimuli, on_hit)
    for _, target in ipairs(Targets.Find(x, z, radius + MAX_PHYSICS_RADIUS)) do
        local reach = radius + target:GetPhysicsRadius(0)
        if Targets.IsWaveTarget(owner, target) and target:GetDistanceSqToPoint(x, 0, z) <= reach * reach then
            DirectDamage(owner, target, damage, nil, stimuli)
            if on_hit then on_hit(owner, target) end
        end
    end
end

local function PulseRing(ring)
    if GetTime() >= ring.ends_at then return end
    local owner = ring.caster
    local x, _, z = owner.Transform:GetWorldPosition()
    HitArea(owner, x, z, Rules.ring.radius, Rules.ring.damage, "lumine_pyro_ring", Scorch.Apply)
end

function M.StartRing(owner, ring)
    ring.caster = owner
    ring.ends_at = GetTime() + Rules.ring.duration
    owner:AddChild(ring)
    ring:DoPeriodicTask(Rules.ring.interval, PulseRing, 0)
    ring:DoTaskInTime(Rules.ring.duration, ring.Remove)
end

local function FirstContact(x, z, dx, dz, length, owner)
    local nearest
    local radius = Rules.orb.contact
    local half = length * .5
    for _, target in ipairs(Targets.Find(x + dx * half, z + dz * half, half + radius + MAX_PHYSICS_RADIUS)) do
        if Targets.IsWaveTarget(owner, target) then
            local tx, _, tz = target.Transform:GetWorldPosition()
            local offset_x, offset_z = tx - x, tz - z
            local along = offset_x * dx + offset_z * dz
            local sideways = offset_x * dz - offset_z * dx
            local reach = radius + target:GetPhysicsRadius(0)
            local span_sq = reach * reach - sideways * sideways
            if span_sq >= 0 then
                local span = math.sqrt(span_sq)
                local entry = math.max(0, along - span)
                if along + span >= 0 and entry <= length and (nearest == nil or entry < nearest) then
                    nearest = entry
                end
            end
        end
    end
    return nearest
end

local function Explode(orb, x, z)
    orb.move_task:Cancel()
    orb.move_task = nil
    orb:PlayImpact()
    local ground = SpawnPrefab("lumine_pyro_impact_ground")
    if ground then ground.Transform:SetPosition(x, orb.ground_y, z) end
    HitArea(orb.caster, x, z, Rules.orb.radius, orb.damage, "lumine_pyro_orb")
end

local function AdvanceOrb(orb, stride)
    local owner = orb.caster
    local pyro = owner:IsValid() and owner.components.luminepyro
    if not pyro or not pyro:CanMaintain() then orb:Remove() return end

    local x, _, z = orb.Transform:GetWorldPosition()
    local dx, dz = orb.dx, orb.dz
    local step = math.min(orb.remaining, stride or Rules.orb.speed * FRAMES)
    local safe = Travel.SafeStep(x, z, dx, dz, step, Rules.orb.contact, true)
    local hit = FirstContact(x, z, dx, dz, safe, owner)
    local distance = hit or safe
    x, z = x + dx * distance, z + dz * distance
    orb.remaining = orb.remaining - distance
    local descent = math.min(1, (Rules.orb.range - orb.remaining) / 4)
    local height = orb.launch_height + (Rules.orb.cruise_height - orb.launch_height) * descent
    orb.Transform:SetPosition(x, orb.ground_y + height, z)
    if hit ~= nil or safe < step then Explode(orb, x, z) return end
    if orb.remaining <= 0 then orb:Remove() end
end

function M.LaunchOrb(owner, orb, damage, dx, dz, rotation)
    local x, y, z = owner.Transform:GetWorldPosition()
    local _, hand_y, _, found = owner.AnimState:GetSymbolPosition("swap_object", 0, 0, 0)
    orb.ground_y = y
    orb.launch_height = found and math.max(1.12, math.min(1.48, hand_y - y)) or Rules.orb.launch_height
    orb.caster, orb.damage = owner, damage
    orb.dx, orb.dz = dx, dz
    orb.remaining = Rules.orb.range
    orb.Transform:SetPosition(x, y + orb.launch_height, z)
    orb.Transform:SetRotation(rotation)
    orb.move_task = orb:DoPeriodicTask(FRAMES, AdvanceOrb)
    -- Sweep the short muzzle offset too, so near enemies or walls still intercept the shot.
    AdvanceOrb(orb, Rules.orb.launch_offset)
end

return M
