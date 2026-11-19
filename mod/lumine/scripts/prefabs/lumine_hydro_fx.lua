local assets = {
    Asset("ANIM", "anim/lumine_hydro_water.zip"),
    Asset("ANIM", "anim/waterstreak.zip"),
}

local function Visual(bank, anim, scale)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(bank)
    inst.AnimState:PlayAnimation(anim, true)
    inst.AnimState:SetLightOverride(.24)
    inst.Transform:SetScale(scale, scale, scale)
    return inst
end

local function Drop()
    local inst = Visual("lumine_hydro_water", "drop", 1)
    inst.AnimState:SetLightOverride(.48)
    inst.AnimState:SetFinalOffset(2)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    return inst
end

local function Stream()
    local inst = Visual("waterstreak", "pre", 1.65)
    inst.Transform:SetSixFaced()
    inst.AnimState:PlayAnimation("pre")
    inst.AnimState:PushAnimation("loop", true)
    inst.AnimState:SetDeltaTimeMultiplier(1.9)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    return inst
end

return Prefab("lumine_hydro_drop", Drop, assets, {"waterstreak_burst"}),
    Prefab("lumine_hydro_stream", Stream, assets, {"waterstreak_burst"})
