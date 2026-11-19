local Config = require("aranara_hut/config")

local assets = {Asset("ANIM", "anim/lumine_aranara.zip")}
local STEP = FRAMES
local SPEED = 2.4
local RETREAT_SPEED = 8

local function Animate(inst, name)
    if inst._animation ~= name then
        inst._animation = name
        inst.AnimState:PlayAnimation(name, name ~= "appear" and name ~= "disappear" and name ~= "idle_wave")
    end
end

local function ValidPlant(home, plant)
    if plant == nil or not plant:IsValid() or plant:HasTag("INLIMBO")
        or home.reserved_plants[plant] then return false end
    local tendable = plant.components.farmplanttendable
    local stress = plant.components.farmplantstress
    if tendable == nil or not tendable.tendable or stress == nil
        or stress.stressors.happiness ~= true then return false end
    local growable = plant.components.growable
    if growable ~= nil then
        local stage = growable:GetCurrentStageData()
        if stage == nil or not stage.tendable then return false end
    end
    return Config.Contains(home, plant)
end

local function FindPlant(inst)
    local home = inst.home
    local x, _, z = home.Transform:GetWorldPosition()
    local best, best_distance = nil, math.huge
    for _, plant in ipairs(TheSim:FindEntities(x, 0, z, Config.RADIUS,
            {"tendable_farmplant"}, {"INLIMBO"})) do
        if ValidPlant(home, plant) then
            local distance = inst:GetDistanceSqToInst(plant)
            if distance < best_distance then
                best, best_distance = plant, distance
            end
        end
    end
    if best ~= nil then home.reserved_plants[best] = inst end
    return best
end

local function ReleaseTarget(inst)
    local home, target = inst.home, inst.target_plant
    if home ~= nil and home:IsValid() and target ~= nil
        and home.reserved_plants[target] == inst then
        home.reserved_plants[target] = nil
    end
    inst.target_plant = nil
end

local function MoveToward(inst, x, z, speed, animation)
    local px, _, pz = inst.Transform:GetWorldPosition()
    local dx, dz = x - px, z - pz
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= .3 then return true end
    local step = math.min(distance, (speed or SPEED) * STEP)
    inst.Transform:SetPosition(px + dx / distance * step, 0, pz + dz / distance * step)
    inst.AnimState:SetScale(dx < 0 and -1 or 1, 1)
    Animate(inst, animation or "walk")
    return false
end

local function Tick(inst)
    if inst.despawning then return end
    local home = inst.home
    if home == nil or not home:IsValid() or home.remaining <= 0 then
        inst:Remove()
        return
    end
    if inst.retreating then
        local x, _, z = home.Transform:GetWorldPosition()
        if inst:GetDistanceSqToInst(home) <= .7 * .7
            or MoveToward(inst, x, z + .2, RETREAT_SPEED, "run") then
            inst:Despawn()
        end
        return
    end
    if GetTime() < (inst.appearing_until or 0) then return end
    local target = inst.target_plant
    if inst.tending_until ~= nil then
        if GetTime() >= inst.tending_until then
            if Config.Contains(home, target)
                and target.components.farmplanttendable ~= nil then
                target.components.farmplanttendable:TendTo(inst)
            end
            ReleaseTarget(inst)
            inst.tending_until = nil
            inst.next_search = GetTime() + 1.5
        end
        return
    end
    if target ~= nil then
        if not Config.Contains(home, target)
            or target.components.farmplanttendable == nil
            or not target.components.farmplanttendable.tendable then
            ReleaseTarget(inst)
        else
            local x, _, z = target.Transform:GetWorldPosition()
            if inst:GetDistanceSqToInst(target) <= 1.1 * 1.1 or MoveToward(inst, x, z) then
                Animate(inst, "tend")
                inst.tending_until = GetTime() + .9
            end
            return
        end
    end
    if GetTime() >= (inst.next_search or 0) then
        inst.next_search = GetTime() + 2.5
        inst.target_plant = FindPlant(inst)
        if inst.target_plant ~= nil then
            inst.idle_wave_until = nil
            inst.idle_destination = nil
            return
        end
    end
    local x, _, z = home.Transform:GetWorldPosition()
    local offset = inst.worker_slot - 2
    local now = GetTime()
    if inst.idle_wave_until ~= nil then
        if now < inst.idle_wave_until then return end
        inst.idle_wave_until = nil
        Animate(inst, "idle")
    end
    if inst.idle_destination == nil and now >= (inst.next_idle_move or 0) then
        inst.idle_destination = {
            x = x + offset * 1.4 + (math.random() - .5) * 1.5,
            z = z + 1.5 + math.random() * 1.7,
        }
        inst.next_idle_move = now + 5 + math.random() * 4
    end
    local point = inst.idle_destination
    if point ~= nil then
        if MoveToward(inst, point.x, point.z) then
            inst.idle_destination = nil
            inst.idle_wave_until = now + 1.4
            Animate(inst, "idle_wave")
        end
    else
        Animate(inst, "idle")
    end
end

local function SetHome(inst, home, slot)
    inst.home = home
    inst.worker_slot = slot
    inst.next_search = GetTime() + (slot - 1) * .35
    inst.next_idle_move = GetTime() + slot * .8
    local x, _, z = home.Transform:GetWorldPosition()
    inst.Transform:SetPosition(x + (slot - 2) * .6, 0, z + .5)
    inst.appearing_until = GetTime() + .55
    Animate(inst, "appear")
end

local function Despawn(inst)
    if inst.despawning then return end
    inst.despawning = true
    ReleaseTarget(inst)
    Animate(inst, "disappear")
    inst:DoTaskInTime(.55, inst.Remove)
end

local function Retreat(inst)
    if inst.despawning or inst.retreating then return end
    inst.retreating = true
    inst.tending_until = nil
    inst.idle_wave_until = nil
    inst.idle_destination = nil
    ReleaseTarget(inst)
    Animate(inst, "run")
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("lumine_aranara")
    inst.AnimState:SetBuild("lumine_aranara")
    inst.AnimState:PlayAnimation("idle", true)
    inst.Transform:SetScale(.8, .8, .8)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("notarget")
    inst:AddTag("noattack")
    inst:AddTag("lumine_aranara")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false -- The persistent hut reconstructs its helpers after loading.
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(1)
    inst.components.health:SetInvincible(true)
    inst.SetHome = SetHome
    inst.Despawn = Despawn
    inst.Retreat = Retreat
    inst:DoPeriodicTask(STEP, Tick, .1)
    inst.OnRemoveEntity = ReleaseTarget
    return inst
end

return Prefab("lumine_aranara", fn, assets)
