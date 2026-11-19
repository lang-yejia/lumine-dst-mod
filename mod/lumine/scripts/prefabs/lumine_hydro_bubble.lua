local Rules = require("hydro/rules").bubble
local assets = {Asset("ANIM", "anim/lumine_hydro_water.zip")}
local prefabs = {"crab_king_bubble2", "waterstreak_burst"}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:SetCanSleep(false)
    MakeCharacterPhysics(inst, 40, .65)
    -- Keep the ground plane so the motor cannot carry a falling body out of view.
    -- Horizontal obstacles are checked separately, leaving nearby creatures free to move.
    inst.Physics:SetCollisionMask(COLLISION.GROUND)

    inst:AddTag("NOCLICK")
    inst:AddTag("companion")
    inst:AddTag("player_aligned")
    inst:AddTag("soulless")
    inst:AddTag("lumine_hydro_bubble")

    inst.AnimState:SetBank("lumine_hydro_water")
    inst.AnimState:SetBuild("lumine_hydro_water")
    inst.AnimState:PlayAnimation("orb", true)
    inst.AnimState:SetLightOverride(.55)
    inst.AnimState:SetFinalOffset(2)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(Rules.health)
    inst.components.health.nofadeout = true
    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(Rules.damage)
    return inst
end

return Prefab("lumine_hydro_bubble", fn, assets, prefabs)
