local L = require("languages/lumine").For("flight/lumine_glider")
-- Visual altitude is baked into wilson animations. The authoritative physics
-- root follows the horizontal plane; airspace and safe landing are separate.
local EnergyRules = require("lumine_energy_rules")
local Glider = { SPEED = 1.5, EAT_INTERVAL = 1, INPUT_TIMEOUT = .6,
    TAKEOFF_WIND = EnergyRules.WING_TAKEOFF_WIND,
    TAKEOFF_OTHER = EnergyRules.WING_TAKEOFF_OTHER,
    DRAIN_WIND = EnergyRules.WING_DRAIN_WIND,
    DRAIN_OTHER = EnergyRules.WING_DRAIN_OTHER }
local Ground = require("flight/lumine_flight_ground")
local WingLight = require("flight/lumine_glider_light")
local STATES = { "lumine_glider_takeoff", "lumine_glider_fly", "lumine_glider_plunge" }
-- Native flight/notarget/noattack tags also reject ranged attacks. Keep the
-- player targetable and filter ground melee at the incoming combat entry.
local TAGS = { "lumine_gliding" }

local function IsRanged(source)
    if not source then return false end
    local c = source.components
    return IsRangedWeapon(source) or source:HasTag("rangedweapon")
        or (c.complexprojectile ~= nil and not c.complexprojectile.ismeleeweapon)
end

local function GroundMelee(inst, attacker, weapon)
    if not inst._lumine_glider or inst.lumine_glider_phase:value() ~= 2
        or not attacker or not attacker.components.combat then return false end
    return not attacker:HasAnyTag("flying", "flight", "lumine_gliding")
        and not (attacker.sg and attacker.sg:HasAnyStateTag("flying", "flight"))
        and not IsRanged(weapon) and not IsRanged(attacker)
end

local function EndActionProtection(inst)
    local saved = inst._lumine_glider
    if saved and saved.action_invincible ~= nil then
        local previous = saved.action_invincible
        saved.action_invincible = nil
        inst.components.health:SetInvincible(previous)
    end
end

function Glider.CommonInit(inst)
    inst.lumine_glider_phase = net_tinybyte(inst.GUID, "lumine.glider", "lumine_glider_dirty")
    inst.lumine_glider_remaining = net_float(inst.GUID, "lumine.glider.remaining", "lumine_glider_time_dirty")
    inst.lumine_glider_cd = net_float(inst.GUID, "lumine.glider.cooldown", "lumine_glider_cd_dirty")
    WingLight.CommonInit(inst)
end

function Glider.HasCooldown() return false end
function Glider.GetCooldown(inst) return 0 end
function Glider.SyncCooldown(inst)
    -- Retire cooldowns from older saves, including an already-running task.
    if inst.components.luminegrowth then inst.components.luminegrowth.glider_ready=nil end
    if inst.lumine_glider_cd:value()~=0 then inst.lumine_glider_cd:set(0) end
    if inst._lumine_glider_cd_task then
        inst._lumine_glider_cd_task:Cancel();inst._lumine_glider_cd_task=nil
    end
end
function Glider.Refresh(inst)
    if not inst.lumine_glider_cd then return end
    Glider.SyncCooldown(inst)
end

function Glider.SyncTime(inst)
    local energy = inst.components.lumineenergy
    local remaining = energy and energy.current or 0
    if inst.lumine_glider_remaining:value() ~= remaining then inst.lumine_glider_remaining:set(remaining) end
end

local function Hands(inst)
    local inv = inst.components.inventory
    local armed = inv and inv:GetEquippedItem(EQUIPSLOTS.HANDS) ~= nil
    inst.AnimState[armed and "Show" or "Hide"](inst.AnimState, "ARM_carry")
    inst.AnimState[armed and "Hide" or "Show"](inst.AnimState, "ARM_normal")
end

local function OpenHands(inst)
    inst.AnimState:Hide("ARM_carry")
    inst.AnimState:Show("ARM_normal")
end

