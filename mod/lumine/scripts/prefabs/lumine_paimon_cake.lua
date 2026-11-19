-- Paimon's anniversary gift uses its own cream cake art in-world and in inventory.
local C=require("paimon/config")
local assets={
    Asset("ANIM","anim/lumine_paimon_cake.zip"),
    Asset("ATLAS","images/inventoryimages/lumine_paimon_cake.xml"),
    Asset("IMAGE","images/inventoryimages/lumine_paimon_cake.tex"),
}
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("lumine_paimon_cake")
    inst.AnimState:SetBuild("lumine_paimon_cake")
    inst.AnimState:PlayAnimation("idle")
    inst:AddTag("preparedfood")
    inst:AddTag("paimon_anniversary_gift")
    MakeInventoryFloatable(inst,"med",.1,.83)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname="images/inventoryimages/lumine_paimon_cake.xml"
    inst.components.inventoryitem:ChangeImageName("lumine_paimon_cake")
    inst:AddComponent("edible")
    inst.components.edible.foodtype=FOODTYPE.GOODIES
    inst.components.edible.healthvalue=C.CAKE_HEALTH
    inst.components.edible.hungervalue=C.CAKE_HUNGER
    inst.components.edible.sanityvalue=C.CAKE_SANITY
    -- No perishable, stackable, recipe or cooking ingredients: one lasting gift.
    MakeHauntableLaunch(inst)
    return inst
end
return Prefab("lumine_paimon_cake",fn,assets)
