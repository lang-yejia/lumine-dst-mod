local DirectDamage = require("lumine_direct_damage")
local Rules = require("lumine_dendro_rules")
local Targets = require("lumine_dendro_targets")
local ROOT, BOMB = Rules.ROOT, Rules.BOMB
local KEY = "lumine_dendro_root"
local WAVE_ROWS = {
    {fraction = .26, count = 3, delay = 0},
    {fraction = .59, count = 5, delay = .06},
    {fraction = .96, count = 7, delay = .12},
}

local function SpawnBomb(caster, x, y, z)
    local bomb = SpawnPrefab("lumine_dendro_sporebomb")
    if not bomb then return end
    caster:Track(bomb)
    bomb:ListenForEvent("onremove", function() caster.effects[bomb] = nil end)
    bomb.Transform:SetPosition(x, y, z)
    bomb:DoTaskInTime(BOMB.delay, function(inst)
        if not caster:CanUse() then
            inst:Remove()
            return
        end
        inst:Pop()
        for _, target in ipairs(Targets.Find(x, z, BOMB.radius + MAX_PHYSICS_RADIUS)) do
            if Targets.IsWaveTarget(caster.inst, target) then
                local tx, _, tz = target.Transform:GetWorldPosition()
                local reach = BOMB.radius + target:GetPhysicsRadius(0)
                if (tx - x)^2 + (tz - z)^2 <= reach^2 then
                    DirectDamage(caster.inst, target, BOMB.damage, nil, "lumine_dendro_bomb")
                end
            end
        end
    end)
end

local function ApplyRoot(caster, target)
    -- Do not let a second wave replace the pending hit.
    if target._lumine_dendro_root then return end
    local fx = SpawnPrefab("lumine_dendro_roots")
    if not fx then return end
    caster:Track(fx)
    target._lumine_dendro_root = fx
    fx.entity:SetParent(target.entity)
    local scale = 1 + math.min(target:GetPhysicsRadius(0), 2.5) * .24
    fx.Transform:SetScale(scale, scale, scale)
    local locomotor = target.components.locomotor
    if locomotor then locomotor:SetExternalSpeedMultiplier(fx, KEY, ROOT.speed) end

    local function Clear()
        target._lumine_dendro_root = nil
        caster.effects[fx] = nil
        if target.components.locomotor == locomotor and locomotor then
            locomotor:RemoveExternalSpeedMultiplier(fx, KEY)
        end
    end
    fx:ListenForEvent("onremove", Clear)
    local function Remove() if fx:IsValid() then fx:Remove() end end
    fx:ListenForEvent("onremove", Remove, target)
    fx:ListenForEvent("enterlimbo", Remove, target)
    fx:ListenForEvent("newstate", function()
        if target.sg and target.sg:HasStateTag("flight") then Remove() end
    end, target)
    fx:ListenForEvent("death", function() fx:DoTaskInTime(0, Remove) end, target)
    fx:ListenForEvent("attacked", function(_, data)
        if not data or data.redirected or not data.attacker or not data.attacker:IsValid()
            or not data.attacker.components.combat or (data.damageresolved or 0) <= 0
            or data.stimuli == "lumine_dendro_poison" or data.stimuli == "lumine_dendro_bomb" then
            return
        end
        local x, y, z = target.Transform:GetWorldPosition()
        Remove()
        if caster:CanUse() then SpawnBomb(caster, x, y, z) end
    end, target)
    fx:DoTaskInTime(ROOT.duration, Remove)
end

local function TouchesSector(ox, oz, aim, cos_half, sin_half, radius)
    local forward = ox * aim.dx + oz * aim.dz
    local side = math.abs(ox * aim.dz - oz * aim.dx)
    local distance_sq = forward^2 + side^2
    if forward >= 0 and side * cos_half <= forward * sin_half + 1e-6 then
        return distance_sq <= (ROOT.range + radius)^2 + 1e-6
    end
    -- Outside the central angle, the closest point lies on the nearer finite edge.
    local along_edge = math.max(0, math.min(ROOT.range, forward * cos_half + side * sin_half))
    local df, ds = forward - along_edge * cos_half, side - along_edge * sin_half
    return df^2 + ds^2 <= radius^2 + 1e-6
end

local function ShowRow(caster, x, z, aim, half, row)
    if not caster:CanUse() then return end
    local map = TheWorld.Map
    for step = 0, row.count - 1 do
        local angle = (2 * step / (row.count - 1) - 1) * half
        local c, s = math.cos(angle), math.sin(angle)
        local px = x + ROOT.range * row.fraction * (aim.dx * c - aim.dz * s)
        local pz = z + ROOT.range * row.fraction * (aim.dz * c + aim.dx * s)
        if map:IsValidTileAtPoint(px, 0, pz) then
            local pulse = SpawnPrefab("lumine_dendro_roots")
            if pulse then
                pulse.Transform:SetPosition(px, 0, pz)
                pulse.AnimState:SetDeltaTimeMultiplier(1.8)
                if map:IsOceanTileAtPoint(px, 0, pz) then pulse.AnimState:Hide("soil01") end
                caster:Track(pulse)
                pulse:ListenForEvent("onremove", function() caster.effects[pulse] = nil end)
                pulse:DoTaskInTime(.45, pulse.Retract)
            end
        end
    end
end

return function(caster, aim)
    local inst = caster.inst
    local x, _, z = inst.Transform:GetWorldPosition()
    local half = ROOT.half_angle * DEGREES
    local cos_half, sin_half = math.cos(half), math.sin(half)
    for _, target in ipairs(Targets.Find(x, z, ROOT.range + MAX_PHYSICS_RADIUS)) do
        if Targets.IsWaveTarget(inst, target) then
            local tx, _, tz = target.Transform:GetWorldPosition()
            if TouchesSector(tx - x, tz - z, aim, cos_half, sin_half, target:GetPhysicsRadius(0)) then
                ApplyRoot(caster, target)
            end
        end
    end
    for _, row in ipairs(WAVE_ROWS) do
        if row.delay == 0 then
            ShowRow(caster, x, z, aim, half, row)
        else
            inst:DoTaskInTime(row.delay, function() ShowRow(caster, x, z, aim, half, row) end)
        end
    end
end
