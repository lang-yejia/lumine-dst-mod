local L = require("languages/lumine").For("paimon/feeding")
local Food = require("paimon/food")
local JourneyData = require("lumine_progression")
local M = {}

function M.Install(G, hooks)
    local feed = hooks.AddAction("PAIMON_FEED", L(1, "喂食"), function(act)
        return Food.Feed(act.target, act.doer, act.invobject)
    end)
    feed.priority = 10
    feed.distance = 2
    local record = hooks.AddAction("PAIMON_RECORD", "请派蒙记录", function(act)
        local owner, pet = act.doer, act.target
        if not G.TheWorld.ismastersim or owner == nil
            or owner.components.luminejourney == nil then return false end
        return owner.components.luminejourney:BeginRecording(act.invobject, pet)
    end)
    record.priority = 11
    record.distance = 2
    hooks.AddComponentAction("USEITEM", "inventoryitem", function(item, doer, target, actions, right)
        if right or target.prefab ~= "lumine_paimon" or not target._owner
            or target._owner:value() ~= doer or target:HasTag("NOCLICK")
            or doer:HasTag("playerghost") then return end
        if JourneyData.BY_EVIDENCE[item.prefab] then actions[#actions + 1] = record end
        -- 客户端只有食物标签；新鲜度和动态收益在服务端执行时重新检查。
        for _, kind in ipairs({"MEAT", "VEGGIE", "GOODIES", "GENERIC", "SEEDS"}) do
            if item:HasTag("edible_" .. G.FOODTYPE[kind]) then
                actions[#actions + 1] = feed
                return
            end
        end
    end)
    for _, sg in ipairs({"wilson", "wilson_client"}) do
        hooks.AddStategraphActionHandler(sg, G.ActionHandler(feed, "doshortaction"))
        hooks.AddStategraphActionHandler(sg, G.ActionHandler(record, "doshortaction"))
    end
end

return M
