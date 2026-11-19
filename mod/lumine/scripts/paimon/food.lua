local C = require("paimon/config")
local JourneyData = require("lumine_progression")
local Memory = require("paimon/memory")
local M = {}
function M.IsHarmful(item, pet)
    local edible = item and item.components.edible
    -- 使用实时收益，包含腐坏与食物自定义数值；不触发 OnEaten 副作用。
    return edible ~= nil and (edible:GetHealth(pet) < 0 or edible:GetSanity(pet) < 0)
end

local function Complain(pet, feeding)
    -- 只回应玩家实际开包放入，读档恢复库存不触发吐槽。
    if pet._dormant or not pet.owner or (not feeding and not pet.components.container:IsOpenedBy(pet.owner))
        then return end
    pet.dialogue:Offer("bad_food")
    if pet.dialogue.pending.bad_food then
        -- 留出开包台词播放时间，仍由统一调度让位给紧急提醒。
        pet.dialogue.pending.bad_food = GetTime() + 30
    end
end

function M.Attach(pet)
    local container = pet.components.container
    local giveitem = container.GiveItem
    local function Count()
        local count = 0
        for slot = 1, C.SLOTS do
            local item = container:GetItemInSlot(slot)
            if item then
                count = count + (item.components.stackable and item.components.stackable:StackSize() or 1)
            end
        end
        return count
    end
    container.GiveItem = function(self, item, ...)
        -- 原版合并堆叠不发送 itemget；比较实际入包数量，也覆盖只放入部分堆叠。
        local harmful = M.IsHarmful(item, pet)
        local before = harmful and Count() or 0
        local result = giveitem(self, item, ...)
        if harmful and Count() > before then Complain(pet) end
        return result
    end
end

local function EffectiveHunger(item, pet)
    if item and item.prefab=="lumine_paimon_cake" then return 0 end
    local edible = item and item.components.edible
    if edible == nil then return 0 end
    -- 人类饮食类型；不把噩梦燃料、木头、齿轮等角色专用食物吞掉。
    local t = edible and edible.foodtype
    if t ~= FOODTYPE.MEAT and t ~= FOODTYPE.VEGGIE and t ~= FOODTYPE.GOODIES
        and t ~= FOODTYPE.GENERIC and t ~= FOODTYPE.SEEDS then return 0 end
    if M.IsHarmful(item, pet) then return 0 end
    local value = edible:GetHunger(pet)
    return type(value) == "number" and value == value and value > 0 and value < math.huge and value or 0
end
M.EffectiveHunger = EffectiveHunger

local function EatServing(pet, serving, value, slot)
    -- Both routes reach here only after one real serving has left its inventory.
    local rewarded=false -- Travel records replace the former food-order reward loop.
    pet:SetSatiety(pet.satiety + value)
    Memory.Food(pet, serving.prefab, value, slot)
    serving:Remove()
    pet:PlayPaimonAnimation("eat", false)
    pet._eating_until = GetTime() + C.EAT_INTERVAL
    pet.dialogue:Offer("eat")
    return rewarded
end

function M.Feed(pet, doer, item)
    if not pet or not pet:IsValid() or pet.prefab ~= "lumine_paimon"
        or not doer or not doer:IsValid() or pet.owner ~= doer or pet._dormant
        or doer:HasTag("playerghost")
        or (doer.components.health and doer.components.health:IsDead())
        or doer:GetDistanceSqToInst(pet) > 9 then return false end
    local inventory = doer.components.inventory
    if not inventory or not item or not item:IsValid() or inventory:GetActiveItem() ~= item then return false end
    local value = EffectiveHunger(item, pet)
    if value <= 0 then
        if item.prefab=="lumine_paimon_cake" then pet.dialogue:Offer("cake_refusal") end
        if M.IsHarmful(item, pet) then Complain(pet, true) end
        return false
    end
    local companion=doer.components.paimoncompanion
    local order=companion and companion:IsOrder(item)
    if pet.satiety >= C.MAX_HUNGER and not order then return false end
    local serving = inventory:RemoveItem(item, false)
    if not serving then return false end
    local rewarded=EatServing(pet, serving, value)
    if not rewarded and doer.components.sanity then doer.components.sanity:DoDelta(2) end
    return true
end

function M.TryEat(pet)
    if pet.satiety >= C.AUTO_EAT_BELOW or pet._dormant then return false end
    local container = pet.components.container
    for slot = 1, C.SLOTS do
        local item = container:GetItemInSlot(slot)
        -- Returned travel evidence belongs in Paimon's bag, even if edible.
        local value = item ~= nil and JourneyData.BY_EVIDENCE[item.prefab] == nil
            and EffectiveHunger(item, pet) or 0
        if value > 0 then
            -- Container:RemoveItem(false) 只分离一份，并正确同步堆叠和格子。
            local serving = container:RemoveItem(item, false)
            if serving == nil then return false end
            EatServing(pet, serving, value, slot)
            return true
        end
    end
    return false
end
return M
