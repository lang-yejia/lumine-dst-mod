local L = require("languages/lumine").For("paimon/install")
local M = {}
function M.Install(G, hooks)
    G.require("paimon/feeding").Install(G, hooks)
    hooks.AddPlayerPostInit(G.require("paimon/companion").AttachPlayer)
    G.require("paimon/companion").InstallRPC(G,hooks)
    G.require("paimon/companion").InstallAction(G,hooks)
    local containers = G.require("containers")
    local positions = {}
    for y = 0, 2 do
        positions[#positions + 1] = G.Vector3(-162, 75 - 75 * y, 0)
        positions[#positions + 1] = G.Vector3(-87, 75 - 75 * y, 0)
    end
    containers.params.lumine_paimon = {
        widget = {
            slotpos = positions, animbank = "ui_icepack_2x3", animbuild = "ui_icepack_2x3",
            pos = G.Vector3(125, 180, 0), side_align_tip = 120,
        },
        type = "chest", openlimit = 1,
    }
    local S = G.STRINGS
    S.NAMES.LUMINE_PAIMON = L(1, "派蒙")
    S.NAMES.LUMINE_PAIMON_CAKE = L(2, "旅途周年小蛋糕")
    S.CHARACTERS.GENERIC.DESCRIBE.LUMINE_PAIMON_CAKE = L(3, "派蒙准备的周年礼物，愿我们明年还在一起旅行。")
    S.CHARACTERS.GENERIC.DESCRIBE.LUMINE_PAIMON = L(4, "这位小向导有自己的旅行者。")
    -- 原版 COOK 不向玩家发出成功事件；只在原动作成功返回后补发给派蒙。
    local cook = G.ACTIONS.COOK.fn
    G.ACTIONS.COOK.fn = function(action)
        local success, reason = cook(action)
        local pet = action.doer and action.doer._paimon
        if success and pet and pet:IsValid() and not pet._dormant then pet.dialogue:Offer("cook") end
        return success, reason
    end
    hooks.AddPlayerPostInit(G.require("paimon/bond").AttachPlayer)
    G.require("paimon/guide").Install(hooks.AddPrefabPostInit)
    G.require("paimon/tracking").Install(hooks.AddPrefabPostInit)
    G.require("paimon/guide").InstallDebug(G)
    G.require("paimon/guide").InstallRPC(G,hooks)
    hooks.AddPrefabPostInit("world", function(inst)
        if inst.ismastersim then inst:AddComponent("paimonworld") end
    end)
    G.require("paimon/lore_service").InstallRPC(G, hooks.AddShardModRPCHandler,
        hooks.SendModRPCToShard, hooks.GetShardModRPC)
    hooks.AddClassPostConstruct("widgets/containerwidget", G.require("paimon/container_ui").Attach)
end
return M
