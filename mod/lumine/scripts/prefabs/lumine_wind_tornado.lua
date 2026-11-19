local DirectDamage = require("lumine_direct_damage")
local assets = { Asset("ANIM", "anim/lumine_wind_burst.zip") }
local STEP_TIME = 0.1
local DURATION = 6
local SPEED = 1.5
local RADIUS = 5.25
local SCALE = 1.86
local LARGE_CONTACT = 1.875
local PULL_STEP = .33
local DAMAGE_MULTIPLIER = 1.25
local HIT_INTERVAL = .6
local MAX_HITS = 5

local function IsGround(x, z)
    return TheWorld.Map:IsPassableAtPoint(x, 0, z)
        and TheWorld.Map:IsVisualGroundAtPoint(x, 0, z)
end

local function IsLarge(target)
    return target:HasTag("epic") or target:HasTag("largecreature")
end

local function IsEnemy(target, caster)
    if target == caster or not target:IsValid() or target:HasTag("player")
        or target:HasTag("INLIMBO") or target:HasTag("wall")
        or target.components.health == nil or target.components.health:IsDead()
        or target.components.combat == nil then
        return false
    end
    if target.components.follower ~= nil and target.components.follower.leader ~= nil then return false end
    return target.components.combat.target == caster
        or (caster.components.combat ~= nil and caster.components.combat.target == target)
        or (target:HasTag("monster") and not target:HasTag("character"))
end

local function IsObstructed(x, z)
    if not IsGround(x, z) then return true end
    local blockers = TheSim:FindEntities(x, 0, z, 0.5, nil, {"INLIMBO"},
        {"wall", "structure"})
    return #blockers > 0
end

local function GetDamage(caster)
    local damage = 34
    if caster.components.inventory ~= nil then
        local weapon = caster.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if weapon ~= nil and weapon.components.weapon ~= nil
            and type(weapon.components.weapon.damage) == "number" then
            damage = weapon.components.weapon.damage
        end
    end
    return math.min(25, math.max(1, damage * .25)) * DAMAGE_MULTIPLIER
end

local function BeginDespawn(inst)
    if inst.fading then return end
    inst.fading = true
    inst.tick_task:Cancel()
    inst.tick_task = nil
    inst.SoundEmitter:KillSound("wind")
    inst.AnimState:PlayAnimation("out")
    inst:DoTaskInTime(0.3, inst.Remove)
end

local function Tick(inst)
    if inst.fading then return end
    inst.age = inst.age + STEP_TIME
    if inst.age + .001 >= DURATION or inst.caster == nil or not inst.caster:IsValid()
        or inst.caster:HasTag("playerghost") then
        BeginDespawn(inst)
        return
    end
    local x, _, z = inst.Transform:GetWorldPosition()
    if not inst.stopped then
        local nx, nz = x + inst.dx * SPEED * STEP_TIME, z + inst.dz * SPEED * STEP_TIME
        if IsObstructed(nx, nz) then
            BeginDespawn(inst)
            return
        end
        local nearby = TheSim:FindEntities(nx, 0, nz, MAX_PHYSICS_RADIUS + LARGE_CONTACT,
            nil, {"INLIMBO"}, {"epic", "largecreature"})
        for _, target in ipairs(nearby) do
            if IsLarge(target) and target.components.health ~= nil and not target.components.health:IsDead() then
                local tx, _, tz = target.Transform:GetWorldPosition()
                local vx, vz = tx - nx, tz - nz
                local reach = target:GetPhysicsRadius(0) + LARGE_CONTACT
                if vx * vx + vz * vz <= reach * reach then
                    inst.stopped = true
                    break
                end
            end
        end
        if not inst.stopped then
            inst.Transform:SetPosition(nx, 0, nz)
            x, z = nx, nz
        end
    end

    local targets = TheSim:FindEntities(x, 0, z, RADIUS, nil,
        {"INLIMBO", "playerghost", "player"}, {"_combat", "monster"})
    local affected = 0
    for _, target in ipairs(targets) do
        if affected >= 8 then break end
        if IsEnemy(target, inst.caster) then
            affected = affected + 1
            if math.floor(inst.age / STEP_TIME + 0.5) % 2 == 0
                and not IsLarge(target) and target:GetPhysicsRadius(0) <= 0.8
                and target.Physics ~= nil
                and target.components.locomotor ~= nil and target:GetCurrentPlatform() == nil then
                local tx, _, tz = target.Transform:GetWorldPosition()
                local vx, vz = x - tx, z - tz
                local distance = math.sqrt(vx * vx + vz * vz)
                if distance > 0.65 then
                    local step = math.min(PULL_STEP, distance - 0.65)
                    local px, pz = tx + vx / distance * step, tz + vz / distance * step
                    if IsGround(px, pz) and not IsObstructed(px, pz) then
                        target.Physics:Teleport(px, 0, pz)
                    end
                end
            end
            local count = inst.hits[target.GUID] or 0
            if count < MAX_HITS and inst.age + 0.001 >= inst.next_hit then
                inst.hits[target.GUID] = count + 1
                DirectDamage(inst.caster, target, inst.damage)
            end
        end
    end
    if inst.age + 0.001 >= inst.next_hit then
        inst.next_hit = inst.next_hit + HIT_INTERVAL
    end
end

local function SetCaster(inst, caster, dx, dz)
    inst.caster = caster
    inst.dx, inst.dz = dx, dz
    inst.damage = GetDamage(caster)
end

local function TornadoFn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("lumine_wind_burst")
    inst.AnimState:SetBuild("lumine_wind_burst")
    inst.AnimState:SetFinalOffset(2)
    inst.AnimState:PlayAnimation("in")
    inst.AnimState:PushAnimation("loop", true)
    inst.AnimState:SetScale(SCALE, SCALE)
    inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tornado", "wind")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.caster = nil
    inst.stopped = false
    inst.fading = false
    inst.age = 0
    inst.next_hit = HIT_INTERVAL
    inst.hits = {}
    inst.SetCaster = SetCaster
    inst.tick_task = inst:DoPeriodicTask(STEP_TIME, Tick)
    return inst
end

return Prefab("lumine_wind_tornado", TornadoFn, assets)