function Glider.Cleanup(inst)
    local saved = inst._lumine_glider
    if not saved then return end
    EndActionProtection(inst)
    inst.AnimState:Resume()
    Glider.SyncCooldown(inst)
    inst._lumine_glider = nil
    inst.components.hunger.burnratemodifiers:RemoveModifier(inst, "lumine_glider")
    Glider.SyncTime(inst)
    inst.Physics:ClearMotorVelOverride()
    inst.Physics:Stop()
    inst.components.locomotor:Stop()
    inst.components.locomotor:Clear()
    local x, _, z = inst.Transform:GetWorldPosition()
    if not saved.fatal_landing and not Ground.CanLand(inst, x, z) then
        local point = Ground.RecoveryPoint(inst, saved)
        if point then inst.Physics:Teleport(point.x, 0, point.z) end
    end
    -- Restore collisions only after we are back on clear ground. This also runs
    -- on forced SG exits, death, disconnect and entity removal.
    inst.Physics:SetCollisionMask(saved.collisionmask)
    if inst.components.drownable then inst.components.drownable.enabled = saved.drownable end
    inst.lumine_glider_phase:set(0)
    if inst._lumine_glider_light_visuals then WingLight.Refresh(inst) end
    for _, tag in ipairs(TAGS) do
        if not saved.tags[tag] then inst:RemoveTag(tag) end
    end
    if inst.components.grogginess then inst.components.grogginess:RemoveImmunitySource(saved) end
    inst.AnimState:ClearOverrideSymbol("lumine_glider_left")
    inst.AnimState:ClearOverrideSymbol("lumine_glider_right")
    Hands(inst)
end

local function Begin(inst)
    if inst._lumine_glider then return end
    local x, _, z = inst.Transform:GetWorldPosition()
    local saved = { tags = {},
        collisionmask = inst.Physics:GetCollisionMask(),
        drownable = inst.components.drownable and inst.components.drownable.enabled,
        origin = { x = x, z = z }, safe = { x = x, z = z },
        last_air = { x = x, z = z } }
    inst._lumine_glider = saved
    for _, tag in ipairs(TAGS) do
        saved.tags[tag] = inst:HasTag(tag)
        inst:AddTag(tag)
    end
    inst.Physics:SetCollisionMask(COLLISION.GROUND)
    if inst.components.drownable then inst.components.drownable.enabled = false end
    if inst.components.grogginess then inst.components.grogginess:AddImmunitySource(saved) end
    inst.components.combat:SetTarget(nil)
    inst:ClearBufferedAction()
    inst.components.locomotor:Stop()
    inst.components.locomotor:Clear()
    inst.Physics:Stop()
    inst.AnimState:OverrideSymbol("lumine_glider_left", "lumine_glider_wings", "wing")
    inst.AnimState:OverrideSymbol("lumine_glider_right", "lumine_glider_wings", "wing")
    if inst.components.playercontroller then inst.components.playercontroller:RemotePausePrediction() end
end

function Glider.CanStart(inst)
    if inst.prefab ~= "lumine" or not inst.sg or inst.sg:HasStateTag("busy")
        or inst:HasTag("playerghost") or inst:HasTag("INLIMBO")
        or inst:HasTag("wereplayer") or inst:HasTag("sleeping")
        or inst.components.health:IsDead()
        or inst.is_teleporting then return false end
    if Glider.GetCooldown(inst)>0 then return false end
    if inst.components.rider and inst.components.rider:IsRiding() then return false end
    if inst.components.inventory and inst.components.inventory:IsHeavyLifting() then return false end
    local energy = inst.components.lumineenergy
    local journey = inst.components.luminejourney
    local wind = journey ~= nil and journey.active_element == "wind"
    if energy == nil or energy.current < (wind and Glider.TAKEOFF_WIND or Glider.TAKEOFF_OTHER) then return false end
    local x, _, z = inst.Transform:GetWorldPosition()
    return Ground.CanLand(inst, x, z)
end

local function NextState(inst, name)
    inst.sg.statemem.glider_continue = true
    inst.sg:GoToState(name)
end

