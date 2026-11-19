local assets = {Asset("ANIM", "anim/lumine_element_energy.zip")}

local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("lumine_element_energy")
    inst.AnimState:SetBuild("lumine_element_energy")
    inst.AnimState:PlayAnimation("orb",true)
    inst.AnimState:SetScale(.72,.72)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists=false
    inst.SetColour=function(self, colour)
        self.AnimState:SetMultColour(colour[1],colour[2],colour[3],.95)
    end
    inst:DoTaskInTime(2.2,inst.Remove)
    return inst
end

return Prefab("lumine_relic_echo",fn,assets)
