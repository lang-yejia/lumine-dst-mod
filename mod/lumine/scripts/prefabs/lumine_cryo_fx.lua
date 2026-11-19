local assets = {
    Asset("ANIM", "anim/deerclops_icespike.zip"),
    Asset("ANIM", "anim/deerclops_mutated_actions.zip"),
    Asset("ANIM", "anim/deerclops_mutated.zip"),
    Asset("ANIM", "anim/deer_ice_circle.zip"),
}

local function Visual(bank, build, animation, looping, scale, ground)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false
    inst.Transform:SetScale(scale, scale, scale)
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:PlayAnimation(animation, looping)
    inst.AnimState:SetMultColour(.68, .88, 1, .9)
    inst.AnimState:SetLightOverride(.35)
    if ground then
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
    end
    inst.entity:SetPristine()
    return inst
end

local function Meteor()
    local inst = Visual("deerclops_icespike", "deerclops_icespike", "spike_big1", false, 1.6)
    inst.entity:SetCanSleep(false)
    return inst
end

local function Impact()
    local inst = Visual("deerclops", "deerclops_mutated", "ice_impact", false, 1.3)
    if TheWorld.ismastersim then
        inst:ListenForEvent("animover", inst.Remove)
        inst:DoTaskInTime(1.2, inst.Remove)
    end
    return inst
end

local function Field()
    return Visual("deer_ice_circle", "deer_ice_circle", "loop", true, 1.6, true)
end

local function Weapon()
    local inst = Visual("deerclops_icespike", "deerclops_icespike", "spike1", true, .22)
    inst.entity:AddFollower()
    return inst
end

local function Crystal()
    local inst = Visual("deerclops_icespike", "deerclops_icespike", "spike_big1", false, .24)
    inst.AnimState:SetFrame(9)
    inst.AnimState:Pause()
    return inst
end

return Prefab("lumine_cryo_meteor", Meteor, assets),
    Prefab("lumine_cryo_impact", Impact, assets),
    Prefab("lumine_cryo_field", Field, assets),
    Prefab("lumine_cryo_weapon_fx", Weapon, assets),
    Prefab("lumine_cryo_shield_crystal", Crystal, assets)
