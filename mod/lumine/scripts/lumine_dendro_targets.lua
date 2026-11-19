local M = {}
local EXCLUDED = {"player", "companion", "pet", "FX", "INLIMBO", "wall", "structure",
    "lunarplanttentacle", "shadowminion"}
local UNTARGETABLE = {"notarget", "noattack", "flight", "invisible"}
local FIND_EXCLUDED = {unpack(EXCLUDED)}
for _, tag in ipairs(UNTARGETABLE) do FIND_EXCLUDED[#FIND_EXCLUDED + 1] = tag end

local function IsHostile(owner, target, landed_hit)
    if not target or not target:IsValid() or target:HasAnyTag(unpack(EXCLUDED)) then
        return false
    end
    if not landed_hit and (not target.entity:IsVisible() or target:HasAnyTag(unpack(UNTARGETABLE))) then
        return false
    end
    local c = target.components
    local leader = c.follower and c.follower.leader
    return c.health ~= nil and (landed_hit or not c.health:IsDead()) and c.combat ~= nil
        and (not leader or not leader:HasTag("player"))
        and not owner.components.combat:IsAlly(target)
        and (target:HasAnyTag("monster", "hostile", "epic") or c.combat.target == owner)
end

function M.IsHitTarget(owner, target)
    -- onhitother runs after a lethal hit can set the target's death tags.
    return IsHostile(owner, target, true)
end

function M.IsEnemy(owner, target)
    return IsHostile(owner, target) and not target:HasTag("tree") and owner.components.combat:CanTarget(target)
end

function M.IsWaveTarget(owner, target)
    -- The melee target check also limits elevation to the held weapon's range.
    -- A ground wave uses the target's combat eligibility and its ground footprint.
    return IsHostile(owner, target) and not target:HasAnyTag("spawnprotection", "debugnoattack")
        and not target.components.health:IsInvincible() and target.components.combat:CanBeAttacked(owner)
end

function M.Find(x, z, radius)
    return TheSim:FindEntities(x, 0, z, radius, {"_combat"}, FIND_EXCLUDED)
end

return M
