local L = require("languages/lumine").For("paimon/companion_data")
-- Stable recipe IDs and account progress, shared by server logic and the bag UI.
local M = { recipes = {}, order = {} }
local function Add(id, name, tier, day)
    M.order[#M.order+1] = id
    M.recipes[id] = {id=id, name=name, tier=tier, day=day, sanity=tier*20, gold=tier*2}
end
Add("meatballs", L(1, "肉丸"), 1, 0)
Add("bonestew", L(2, "炖肉汤"), 1, 0)
Add("ratatouille", L(3, "蔬菜杂烩"), 1, 0)
Add("honeyham", L(4, "蜜汁火腿"), 2, 10)
Add("dragonpie", L(5, "火龙果派"), 2, 10)
Add("pumpkincookie", L(6, "南瓜饼"), 2, 10)
Add("icecream", L(7, "冰淇淋"), 2, 25)

local function Number(n, maximum)
    return type(n)=="number" and n==n and math.max(0,math.min(maximum,n)) or 0
end
function M.Clean(data)
    data = type(data)=="table" and data or {}
    return {revision=math.floor(Number(data.revision,1e12)), days=Number(data.days,1e9),
        claimed=math.floor(Number(data.claimed,1e9)), cycle=math.floor(Number(data.cycle,1e9)),
        recipe=M.recipes[data.recipe] and data.recipe or nil,
        done=data.done==true, rerolled=data.rerolled==true, cake_speech=data.cake_speech==true,
        gold=math.floor(Number(data.gold,1e6))}
end
function M.Newer(a,b)
    a,b = M.Clean(a),M.Clean(b)
    if b.revision>a.revision or (b.revision==a.revision and b.days>a.days) then return b end
    return a
end
function M.Pick(days, previous)
    local pool={}
    for _,id in ipairs(M.order) do
        if id~=previous and days>=M.recipes[id].day then pool[#pool+1]=id end
    end
    return pool[math.random(#pool)]
end
return M
