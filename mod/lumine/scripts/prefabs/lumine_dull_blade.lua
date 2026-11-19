local swords = require("lumine_gear_stats").swords

local AddUpgradeTarget = require("lumine_upgrade")

local function MakeSword(data)
    local name = data.name
    local atlas = "images/inventoryimages/" .. name .. ".xml"
    local assets = {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("ATLAS", atlas),
        Asset("IMAGE", "images/inventoryimages/" .. name .. ".tex"),
    }

    local function OnEquip(inst, owner)
        owner.AnimState:OverrideSymbol("swap_object", name, "swap_" .. name)
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
        owner:DoTaskInTime(0, function()
            if owner:IsValid() and owner.components.luminejourney ~= nil then
                owner.components.luminejourney:ApplySwordSkill()
            end
        end)
    end

    local function OnUnequip(inst, owner)
        owner.AnimState:Hide("ARM_carry")
        owner.AnimState:Show("ARM_normal")
        owner:DoTaskInTime(0, function()
            if owner:IsValid() and owner.components.luminejourney ~= nil then
                owner.components.luminejourney:ApplySwordSkill()
            end
        end)
    end

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")
        inst:AddTag("weapon")
        inst:AddTag("lumine_sword")
        MakeInventoryFloatable(inst, "small", 0.1, 0.7)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = atlas
        inst.components.inventoryitem.imagename = name
        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(data.damage)
        if data.faction_bonus ~= nil then
            inst:AddComponent("damagetypebonus")
            inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, data.faction_bonus)
            inst.components.damagetypebonus:AddBonus("lunar_aligned", inst, data.faction_bonus)
        end
        if data.planar ~= nil then
            inst:AddComponent("planardamage")
            inst.components.planardamage:SetBaseDamage(data.planar)
        end
        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(data.uses)
        inst.components.finiteuses:SetUses(data.uses)
        inst.components.finiteuses:SetOnFinished(inst.Remove)
        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
        if data.speed ~= nil then inst.components.equippable.walkspeedmult = data.speed end
        inst.components.equippable:SetOnEquip(OnEquip)
        inst.components.equippable:SetOnUnequip(OnUnequip)
        AddUpgradeTarget(inst, name)
        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeSword(swords[1]), MakeSword(swords[2]), MakeSword(swords[3]), MakeSword(swords[4])
