local Data = require("lumine_artifact_data")
local M = {}

local function IsCodex(item)
    return item ~= nil and item:IsValid() and item.prefab == "lumine_relic_codex"
end

function M.GetEquipped(inventory)
    local item = inventory and inventory:GetEquippedItem(EQUIPSLOTS.LUMINE_RELIC_CODEX)
    return IsCodex(item) and item or nil
end

function M.GetCarried(inventory)
    return M.GetEquipped(inventory) or (inventory and inventory:FindItem(IsCodex))
end

local function CanCollect(owner)
    return owner ~= nil and owner:HasTag("lumine") and not owner:HasTag("playerghost")
end

local function IsOwnedBy(item, owner)
    local inventoryitem = item and item:IsValid() and item.components.inventoryitem
    return inventoryitem and inventoryitem:GetGrandOwner() == owner
end

function M.Collect(act)
    local owner, item, codex = act.doer, act.invobject, act.target
    if not CanCollect(owner) or not IsOwnedBy(item, owner) then return false end
    local artifacts = owner.components.lumineartifacts
    local piece = Data.BY_PREFAB[item.prefab]
    if not artifacts or not piece then return false end

    if codex == nil then codex = M.GetCarried(owner.components.inventory) end
    if not IsCodex(codex) or not IsOwnedBy(codex, owner) then return false end

    local stack = item.components.stackable
    local consumed = item
    if stack and stack:IsStack() then
        consumed = stack:Get(1)
        if not consumed then return false end
    end
    local was_new = artifacts:Collect(piece.id)
    consumed:Remove()
    if owner.components.talker then
        owner.components.talker:Say(was_new
            and ("已收录" .. Data.BY_SET[piece.set].short .. "·" .. piece.name .. "。")
            or "这件圣遗物已收录，重复的回响消散了。")
    end
    return true
end

function M.Install(add_action, add_component_action)
    local action = add_action("LUMINE_UNLOCK_RELIC", "收入星辉圣匣", M.Collect)
    action.rmb = true
    action.priority = 9
    action.instant = true

    add_component_action("INVENTORY", "inventoryitem", function(item, doer, actions)
        if item:HasTag("lumine_relic") and CanCollect(doer) and M.GetCarried(doer.replica.inventory) then
            actions[#actions + 1] = action
        end
    end)
    add_component_action("USEITEM", "inventoryitem", function(item, doer, target, actions, right)
        if right and item:HasTag("lumine_relic") and IsCodex(target) and CanCollect(doer)
            and target.replica.inventoryitem and target.replica.inventoryitem:IsGrandOwner(doer) then
            actions[#actions + 1] = action
        end
    end)
end

return M
