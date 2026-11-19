local M = {
    SCAN_RADIUS = 13,
    HUT_DANGER_RADIUS = 6,
    WORKER_DANGER_RADIUS = 5,
    CALM_DELAY = 3,
}

local function IsBeeboxBee(entity)
    if not entity:HasTag("bee") then return false end
    local seeker = entity.components.homeseeker
    local home = seeker ~= nil and seeker:GetHome() or nil
    return home ~= nil and home:IsValid() and home:HasTag("beebox")
end

function M.IsThreat(entity)
    if entity == nil or not entity:IsValid() or entity:HasTag("INLIMBO")
        or entity:HasTag("player") or IsBeeboxBee(entity) then return false end
    local combat, health = entity.components.combat, entity.components.health
    if combat == nil or health == nil or health:IsDead() then return false end
    local follower = entity.components.follower
    local leader = follower ~= nil and follower:GetLeader() or nil
    if leader ~= nil and leader:IsValid()
        and (leader:HasTag("player") or leader:HasTag("playerowned")) then return false end
    return entity:HasAnyTag("monster", "killer", "scarytoprey", "hostile", "epic")
        or combat.target ~= nil
end

function M.NearHutOrWorker(hut)
    local x, _, z = hut.Transform:GetWorldPosition()
    for _, entity in ipairs(TheSim:FindEntities(x, 0, z, M.SCAN_RADIUS,
            {"_combat"}, {"INLIMBO", "player", "lumine_aranara"})) do
        if M.IsThreat(entity) then
            if hut:GetDistanceSqToInst(entity) <= M.HUT_DANGER_RADIUS ^ 2 then return true end
            for _, worker in pairs(hut.workers) do
                if worker ~= nil and worker:IsValid() and not worker.despawning
                    and worker:GetDistanceSqToInst(entity) <= M.WORKER_DANGER_RADIUS ^ 2 then
                    return true
                end
            end
        end
    end
    return false
end

return M