function Glider.Toggle(inst)
    if not inst or inst.prefab ~= "lumine" or not inst.lumine_glider_phase then return false end
    local phase = inst.lumine_glider_phase:value()
    if phase == 2 and inst.sg.currentstate.name == STATES[2] then
        local x, _, z = inst.Transform:GetWorldPosition()
        if not Ground.CanLand(inst, x, z) then
            local saved, now = inst._lumine_glider, GetTime()
            if saved and (not saved.notice_time or now - saved.notice_time >= 2) then
                saved.notice_time = now
                if inst.components.talker then inst.components.talker:Say(L(1, "下方没有安全落脚点，飞到空旷的陆地或船上再降落吧。")) end
            end
            return false
        end
        NextState(inst, STATES[3])
        return true
    elseif phase == 0 then
        if not Glider.CanStart(inst) then
            if inst.components.talker then inst.components.talker:Say("需要安全的起飞地点与足够的元素力。") end
            return false
        end
        local wind = inst.components.luminejourney.active_element == "wind"
        inst.components.lumineenergy:Add(-(wind and Glider.TAKEOFF_WIND or Glider.TAKEOFF_OTHER))
        inst._lumine_glider_drain = wind and Glider.DRAIN_WIND or Glider.DRAIN_OTHER
        inst.sg:GoToState(STATES[1])
        return true
    end
    return false
end

local function Finite(n)
    return type(n) == "number" and n == n and math.abs(n) <= 1.01
end

function Glider.FinishGlide(inst)
    local saved = inst._lumine_glider
    if not saved then return end
    local x, _, z = inst.Transform:GetWorldPosition()
    if not Ground.CanLand(inst, x, z) then
        -- A solid obstacle on land/deck is not an ocean crash. Find clearance
        -- nearby; never recover to a distant shoreline after falling into water.
        local supported = TheWorld.Map:IsAboveGroundAtPoint(x, 0, z, false)
            or TheWorld.Map:GetPlatformAtPoint(x, z) ~= nil
        local point = supported and Ground.FindLanding(inst, { x = x, z = z })
            or Ground.RecoveryPoint(inst, saved)
        if point then inst.Physics:Teleport(point.x, 0, point.z) end
    end
    local lx, _, lz = inst.Transform:GetWorldPosition()
    if Ground.CanLand(inst, lx, lz) then
        NextState(inst, STATES[3])
    else
        inst.sg:GoToState("idle")
    end
end

local function GlideExpired(inst)
    local saved = inst._lumine_glider
    if saved and inst.components.lumineenergy.current <= 0 then
        Glider.FinishGlide(inst)
        return true
    end
    return false
end

function Glider.SetDirection(inst, x, z)
    local saved = inst and inst._lumine_glider
    if not saved or inst.lumine_glider_phase:value() ~= 2 or not Finite(x) or not Finite(z) then return end
    local length = math.sqrt(x * x + z * z)
    saved.dx, saved.dz = 0, 0
    if length > .01 then saved.dx, saved.dz = x / length, z / length end
    saved.input_time = GetTime()
end

function Glider.Eat(inst, food)
    local saved = inst and inst._lumine_glider
    if not saved or inst.lumine_glider_phase:value() ~= 2
        or inst.sg.currentstate.name ~= STATES[2] or inst.components.health:IsDead()
        or inst:HasTag("playerghost") or inst:HasTag("INLIMBO")
        or type(food) ~= "table" or type(food.IsValid) ~= "function" or not food:IsValid()
        or not food.components or not food.components.edible
        or not food.components.inventoryitem then return false end
    local inventory, eater = inst.components.inventory, inst.components.eater
    -- Only carried food (including an accessible backpack), never remote food
    -- or another player's inventory. Reuse native diet and consumption effects.
    if not inventory or not eater or not inventory:CanAccessItem(food)
        or food.components.inventoryitem:GetGrandOwner() ~= inst
        or not eater:PrefersToEat(food) then return false end
    local now = GetTime()
    if saved.eat_time and now < saved.eat_time then return false end
    saved.eat_time = now + Glider.EAT_INTERVAL
    local eaten = eater:Eat(food, inst)
    if eaten then inst.SoundEmitter:PlaySound("dontstarve/wilson/eat") end
    return eaten == true
end

