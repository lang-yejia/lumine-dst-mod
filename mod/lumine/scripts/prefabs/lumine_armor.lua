local armor = require("lumine_gear_stats").armor

local AddUpgradeTarget = require("lumine_upgrade")

local function MakeArmor(data)
    local name = data.name
    local atlas = "images/inventoryimages/" .. name .. ".xml"
    local assets = {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("IMAGE", "images/inventoryimages/" .. name .. ".tex"),
        Asset("ATLAS", atlas),
    }

    local function OnEquip(inst, owner)
        if data.slot == "HEAD" then
            owner.AnimState:OverrideSymbol("headbase_hat", name, "headbase_hat")
            owner.AnimState:Show("HAT")
            owner.AnimState:Show("HAIR_HAT")
            owner.AnimState:Hide("HAIR_NOHAT")
            owner.AnimState:Hide("HAIR")
            owner.AnimState:Hide("HEAD")
            owner.AnimState:Show("HEAD_HAT")
            owner.AnimState:Show("HEAD_HAT_NOHELM")
            owner.AnimState:Hide("HEAD_HAT_HELM")
        else
            owner.AnimState:OverrideSymbol("torso", name, "torso")
        end
    end

    local function OnUnequip(inst, owner)
        if data.slot == "HEAD" then
            owner.AnimState:ClearOverrideSymbol("headbase_hat")
            owner.AnimState:Hide("HAT")
            owner.AnimState:Hide("HAIR_HAT")
            owner.AnimState:Show("HAIR_NOHAT")
            owner.AnimState:Show("HAIR")
            owner.AnimState:Show("HEAD")
            owner.AnimState:Hide("HEAD_HAT")
            owner.AnimState:Hide("HEAD_HAT_NOHELM")
            owner.AnimState:Hide("HEAD_HAT_HELM")
        else
            owner.AnimState:ClearOverrideSymbol("torso")
        end
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
        -- Scale only the world item animation; inventory tex and equipped
        -- character symbols use separate assets and keep their current size.
        inst.AnimState:SetScale(1.5, 1.5)
        inst:AddTag("lumine_armor")
        MakeInventoryFloatable(inst, "small", .1, .75)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = atlas
        inst.components.inventoryitem.imagename = name
        inst:AddComponent("armor")
        inst.components.armor:InitCondition(data.durability, data.absorption)
        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS[data.slot]
        inst.components.equippable.restrictedtag = "lumine"
        inst.components.equippable:SetOnEquip(OnEquip)
        inst.components.equippable:SetOnUnequip(OnUnequip)
        AddUpgradeTarget(inst, name)
        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeArmor(armor[1]), MakeArmor(armor[2]), MakeArmor(armor[3]), MakeArmor(armor[4]),
    MakeArmor(armor[5]), MakeArmor(armor[6]), MakeArmor(armor[7]), MakeArmor(armor[8])
