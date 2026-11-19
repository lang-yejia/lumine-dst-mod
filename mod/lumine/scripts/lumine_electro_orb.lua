local DirectDamage = require("lumine_direct_damage")
local Rules = require("lumine_energy_rules").ELECTRO
local FX = require("lumine_electro_fx")
local BOUNCE_SPEED = 10
local BOUNCE_DELAY = .1
local MUST_TAGS = {"_combat"}
local EXCLUDE_TAGS = {
    "INLIMBO", "wall", "structure", "notarget", "player", "companion",
    "flight", "invisible", "noattack", "hiding",
}

local function Tint(inst)
    inst.AnimState:SetMultColour(.68, .23, 1, 1)
    inst.AnimState:SetAddColour(.12, .02, .26, 0)
end

local function CanStrike(caster)
    return caster and caster:IsValid() and not caster:HasTag("playerghost")
        and caster.components.combat ~= nil
        and caster.components.health and not caster.components.health:IsDead()
end

local function FindNextTarget(orb, caster, previous, x, z)
    local combat = caster.components.combat
    local best, best_hit, best_distance
    for _, candidate in ipairs(TheSim:FindEntities(x, 0, z, Rules.ORB_BOUNCE_RANGE, MUST_TAGS, EXCLUDE_TAGS)) do
        if candidate ~= previous and candidate ~= caster and candidate:IsValid() and candidate.entity:IsVisible() then
            local components = candidate.components
            if components.health and not components.health:IsDead() and components.combat
                and (candidate:HasAnyTag("hostile", "monster")
                    or combat.target == candidate or components.combat.target == caster)
                and combat:CanTarget(candidate) and not combat:IsAlly(candidate) then
                local last_hit = orb.lumine_hit_order[candidate] or 0
                local distance = candidate:GetDistanceSqToPoint(x, 0, z)
                if best == nil or last_hit < best_hit or (last_hit == best_hit and distance < best_distance) then
                    best, best_hit, best_distance = candidate, last_hit, distance
                end
            end
        end
    end
    return best
end

local function Bounce(orb, previous, x, z)
    local caster = orb.lumine_caster
    local target = CanStrike(caster) and FindNextTarget(orb, caster, previous, x, z)
    if not target then orb:Remove() return end

    orb.Physics:Teleport(x, .6, z)
    orb:Show()
    local projectile = orb.components.projectile
    projectile:SetSpeed(BOUNCE_SPEED)
    projectile:SetBounced(true)
    projectile.overridestartpos = Vector3(x, .6, z)
    orb.lumine_inflight = true
    projectile:Throw(orb, target, caster)
end

local function Hit(orb, _, target)
    if not orb.lumine_inflight then return end
    orb.lumine_inflight = false
    local caster = orb.lumine_caster
    if not CanStrike(caster) or not target or not target:IsValid() then
        orb:Remove()
        return
    end

    local x, y, z = orb.Transform:GetWorldPosition()
    local blast = SpawnPrefab("brilliance_projectile_blast_fx")
    if blast then
        FX.TintImpact(blast)
        blast.AnimState:SetSymbolMultColour("light_bar", .78, .35, 1, .5)
        blast.Transform:SetPosition(x, y, z)
    end
    local components = target.components
    if components.combat and components.health and not components.health:IsDead()
        and not caster.components.combat:IsAlly(target) then
        DirectDamage(caster, target, Rules.ORB_DAMAGE, nil, "electric")
    end
    if not orb:IsValid() then return end
    orb.lumine_hits = orb.lumine_hits + 1
    orb.lumine_hit_order[target] = orb.lumine_hits
    if orb.lumine_hits >= Rules.ORB_MAX_HITS then
        orb:Remove()
    else
        orb:Hide()
        orb:DoTaskInTime(BOUNCE_DELAY, Bounce, target, x, z)
    end
end

return function(caster, target, energy, cost)
    local orb = SpawnPrefab("brilliance_projectile_fx")
    if not orb then return false end
    if not energy:SpendAmount(cost) then orb:Remove() return false end
    local x, _, z = caster.Transform:GetWorldPosition()
    orb.Transform:SetPosition(x, .6, z)
    Tint(orb)
    orb.lumine_caster = caster
    orb.lumine_hits, orb.lumine_hit_order = 0, {}
    orb.lumine_inflight = true
    local projectile = orb.components.projectile
    projectile:SetOnThrownFn(nil)
    projectile:SetOnHitFn(Hit)
    -- Using the orb as the projectile's owner suppresses the automatic weapon attack.
    -- The callback applies one fixed bonus hit without triggering another weapon swing.
    projectile:Throw(orb, target, caster)
    return true
end
