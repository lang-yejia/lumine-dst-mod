local L = require("languages/lumine").For("paimon/dialogue_database")
-- 每句均为独立编写的完整台词；不使用运行时拼词凑数。
local M = { events = {}, categories = {}, count = 0 }
local function Add(category, event, priority, lo, hi, text)
    local group = M.events[event]
    if not group then
        group = { priority = priority, cooldown = { lo, hi }, lines = {} }
        M.events[event] = group
    end
    for line in text:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if #line > 0 then
            M.categories[category] = (M.categories[category] or 0) + 1
            M.count = M.count + 1
            group.lines[#group.lines + 1] = {
                id = category .. ":" .. M.categories[category], text = line,
            }
        end
    end
end
for _, name in ipairs({ "common", "life", "activities", "combat", "elements", "glider" }) do
    require("paimon/lines/" .. name)(Add)
end
-- 使用原 ID 分配观测事件，不扩充数量，也不让着火台词在普通技能成功时乱播。
local function Move(from, event, ids)
    local group = { priority = 3, cooldown = {90,150}, lines = {} }
    for _,id in ipairs(ids) do
        for i,line in ipairs(M.events[from].lines) do
            if line.id == id then
                group.lines[#group.lines+1] = table.remove(M.events[from].lines,i)
                break
            end
        end
    end
    local existing = M.events[event]
    if existing then for _,line in ipairs(group.lines) do existing.lines[#existing.lines+1] = line end
    else M.events[event] = group end
end
Move("pyro_skill1", "fire_notice", {"elements:102"})
Move("pyro_skill2", "fire_notice", {"elements:105"})
Move("pyro_skill2", "fire_continues", {"elements:107"})
Move("pyro_skill2", "fire_ended", {"elements:108"})
Add("food_refusal", "bad_food", 3, 45, 75, L(1, [[
旅行者！背包可以借你放东西，但这种吃了会难受的东西，派蒙才不吃！
喂！你把这种东西塞进来，是想考验派蒙的胃吗？
先说好，这个只是替你保管，可不算给派蒙准备的点心！
派蒙是喜欢好吃的，又不是只要能咽下去就行！
]]))
Add("companion", "order_thanks", 3, 0, 0, L(2, [[
就是这个味道！旅行者太懂派蒙啦！说好的回礼，派蒙可不会赖账！
好吃！小金库又少了一点……不过请旅行者收下，这是派蒙的心意！
]]))
Add("companion", "gift_drop", 3, 15, 15, L(3, [[
背包放不下啦！派蒙把回礼放在你脚边了，记得捡起来哦！
]]))
Add("companion", "cake_gift", 3, 0, 0, L(4, [[
以前都是你给派蒙找好吃的，这次轮到派蒙请客啦！下一年，也要一起旅行哦！
]]))
Add("companion", "track_none", 2, 15, 15, L(5, [[
这附近没发现新的痕迹，我们往前走走吧！
]]))
Add("companion", "cake_refusal", 3, 30, 30, L(6, [[
这是派蒙专门给你准备的礼物！不许喂回来，留着自己吃嘛！
]]))
Add("monkey", "monkey_transform", 3, 0, 0, L(7, [[
荧？！你、你怎么变成猴子啦！别跑，派蒙差点认不出你了！
哇啊！尾巴、毛茸茸的手……荧，原来那个诅咒真的会把你变成猴子！
荧变成猴子了？！冷静，派蒙要冷静……不管变成什么样，派蒙都会陪着你的！
]]))
return M
