local assets = {
    Asset("ANIM", "anim/lumine_journal.zip"),
    Asset("ATLAS", "images/inventoryimages/lumine_journal.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_journal.tex"),
}

local function Description(inst, viewer)
    local journey = viewer.components.luminejourney
    return journey ~= nil and journey:GetSummary() or "这是莹的旅行手册。"
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("lumine_journal")
    inst.AnimState:SetBuild("lumine_journal")
    inst.AnimState:PlayAnimation("idle")
    MakeInventoryFloatable(inst, "small", 0.1, 0.7)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = Description
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/lumine_journal.xml"
    inst.components.inventoryitem.imagename = "lumine_journal"
    return inst
end

return Prefab("lumine_journal", fn, assets)
