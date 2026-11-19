local Config = require("aranara_hut/config")
local M = {}

function M.Install(G, AddClassPostConstruct)
    local containers = G.require("containers")
    containers.params.lumine_aranara_hut = {
        widget = {
            slotpos = {G.Vector3(-76, 0, 0), G.Vector3(0, 0, 0), G.Vector3(76, 0, 0)},
            animbank = "ui_chest_3x1",
            animbuild = "ui_chest_3x1",
            pos = G.Vector3(0, 200, 0),
            side_align_tip = 100,
        },
        type = "chest",
        openlimit = 1,
        itemtestfn = function(_, item)
            return Config.IsFuel(item)
        end,
    }
    AddClassPostConstruct("widgets/containerwidget", G.require("aranara_hut/container_ui").Attach)
    G.STRINGS.NAMES.LUMINE_ARANARA_HUT = "兰纳罗小屋"
    G.STRINGS.RECIPE_DESC.LUMINE_ARANARA_HUT = "给森林的小帮手一个家。"
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.LUMINE_ARANARA_HUT = "燃料让这里的兰纳罗照料附近的农作物。"
end

return M
