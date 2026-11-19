local Rules = require("pyro/rules")
local assets = {
    Asset("ANIM", "anim/frenzy_fx.zip"),
    Asset("ANIM", "anim/lumine_pyro_orb.zip"),
    Asset("ANIM", "anim/deer_fire_charge.zip"),
    Asset("ANIM", "anim/fire.zip"),
}

local function MakeFX(bank, build, animation, loop, scale, ground)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:SetCanSleep(false)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false
    inst.Transform:SetScale(scale, scale, scale)
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:PlayAnimation(animation, loop)
    inst.AnimState:SetMultColour(1, .63, .39, 1)
    inst.AnimState:SetLightOverride(.7)
    if ground then
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
    else
        inst.AnimState:SetFinalOffset(2)
    end
    inst.entity:SetPristine()
    return inst
end

local function Ring()
    return MakeFX("frenzy_fx", "frenzy_fx", "loop", true, Rules.ring.visual_scale, true)
end

local function Burst()
    return MakeFX("frenzy_fx", "frenzy_fx", "loop", true, .85, true)
end

local function PlayImpact(inst)
    inst.AnimState:SetBank("deer_fire_charge")
    inst.AnimState:SetBuild("deer_fire_charge")
    inst.AnimState:PlayAnimation("blast", false)
    inst.Transform:SetScale(1.4, 1.4, 1.4)
    inst:ListenForEvent("animover", inst.Remove)
    inst:DoTaskInTime(1.1, inst.Remove)
end

local function Orb()
    local inst = MakeFX("lumine_pyro_orb", "lumine_pyro_orb", "idle_loop", true, Rules.orb.visual_scale, false)
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    if TheWorld.ismastersim then
        inst.PlayImpact = PlayImpact
    end
    return inst
end

local function GroundImpact()
    local inst = MakeFX("frenzy_fx", "frenzy_fx", "post", false, 1.28, true)
    if TheWorld.ismastersim then
        inst:ListenForEvent("animover", inst.Remove)
        inst:DoTaskInTime(.8, inst.Remove)
    end
    return inst
end

local function Scorch()
    return MakeFX("fire", "fire", "level1", true, .42, false)
end

return Prefab("lumine_pyro_ring_fx", Ring, assets),
    Prefab("lumine_pyro_burst_fx", Burst, assets),
    Prefab("lumine_pyro_fireball", Orb, assets, {"lumine_pyro_impact_ground"}),
    Prefab("lumine_pyro_impact_ground", GroundImpact, assets),
    Prefab("lumine_pyro_scorch_fx", Scorch, assets)
