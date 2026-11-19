local Data = require("lumine_forging_data")
local M = {}

local function Valid(act)
    local owner, table_inst, item = act.doer, act.target, act.invobject
    return owner ~= nil and owner:HasTag("lumine") and not owner:HasTag("playerghost")
        and table_inst ~= nil and table_inst:IsValid() and table_inst:HasTag("lumine_alchemy_station")
        and item ~= nil and item:IsValid() and item.components.inventoryitem ~= nil
        and item.components.inventoryitem:GetGrandOwner() == owner
        and owner:GetDistanceSqToInst(table_inst) <= 16
        and owner.components.luminejourney ~= nil
end

local function Say(owner, message)
    if owner.components.talker ~= nil then owner.components.talker:Say(message) end
end

local function Activate(table_inst)
    if table_inst.PlayForge ~= nil then table_inst:PlayForge() end
end

function M.Record(act)
    if not Valid(act) then return false end
    local owner, item = act.doer, act.invobject
    local journey = owner.components.luminejourney
    if Data.BY_INSIGHT[item.prefab] ~= nil then
        if not journey:RedeemInsight(item.prefab) then Say(owner, "这份旧见闻已经记录过了。") return false end
        item:Remove()
        Activate(act.target)
        Say(owner, "旧见闻已录入旅行手册。")
        return true
    end
    if journey:RecordGear(item.prefab) then
        Activate(act.target)
        Say(owner, "已记录" .. (STRINGS.NAMES[string.upper(item.prefab)] or item.prefab) .. "的旅行见闻。装备已归还。")
        return true
    end
    Say(owner, journey.gear_records[item.prefab] and "这件装备的见闻已记录。" or "先亲自使用这件装备，再来记录见闻。")
    return false
end

function M.Forge(act)
    if not Valid(act) then return false end
    local owner, old = act.doer, act.invobject
    local stage = Data.BY_OLD[old.prefab]
    if stage == nil then return false end
    if old.components.equippable ~= nil and old.components.equippable:IsEquipped() then
        Say(owner, "先卸下装备再重铸。") return false
    end
    if not owner.components.luminejourney:HasStageRecords(stage) then
        Say(owner, "还没有记齐这一阶段的装备见闻。") return false
    end
    local energy = owner.components.lumineenergy
    if energy == nil or energy.current < stage.energy then
        Say(owner, "重铸需要 " .. stage.energy .. " 点元素力。") return false
    end
    local inventory = owner.components.inventory
    for _, material in ipairs(stage.materials) do
        -- ConsumeByName only draws from the inventory, active item and overflow.
        -- Keep the availability check on exactly those sources.
        if not inventory:Has(material[1], material[2], false) then
            Say(owner, "重铸材料不足：" .. (STRINGS.NAMES[string.upper(material[1])] or material[1]))
            return false
        end
    end
    local replacement = SpawnPrefab(stage.new)
    if replacement == nil then return false end
    if old.components.finiteuses ~= nil and replacement.components.finiteuses ~= nil then
        replacement.components.finiteuses:SetPercent(old.components.finiteuses:GetPercent())
    elseif old.components.armor ~= nil and replacement.components.armor ~= nil then
        replacement.components.armor:SetPercent(old.components.armor:GetPercent())
    end
    -- All checks and prefab creation succeeded before anything is spent.
    for _, material in ipairs(stage.materials) do inventory:ConsumeByName(material[1], material[2]) end
    energy:Add(-stage.energy)
    local container = old.components.inventoryitem:GetContainer()
    local slot = old.components.inventoryitem:GetSlotNum()
    old:Remove()
    if container ~= nil then container:GiveItem(replacement, slot)
    else inventory:GiveItem(replacement) end
    Activate(act.target)
    Say(owner, "旅行装备重铸完成。")
    return true
end

function M.Install(G, H)
    local record = H.AddAction("LUMINE_RECORD_GEAR", "记录装备见闻", M.Record)
    local forge = H.AddAction("LUMINE_FORGE_GEAR", "重铸旅行装备", M.Forge)
    for _, action in ipairs({record, forge}) do
        action.distance, action.priority, action.rmb = 2.5, 8, true
        for _, sg in ipairs({"wilson", "wilson_client"}) do
            H.AddStategraphActionHandler(sg, G.ActionHandler(action, "doshortaction"))
        end
    end
    H.AddComponentAction("USEITEM", "inventoryitem", function(item, doer, target, actions, right)
        if right and target ~= nil and target:HasTag("lumine_alchemy_station") and doer:HasTag("lumine") then
            if Data.BY_ITEM[item.prefab] ~= nil or Data.BY_INSIGHT[item.prefab] ~= nil then
                actions[#actions+1] = record
            elseif Data.BY_OLD[item.prefab] ~= nil then
                actions[#actions+1] = forge
            end
        end
    end)
end
return M
