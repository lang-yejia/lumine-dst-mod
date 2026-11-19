local Nodes = require("skilltree/lumine_nodes")
local Layout = require("skilltree/lumine_layout")
local Progress = require("lumine_progression")
local M = {}

local function Closed()
    return false
end

function M.Register()
    local native = require("prefabs/skilltree_defs")
    local defs, orders = {}, {}
    local legacy = {}
    for _, skill in ipairs(Progress.SKILLS) do
        legacy[Nodes.legacy[skill.id]] = skill.hint
    end
    for _, branch in ipairs(Nodes.branches) do
        STRINGS.SKILLTREE.PANELS[string.upper(branch.id)] = branch.title
        orders[#orders + 1] = {branch.id, Layout.NativePosition(Layout.groups[branch.id])}
        for _, node in ipairs(branch.nodes) do
            local prereq = node.requires and "前置：" .. Nodes.by_id[node.requires].title .. "。" or ""
            local summary = (node.status == "planned" and "尚未开放。预留 " or "消耗 ")
                .. node.cost .. " 点洞察。"
            local desc = legacy[node.id] and ("旧旅行技能设计：" .. legacy[node.id]) or node.description
            defs[node.id] = {
                group = branch.id, pos = Layout.NativePosition(Layout.nodes[node.id]), title = node.title,
                desc = summary .. prereq .. "\n" .. desc,
                tags = node.tags or {}, root = node.requires == nil, defaultfocus = node.id == Nodes.foundation,
                lock_open = node.status == "planned" and Closed or nil,
            }
        end
    end
    for _, node in ipairs(Nodes.nodes) do
        if node.requires then
            local parent = defs[node.requires]
            parent.connects = parent.connects or {}
            parent.connects[#parent.connects + 1] = node.id
        end
    end
    native.CreateSkillTreeFor(Nodes.character, defs)
    native.SKILLTREE_ORDERS[Nodes.character] = orders
    for icon, atlas in pairs(Nodes.icons) do
        RegisterSkilltreeIconsAtlas(atlas, icon .. ".tex")
    end
end

return M
