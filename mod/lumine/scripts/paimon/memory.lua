local L = require("languages/lumine").For("paimon/memory")
-- 长期小历史随派蒙存档；短期语境不跨重载，避免把昨天的话说成“刚才”。
local C = require("paimon/config")
local M = {}
local function State(pet)
    pet.memory = pet.memory or { deaths = 0, samefood = 0 }
    pet._context = pet._context or {}
    return pet.memory, pet._context
end
local function Recent(t, seconds) return t ~= nil and GetTime()-t >= 0 and GetTime()-t <= seconds end
local function Window(list, seconds)
    local out = {}
    for _,t in ipairs(list or {}) do if Recent(t, seconds) then out[#out+1] = t end end
    out[#out+1] = GetTime()
    while #out > 8 do table.remove(out, 1) end
    return out
end
function M.Food(pet, prefab, value, slot)
    local m, c = State(pet)
    m.samefood = m.lastfood == prefab and math.min(999, (m.samefood or 0)+1) or 1
    m.lastfood = prefab
    c.meal = { at = GetTime(), repeated = m.samefood >= 3, fancy = slot == 1 and value >= 37.5 }
end
function M.OwnerAte(pet)
    local _,c = State(pet)
    c.ownerate = GetTime()
end
function M.Death(pet, data)
    local m = State(pet)
    m.deaths = math.min(9999, (m.deaths or 0)+1)
    local killer = data and data.afflicter
    m.lastboss = killer and killer:IsValid() and killer:HasTag("epic") and killer.prefab or nil
    m.bossuntil = m.lastboss and GetTime()+TUNING.TOTAL_DAY_TIME or nil
    pet._context = {}
end
function M.Element(pet, data)
    local _,c = State(pet)
    if not data.slot then
        c.hydroafterpyro = data.element == 4 and c.element == 5 and Recent(c.switchedat,30) and GetTime() or nil
        c.switches = Window(c.switches,20)
        c.element, c.switchedat = data.element, GetTime()
    elseif data.element == 6 then
        c.icecasts = Window(c.icecasts,60)
        c.iceat = GetTime()
    end
end
local function NearbyFire(pet, episode)
    if not pet.owner or not episode then return false end
    for _,tree in ipairs(episode.trees) do
        if tree:IsValid() and tree:HasTag("fire") and pet.owner:GetDistanceSqToInst(tree) <= 12*12 then return true end
    end
    return false
end
function M.ObserveFire(pet, entities)
    local _,c = State(pet)
    local trees = {}
    for _,entity in ipairs(entities) do
        if entity:HasTag("tree") and entity:HasTag("fire") then trees[#trees+1] = entity end
    end
    if #trees > 0 then
        if not c.fire then c.fireout = nil end
        c.fire = c.fire or { started = GetTime(), trees = {}, known = {} }
        local f = c.fire
        for _,tree in ipairs(trees) do
            if not f.known[tree] and #f.trees < 32 then
                f.known[tree] = true; f.trees[#f.trees+1] = tree
            end
        end
        if not f.noticed then pet.dialogue:Offer("fire_notice")
        elseif GetTime()-f.started >= 10 then pet.dialogue:Offer("fire_continues") end
    elseif c.fire then
        local ended = c.fire.noticed
        -- 离开火场、树被删除或卸载都不等于看见火灭；只确认仍在眼前的实体。
        for _,tree in ipairs(c.fire.trees) do
            if not tree:IsValid() or tree:HasTag("fire")
                or not pet.owner or pet.owner:GetDistanceSqToInst(tree)>12*12 then ended = false; break end
        end
        if ended then c.fireout = GetTime(); pet.dialogue:Offer("fire_ended") end
        c.fire = nil
    end
end
function M.Spoken(pet, id)
    local _,c = State(pet)
    if id == "elements:92" or id == "elements:99" then c.warned = GetTime() end
    if (id == "elements:102" or id == "elements:105") and c.fire then c.fire.noticed = true end
end

M.labels = {
    materials = L(1, "派蒙饿着，背包非空且没有任何可食用物品"),
    repeatfood = L(2, "实际连续吃同一 prefab 至少三份，且刚完成进食"),
    firstmeal = L(3, "刚从第一格吃到实际饱食收益至少 37.5 的食物"),
    ownerhungry = L(4, "旅行者刚进食，派蒙当前饱食度低于 120"),
    firstdeath = L(5, "本次记录是旅行者首次死亡"), repeatdeath = L(6, "已记录至少两次死亡"),
    manydeaths = L(7, "已记录至少五次死亡"),
    rematch = L(8, "一游戏日内曾被同种首领杀死，当前又以该种存活首领为战斗目标"),
    switching = L(9, "20 秒内实际切换至少三次元素，当前刚切换"),
    hydroafterpyro = L(10, "30 秒内从火切到水，当前刚切换"),
    repeatice = L(11, "60 秒内成功释放冰技能至少三次，当前刚释放"),
    warnedfire = L(12, "30 秒内确实说出防火提醒，且当前看见附近树木着火"),
    fire = L(13, "当前看见附近树木着火"),
    firecontinues = L(14, "确实说出着火反应，且观测到的火势持续至少十秒"),
    fireended = L(15, "确实说出着火反应，随后亲眼确认原树木仍在附近且火已灭"),
}
M.rules = {}
local function Rule(name, ids) for _,id in ipairs(ids) do M.rules[id] = name end end
Rule("materials", {"hunger:12","hunger:16","hunger:24","hunger:32"})
Rule("repeatfood", {"hunger:48","hunger:58","hunger:62"})
Rule("firstmeal", {"hunger:49","hunger:50"})
Rule("ownerhungry", {"actions:55","actions:59","actions:63"})
Rule("firstdeath", {"death:1"}); Rule("repeatdeath", {"death:2"}); Rule("manydeaths", {"death:4"})
Rule("rematch", {"boss:5","boss:12","boss:23"})
Rule("switching", {"elements:4","elements:21","elements:39","elements:57","elements:78","elements:93","elements:111"})
Rule("hydroafterpyro", {"elements:75"}); Rule("repeatice", {"elements:117","elements:120"})
Rule("warnedfire", {"elements:102"}); Rule("fire", {"elements:105"})
Rule("firecontinues", {"elements:107"}); Rule("fireended", {"elements:108"})
function M.Weight(pet, id)
    local rule = M.rules[id]
    if not rule then return 0 end
    local m,c = State(pet)
    local ok
    if rule == "materials" then
        if pet.satiety >= C.AUTO_EAT_BELOW or not pet.components.container then return nil end
        local occupied = false
        for slot = 1,C.SLOTS do
            local item = pet.components.container:GetItemInSlot(slot)
            if item then
                occupied = true
                if require("paimon/food").EffectiveHunger(item,pet)>0 then return nil end
            end
        end
        ok = occupied
    elseif rule == "repeatfood" then ok = c.meal and Recent(c.meal.at,8) and c.meal.repeated
    elseif rule == "firstmeal" then ok = c.meal and Recent(c.meal.at,8) and c.meal.fancy
    elseif rule == "ownerhungry" then ok = Recent(c.ownerate,8) and pet.satiety < C.AUTO_EAT_BELOW
    elseif rule == "firstdeath" then ok = m.deaths == 1
    elseif rule == "repeatdeath" then ok = (m.deaths or 0) >= 2
    elseif rule == "manydeaths" then ok = (m.deaths or 0) >= 5
    elseif rule == "rematch" then
        local target = pet.owner and pet.owner.components.combat and pet.owner.components.combat.target
        ok = m.lastboss and GetTime() < (m.bossuntil or 0) and target and target:IsValid()
            and target.prefab == m.lastboss and target:HasTag("epic")
            and pet.owner:GetDistanceSqToInst(target)<=12*12
            and (not target.components.health or not target.components.health:IsDead())
    elseif rule == "switching" then ok = Recent(c.switchedat,8) and #(c.switches or {})>=3
    elseif rule == "hydroafterpyro" then ok = Recent(c.hydroafterpyro,8)
    elseif rule == "repeatice" then ok = Recent(c.iceat,8) and #(c.icecasts or {})>=3
    elseif rule == "warnedfire" then ok = Recent(c.warned,30) and NearbyFire(pet,c.fire)
    elseif rule == "fire" then ok = NearbyFire(pet,c.fire)
    elseif rule == "firecontinues" then ok = c.fire and c.fire.noticed and GetTime()-c.fire.started>=10 and NearbyFire(pet,c.fire)
    elseif rule == "fireended" then ok = Recent(c.fireout,8) and not c.fire end
    if not ok then return nil end
    return (rule == "manydeaths" or rule == "warnedfire" or rule == "hydroafterpyro") and 3 or rule == "fire" and 1 or 2
end
function M.Lines(pet, lines)
    local selected, best = {}, -1
    for _,line in ipairs(lines) do
        local weight = M.Weight(pet,line.id)
        if weight ~= nil and weight >= best then
            if weight > best then selected, best = {}, weight end
            selected[#selected+1] = line
        end
    end
    return selected
end
function M.OnSave(pet)
    local m = State(pet)
    return { deaths = m.deaths, lastfood = m.lastfood, samefood = m.samefood, lastboss = m.lastboss,
        bossremaining = math.max(0,(m.bossuntil or 0)-GetTime()) }
end
function M.OnLoad(pet, data)
    pet._context = nil
    pet.memory = { deaths = 0, samefood = 0 }
    if type(data) ~= "table" then return end
    local m = pet.memory
    for _,key in ipairs({"deaths","samefood"}) do
        if type(data[key]) == "number" and data[key]==data[key] then m[key] = math.max(0,math.min(9999,math.floor(data[key]))) end
    end
    m.lastfood = type(data.lastfood)=="string" and data.lastfood or nil
    m.lastboss = type(data.lastboss)=="string" and data.lastboss or nil
    if type(data.bossremaining)=="number" and data.bossremaining==data.bossremaining then
        m.bossuntil = GetTime()+math.max(0,math.min(TUNING.TOTAL_DAY_TIME,data.bossremaining))
    end
end
return M
