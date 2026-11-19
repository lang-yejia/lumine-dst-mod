local FX = require("lumine_electro_fx")

local function MakeSparks(name, build, sound)
    local assets = {Asset("ANIM", "anim/" .. build .. ".zip")}

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddLight()
        inst.entity:AddNetwork()
        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        inst.Transform:SetScale(2, 2, 2)
        inst.AnimState:SetBank(build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        FX.TintImpact(inst)
        inst.Light:SetRadius(1.5)
        inst.Light:SetFalloff(1)
        inst.Light:SetIntensity(.55)
        inst.Light:SetColour(.62, .25, 1)
        inst.Light:Enable(false)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end

        inst.persists = false
        inst.AlignToTarget = function(self, target, attacker)
            local x, y, z = target.Transform:GetWorldPosition()
            local ax, _, az = attacker.Transform:GetWorldPosition()
            local dx, dz = ax - x, az - z
            local length = math.sqrt(dx * dx + dz * dz)
            local offset = length > 0 and (target:GetPhysicsRadius(0) + .2) / length or 0
            self.Transform:SetPosition(x + dx * offset, y + 1, z + dz * offset)
            self.AnimState:PlayAnimation("sparks_" .. math.random(3))
            self.SoundEmitter:PlaySound(sound)
            self.Light:Enable(true)
        end
        inst:ListenForEvent("animover", inst.Remove)
        inst:DoTaskInTime(.8, inst.Remove)
        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeSparks("lumine_electro_sparks", "elec_hit_fx", "dontstarve/characters/wx78/spark"),
    MakeSparks("lumine_electro_immune_sparks", "elec_immune_fx",
        "dontstarve/common/together/electricity/electrocute_immune")
