local assets = {
    Asset("ANIM", "anim/weed_ivy_lunar.zip"),
    Asset("ANIM", "anim/farm_soil.zip"),
    Asset("ANIM", "anim/sporebomb.zip"),
}

local function CreateFX(bank, build, sound)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    if sound then inst.entity:AddSoundEmitter() end
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)
    inst.AnimState:SetFinalOffset(1)
    return inst
end

local function Roots()
    local inst = CreateFX("weed_ivy", "weed_ivy_lunar", false)
    inst.AnimState:PlayAnimation("spike_pre")
    inst.AnimState:PushAnimation("spike_loop", true)
    inst.AnimState:OverrideSymbol("soil01", "farm_soil", "soil01")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.Retract = function(self)
        self.AnimState:PlayAnimation("spike_pst")
        self:DoTaskInTime(.8, self.Remove)
    end
    return inst
end

local function SporeBomb()
    local inst = CreateFX("sporebomb", "sporebomb", true)
    inst.AnimState:PlayAnimation("sporebomb_pre")
    inst.AnimState:PushAnimation("sporebomb_loop", true)
    inst.AnimState:SetLightOverride(.3)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.Pop = function(self)
        self.AnimState:PlayAnimation("sporebomb_pst")
        self.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spore_cloud_LP", "burst")
        self:DoTaskInTime(.6, self.Remove)
    end
    return inst
end

return Prefab("lumine_dendro_roots", Roots, assets),
    Prefab("lumine_dendro_sporebomb", SporeBomb, assets)
