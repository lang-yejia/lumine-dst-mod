local RADIUS = 5
local DURATION = 10
local TICK = 0.2
local assets = { Asset("ANIM", "anim/lumine_geo_field.zip") }

local function Leave(inst, player)
    if not inst.inside[player] then return end
    inst.inside[player] = nil
    if player:IsValid() then
        if player.components.health ~= nil then
            player.components.health.externalabsorbmodifiers:RemoveModifier(inst, "lumine_geo_field")
        end
        if player.components.combat ~= nil then
            player.components.combat.externaldamagemultipliers:RemoveModifier(inst, "lumine_geo_field")
        end
        player._lumine_geo_fields = math.max(0, (player._lumine_geo_fields or 1) - 1)
        if player._lumine_geo_fields == 0 then player:RemoveTag("lumine_geo_stable") end
    end
end

local function Enter(inst, player)
    if inst.inside[player] then return end
    inst.inside[player] = true
    if player.components.health ~= nil then
        player.components.health.externalabsorbmodifiers:SetModifier(inst, 0.12, "lumine_geo_field")
    end
    if player.components.combat ~= nil then
        player.components.combat.externaldamagemultipliers:SetModifier(inst, 1.15, "lumine_geo_field")
    end
    player._lumine_geo_fields = (player._lumine_geo_fields or 0) + 1
    player:AddTag("lumine_geo_stable")
end

local function Tick(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local found = {}
    for _, player in ipairs(TheSim:FindEntities(x, 0, z, RADIUS, {"player"}, {"INLIMBO", "playerghost"})) do
        if player.components.health ~= nil and not player.components.health:IsDead() then
            found[player] = true
            Enter(inst, player)
        end
    end
    for player in pairs(inst.inside) do
        if not found[player] then Leave(inst, player) end
    end
end

local function OnRemove(inst)
    for player in pairs(inst.inside) do Leave(inst, player) end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("lumine_geo_field")
    inst.AnimState:SetBuild("lumine_geo_field")
    inst.AnimState:PlayAnimation("loop", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.Transform:SetScale(2.5, 2.5, 2.5)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.inside = {}
    inst:DoPeriodicTask(TICK, Tick, 0)
    inst:DoTaskInTime(DURATION, inst.Remove)
    inst.OnRemoveEntity = OnRemove
    return inst
end

return Prefab("lumine_geo_field", fn, assets)
