local M = {
    character = "lumine",
    branches = {},
    nodes = {},
    by_id = {},
    elements = {},
    recipes = {},
    legacy = {
        rations = "lumine_survival_rations",
        ward = "lumine_combat_ward",
        swift = "lumine_survival_stride",
        rainproof = "lumine_survival_weather",
        swordmaster = "lumine_combat_sword",
        resolve = "lumine_combat_resolve",
    },
}

local function Branch(id, title, icon, x)
    local branch = {id = id, title = title, icon = icon, x = x, nodes = {}}
    M.branches[#M.branches + 1] = branch
    return branch
end

local function Node(branch, suffix, title, description, icon, dx, row, requires, effect)
    local id = "lumine_" .. suffix
    local node = {
        id = id, branch = branch.id, title = title, description = description, icon = icon,
        x = branch.x + dx, y = 160 - (row - 1) * 42,
        requires = requires, cost = 1, status = effect and "implemented" or "planned",
        effect = effect,
    }
    assert(M.by_id[id] == nil, id)
    M.nodes[#M.nodes + 1] = node
    branch.nodes[#branch.nodes + 1] = node
    M.by_id[id] = node
    if effect and effect.type == "unlock_element" then M.elements[effect.key] = id end
    if effect and effect.type == "unlock_recipe" then M.recipes[effect.key] = id end
    return id
end

local element = Branch("lumine_elements", "元素共鸣", "wilson_alchemy_gem_1", -204)
local foundation = Node(element, "element_foundation", "元素之门", "开启元素共鸣分支。学习对应元素后，仍需在七天神像处供奉并共鸣。",
    "wilson_alchemy_gem_1", 0, 1, nil, {type = "unlock_feature", key = "element_foundation"})
M.foundation = foundation
local wind = Node(element, "element_wind", "风元素", "允许与风共鸣，使用顺风而行、风行与风涡剑。",
    "wind-emblem", -21, 2, foundation, {type = "unlock_element", key = "wind"})
local geo = Node(element, "element_geo", "岩元素", "允许与岩共鸣，使用磐岩之心、星岩护佑与岩域共鸣。",
    "geo-emblem", 21, 2, foundation, {type = "unlock_element", key = "geo"})
Node(element, "element_electro", "雷元素", "允许在雷元素神像处共鸣，使用战斗回能、雷元素附魔及雷霆唤星。",
    "electro-emblem", -21, 3, foundation, {type = "unlock_element", key = "electro"})
Node(element, "element_dendro", "草元素", "允许在草元素神像处共鸣，使用荆棘援护、藤蔓缠绕与孢子领域。",
    "dendro-emblem", 21, 3, foundation, {type = "unlock_element", key = "dendro"})
Node(element, "element_hydro", "水元素", "允许与水共鸣，使用清澈之水、水纹剑与涨潮之水。",
    "hydro-emblem", -21, 4, foundation, {type = "unlock_element", key = "hydro"})
Node(element, "element_pyro", "火元素", "允许与火共鸣，获得炽热之心，并使用流火之刃与爆炎状态。",
    "pyro-emblem", 21, 4, foundation, {type = "unlock_element", key = "pyro"})
Node(element, "element_cryo", "冰元素", "允许与冰共鸣，使用寒冰护体、霜刃附魔和极寒冰陨。",
    "cryo-emblem", -21, 5, foundation, {type = "unlock_element", key = "cryo"})
Node(element, "element_mastery", "共鸣研习", "预留元素实战研习。",
    "wilson_alchemy_gem_3", 21, 5, foundation)

local workshop = Branch("lumine_workshop", "工坊与珍藏", "wilson_alchemy_1", -102)
local codex = Node(workshop, "workshop_codex", "星辉圣匣", "解锁配方。在制作栏搜索「星辉圣匣」，首次制作需要炼金引擎。",
    "lumine_relic_codex", 0, 1, nil, {type = "unlock_recipe", key = "lumine_relic_codex"})
local relics = Node(workshop, "workshop_relic_study", "遗珍研读", "预留圣遗物研读。",
    "wilson_alchemy_gem_2", 0, 2, codex)
Node(workshop, "workshop_relic_curation", "星辉珍藏", "预留圣遗物收藏扩展。",
    "wilson_alchemy_gem_3", 0, 3, relics)
Node(workshop, "workshop_reforge", "旅人工艺", "预留合成台的装备工艺扩展。",
    "wilson_alchemy_ore_3", 0, 4, codex)

local partners = Branch("lumine_partners", "森林与伙伴", "walter_woby_taskaid", 0)
local hut = Node(partners, "partners_hut", "兰纳罗小屋", "解锁兰纳罗小屋配方，仍需在炼金引擎处原型制作。",
    "lumine_aranara_hut-icon", 0, 1, nil, {type = "unlock_recipe", key = "lumine_aranara_hut"})
local garden = Node(partners, "partners_garden", "森林园丁", "预留兰纳罗照料植物的进阶功能。",
    "wormwood_blooming_farmrange1", -21, 2, hut)
Node(partners, "partners_hearth", "温暖小屋", "预留小屋燃料与照料机制扩展。",
    "walter_camp_fire", -21, 3, garden)
Node(partners, "partners_paimon", "旅伴默契", "预留派蒙的额外互动。",
    "walter_woby_taskaid", 21, 2, hut)

local combat = Branch("lumine_combat", "战斗技巧", "wathgrithr_arsenal_spear_1", 102)
local sword = Node(combat, "combat_sword", "熟练剑士", "预留旅行者剑术。",
    "wathgrithr_arsenal_spear_1", 0, 1)
Node(combat, "combat_ward", "旅途防护", "预留护甲与防护技巧。",
    "wathgrithr_combat_defense", -21, 2, sword)
local resolve = Node(combat, "combat_resolve", "战后振奋", "预留战斗后的恢复技巧。",
    "wathgrithr_songs_instantsong_cd", 21, 2, sword)
Node(combat, "combat_lunar", "月亮专精", "预留月亮阵营专精。",
    "wilson_favor_lunar", -21, 3, resolve)
Node(combat, "combat_shadow", "暗影专精", "预留暗影阵营专精。",
    "wilson_favor_shadow", 21, 3, resolve)

local survival = Branch("lumine_survival", "旅途生存", "walter_camp_rope", 204)
local rations = Node(survival, "survival_rations", "旅行口粮", "预留长途出行的口粮管理。",
    "walter_camp_wobytreat", 0, 1)
local stride = Node(survival, "survival_stride", "轻盈步伐", "预留陆上行旅技巧。",
    "wilson_beard_speed_1", -21, 2, rations)
Node(survival, "survival_weather", "风雨同行", "预留雨天探索技巧。",
    "wormwood_blooming_overheatprotection", 21, 2, rations)
Node(survival, "survival_firstaid", "野外急救", "预留野外伤势处理。",
    "walter_camp_firstaid", 21, 3, rations)
Node(survival, "survival_navigation", "辨途", "预留远行与环境辨识技巧。",
    "lumine_journal", -21, 3, stride)

-- Keep all seven affinities addressable, including those without playable effects.
M.elements.cryo = "lumine_element_cryo"

M.icons = {
    ["wind-emblem"] = "images/element/wind-emblem.xml",
    ["geo-emblem"] = "images/element/geo-emblem.xml",
    ["electro-emblem"] = "images/element/electro-emblem.xml",
    ["dendro-emblem"] = "images/element/dendro-emblem.xml",
    ["hydro-emblem"] = "images/element/hydro-emblem.xml",
    ["pyro-emblem"] = "images/element/pyro-emblem.xml",
    ["cryo-emblem"] = "images/element/cryo-emblem.xml",
    lumine_relic_codex = "images/inventoryimages/lumine_relic_codex.xml",
    ["lumine_aranara_hut-icon"] = "images/inventoryimages/lumine_aranara_hut-icon.xml",
    lumine_journal = "images/inventoryimages/lumine_journal.xml",
}

return M
