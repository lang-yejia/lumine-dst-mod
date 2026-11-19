local assets = {
    Asset("ANIM", "anim/alchemy_table.zip"),
    Asset("ATLAS", "images/inventoryimages/alchemy_table.xml"),
    Asset("IMAGE", "images/inventoryimages/alchemy_table.tex"),
}

local function OnActivate(inst)
    inst.AnimState:PlayAnimation("use")
    inst.AnimState:PushAnimation(inst.components.prototyper.on and "proximity_loop" or "idle", true)
end

local function OnTurnOn(inst)
    if inst.AnimState:IsCurrentAnimation("use") then
        inst.AnimState:PushAnimation("proximity_loop", true)
    else
        inst.AnimState:PlayAnimation("proximity_loop", true)
    end
end

local function OnTurnOff(inst)
    inst.AnimState:PlayAnimation("idle", true)
end

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:SetDeploySmartRadius(1)
    MakeObstaclePhysics(inst, 0.55)
    inst.AnimState:SetBank("alchemy_table")
    inst.AnimState:SetBuild("alchemy_table")
    inst.AnimState:PlayAnimation("idle", true)
    inst:AddTag("structure")
    inst:AddTag("prototyper")
    inst:AddTag("lumine_alchemy_station")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    inst:AddComponent("inspectable")
    inst:AddComponent("craftingstation")
    inst.components.craftingstation.nosave = true
    inst.PlayForge = OnActivate
    inst:AddComponent("prototyper")
    inst.components.prototyper.onturnon = OnTurnOn
    inst.components.prototyper.onturnoff = OnTurnOff
    inst.components.prototyper.onactivate = OnActivate
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst:ListenForEvent("onbuilt", OnActivate)
    return inst
end

return Prefab("alchemy_table", fn, assets),
    MakePlacer("alchemy_table_placer", "alchemy_table", "alchemy_table", "idle")
