local assets = {
    Asset("ANIM", "anim/lumine_relic_codex.zip"),
    Asset("ATLAS", "images/inventoryimages/lumine_relic_codex.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_relic_codex.tex"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("lumine_relic_codex")
    inst.AnimState:SetBuild("lumine_relic_codex")
    inst.AnimState:PlayAnimation("idle", true)
    inst:AddTag("lumine_relic_codex")
    MakeInventoryFloatable(inst, "small", .1, .7)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/lumine_relic_codex.xml"
    inst.components.inventoryitem.imagename = "lumine_relic_codex"
    inst:AddComponent("equippable")
    inst.components.equippable.restrictedtag = "lumine"
    inst.components.equippable.equipslot = EQUIPSLOTS.LUMINE_RELIC_CODEX
    local function Refresh(owner)
        if owner.components.lumineartifacts ~= nil then
            owner:DoTaskInTime(0, function()
                if owner:IsValid() and owner.components.lumineartifacts ~= nil then
                    owner.components.lumineartifacts:Apply()
                end
            end)
        end
    end
    inst.components.equippable:SetOnEquip(function(_, owner) Refresh(owner) end)
    inst.components.equippable:SetOnUnequip(function(_, owner) Refresh(owner) end)
    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("lumine_relic_codex", fn, assets)
