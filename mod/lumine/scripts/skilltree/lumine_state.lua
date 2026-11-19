local Nodes = require("skilltree/lumine_nodes")
local SkillTreeData = require("skilltreedata")
local M = {}

function M.New()
    return SkillTreeData()
end

function M.Save(data)
    local skills = {}
    for id in pairs(data:GetActivatedSkills(Nodes.character) or {}) do skills[id] = true end
    return {skills = skills, xp = data:GetSkillXP(Nodes.character)}
end

function M.Load(data, saved)
    local character = Nodes.character
    local xp = tonumber(saved.xp) or 0
    if xp ~= xp then xp = 0 end
    data.skillxp[character] = math.floor(math.max(0, math.min(data:GetMaximumExperiencePoints(), xp)))
    data.activatedskills[character] = nil
    if type(saved.skills) ~= "table" then return end
    -- Parents are declared before children. Native validation rejects impossible
    -- allocations, while stable names survive position and RPC-index changes.
    for _, node in ipairs(Nodes.nodes) do
        if saved.skills[node.id] == true and M.CanLearn(data, node.id) then
            data:ActivateSkill(node.id, character)
        end
    end
end

function M.XPForPoints(points)
    local xp = 0
    for i = 1, points do xp = xp + TUNING.SKILL_THRESHOLDS[i] end
    return xp
end

function M.CanLearn(data, id)
    local node = Nodes.by_id[id]
    return node ~= nil and node.status == "implemented"
        and not data:IsActivated(id, Nodes.character)
        and (node.requires == nil or data:IsActivated(node.requires, Nodes.character))
        and data:GetAvailableSkillPoints(Nodes.character) >= node.cost
end

function M.MigrateElements(data, legacy, active)
    local wind = legacy.wind == true or active == "wind"
    local geo = legacy.geo == true or active == "geo"
    if not (wind or geo) then return end
    local skills = {[Nodes.foundation] = true}
    local count = 1
    if wind then skills[Nodes.elements.wind], count = true, count + 1 end
    if geo then skills[Nodes.elements.geo], count = true, count + 1 end
    M.Load(data, {skills = skills, xp = M.XPForPoints(count)})
end

function M.Decode(data, encoded)
    local skills, xp = data:DecodeSkillTreeData(encoded)
    M.Load(data, {skills = skills, xp = xp})
end

return M