function Glider.Update(inst, dt)
    local saved = inst._lumine_glider
    if not saved then return end
    if inst:HasTag("playerghost") or inst:HasTag("INLIMBO") or inst.components.health:IsDead() then
        inst.sg:GoToState("idle")
        return
    end
    local x, _, z = inst.Transform:GetWorldPosition()
    -- Correct external displacement/lag overshoot before accepting another move.
    if not Ground.InBounds(x, z) then
        local point = saved.last_air
        inst.Physics:SetMotorVelOverride(0, 0, 0)
        inst.Physics:Teleport(point.x, 0, point.z)
        return
    end
    saved.last_air = { x = x, z = z }
    local over_ocean = inst:GetCurrentPlatform() == nil and TheWorld.Map:IsOceanTileAtPoint(x, 0, z)
    local drain = inst._lumine_glider_drain * (over_ocean and EnergyRules.WING_OCEAN_MULTIPLIER or 1)
    inst.components.lumineenergy:Add(-drain * math.max(0, dt or 0))
    Glider.SyncTime(inst)
    if GlideExpired(inst) then return end
    local now = GetTime()
    if not saved.ground_check or now >= saved.ground_check then
        saved.ground_check = now + .2
        if Ground.CanLand(inst, x, z) then saved.safe = { x = x, z = z } end
    end
    local dx, dz = saved.dx or 0, saved.dz or 0
    local speed = inst.components.locomotor:GetRunSpeed() * Glider.SPEED
    -- Shores, walls and void tiles are traversable; only map bounds stop flight.
    local distance = speed * math.max(dt, FRAMES) + .45
    if not saved.input_time or GetTime() - saved.input_time > Glider.INPUT_TIMEOUT
        or (dx == 0 and dz == 0) or not Ground.InBounds(x + dx * distance, z + dz * distance) then
        inst.Physics:SetMotorVelOverride(0, 0, 0)
        return
    end
    -- FacePoint ignores busy states. Flight deliberately stays busy to block
    -- attacks, so rotate explicitly before applying the local forward motor.
    inst:ForceFacePoint(x + dx, 0, z + dz)
    inst.Physics:SetMotorVelOverride(speed, 0, 0)
end

function Glider.Impact(inst)
    if not inst._lumine_glider or inst.sg.statemem.impacted then return end
    inst.sg.statemem.impacted = true
    local x, _, z = inst.Transform:GetWorldPosition()
    if not Ground.CanLand(inst, x, z) then
        -- Terrain/obstacles can change during the descent animation.
        NextState(inst, STATES[2])
        return
    end
    local fx = SpawnPrefab("groundpoundring_fx")
    inst.lumine_glider_remaining:set(0)
    if fx then fx.Transform:SetPosition(x, 0, z) end
    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
end

function Glider.MasterInit(inst)
    for _, event in ipairs({ "death", "ms_becameghost", "onremove", "ms_playerdespawnanddelete" }) do
        inst:ListenForEvent(event, Glider.Cleanup)
    end
    -- Wrap both public and native DoAttack entries before armor wear, damage
    -- modifiers and attacked events. Accepted hits use the original pipeline;
    -- health, environmental damage and unrelated invincibility are untouched.
    for _, name in ipairs({"GetAttacked", "GetAttacked_Internal"}) do
        local combat = inst.components.combat
        local original = combat[name]
        combat[name] = function(self, attacker, damage, weapon, ...)
            if GroundMelee(inst, attacker, weapon) then return false end
            return original(self, attacker, damage, weapon, ...)
        end
    end
    -- Keep normal hunger running during the glider's short protected actions.
    -- Do not bypass invincibility that was already supplied by another source.
    local hunger, hunger_delta = inst.components.hunger, inst.components.hunger.DoDelta
    hunger.DoDelta = function(self, amount, overtime, ignore, ...)
        local saved = inst._lumine_glider
        return hunger_delta(self, amount, overtime,
            (saved ~= nil and saved.action_invincible == false) or ignore, ...)
    end
    -- Persist a recovery location without moving a live player during autosave.
    -- On load the vanilla player wrapper schedules drowning checks afterwards.
    local save, load = inst.OnSave, inst.OnLoad
    inst.OnSave = function(owner, data, ...)
        local result = save and save(owner, data, ...)
        data.lumine_glider_mode = nil
        if owner._lumine_glider then
            data.lumine_flight_recovery = { safe = owner._lumine_glider.safe, origin = owner._lumine_glider.origin }
        end
        return result
    end
    inst.OnLoad = function(owner, data, ...)
        if data and data.lumine_flight_recovery then
            local x, _, z = owner.Transform:GetWorldPosition()
            if not Ground.CanLand(owner, x, z) then
                local point = Ground.RecoveryPoint(owner, data.lumine_flight_recovery)
                if point then owner.Physics:Teleport(point.x, 0, point.z) end
            end
        end
        if load then return load(owner, data, ...) end
    end
    -- Also covers forced/queued attacks that bypass the keyboard and normal SG.
    local combat, attack = inst.components.combat, inst.components.combat.DoAttack
    combat.DoAttack = function(self, ...)
        if inst._lumine_glider then return end
        return attack(self, ...)
    end
end

function Glider.Install(G, add_state)
    local function Consume() return true end
    local function Events()
        return {
            G.EventHandler("locomote", Consume), G.EventHandler("doattack", Consume),
            G.EventHandler("attacked", Consume), G.EventHandler("knockback", Consume),
            G.EventHandler("repelled", Consume), G.EventHandler("firedamage", Consume),
            G.EventHandler("ontalk", Consume),
            G.EventHandler("onsink", Consume), G.EventHandler("onfallinvoid", Consume),
            G.EventHandler("freeze", function(inst)
                local c = inst.components.freezable
                if c and c:IsFrozen() then c:Unfreeze() end
                return true
            end),
            G.EventHandler("pinned", function(inst)
                local c = inst.components.pinnable
                if c and c:IsStuck() then c:Unstick() end
                return true
            end),
            G.EventHandler("gotosleep", function(inst)
                local c = inst.components.sleeper
                if c and c:IsAsleep() then c:WakeUp() end
                return true
            end),
        }
    end
    for phase, name in ipairs(STATES) do
        local slot = phase
        add_state("wilson", G.State {
            name = name,
            tags = { "busy", "pausepredict", "nomorph", "nointerrupt", "noelectrocute", "nofreeze", "nosleep", "overridelocomote" },
            onenter = function(inst)
                Begin(inst)
                local saved = inst._lumine_glider
                inst.lumine_glider_phase:set(slot)
                if slot ~= 2 then
                    saved.action_invincible = inst.components.health.invincible
                    inst.components.health:SetInvincible(true)
                end
                if inst._lumine_glider_light_visuals then WingLight.Refresh(inst) end
                inst.Physics:SetMotorVelOverride(0, 0, 0)
                if slot == 2 then
                    -- The old flight pose froze a 450-frame clip at frame 90.
                    -- Use the dedicated 48-frame flight cycle so wings and body keep moving.
                    inst.AnimState:Resume()
                    inst.AnimState:PlayAnimation("lumine_glider_fly", true)
                else
                    inst.AnimState:Resume()
                    inst.AnimState:PlayAnimation(name, false)
                end
                if slot == 1 then Hands(inst) else OpenHands(inst) end
                if slot == 1 then
                    inst.sg:SetTimeout(36 * G.FRAMES)
                elseif slot == 3 then
                    local start = 5
                    inst.AnimState:SetFrame(start)
                    Hands(inst)
                    inst.sg.statemem.impact_time = GetTime() + (16 - start) * G.FRAMES
                    inst.sg:SetTimeout((30 - start) * G.FRAMES)
                end
                Glider.SyncTime(inst)
            end,
            onupdate = slot == 2 and Glider.Update or slot == 3 and function(inst)
                if inst.sg.statemem.impacted then return end
                Glider.SyncTime(inst)
                if GetTime() >= inst.sg.statemem.impact_time then Glider.Impact(inst) end
            end or nil,
            timeline = slot == 3 and { G.TimeEvent(5 * G.FRAMES, Hands) }
                or slot == 1 and { G.TimeEvent(30 * G.FRAMES, OpenHands) } or nil,
            events = Events(),
            ontimeout = function(inst)
                if slot == 1 then NextState(inst, STATES[2]) else inst.sg:GoToState("idle") end
            end,
            onexit = function(inst)
                EndActionProtection(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
                if not inst.sg.statemem.glider_continue then Glider.Cleanup(inst) end
            end,
        })
    end
end

return Glider
