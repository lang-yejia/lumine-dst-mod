local F = require("fixtures")
local Dash = require("flight/lumine_wind_dash")
local TornadoCast = require("flight/lumine_wind_tornado_cast")

local function Setup()
    F.world()
    FRAMES, DEGREES, MAX_PHYSICS_RADIUS = 1 / 30, math.pi / 180, 4
    GetTime = function() return 30 end
    State = function(definition) return definition end
    FrameEvent = function(frame, fn) return {frame = frame, fn = fn} end
    local states = {}
    local function Install(graph, definition)
        assert(graph == "wilson")
        states[definition.name] = definition
    end
    Dash.Install(Install)
    TornadoCast.Install(Install)

    local inst = F.player()
    local world = {shore = math.huge, blockers = {}}
    TheWorld.Map = {
        IsPassableAtPoint = function(_, x) return x < world.shore end,
        IsVisualGroundAtPoint = function() return true end,
    }
    TheSim = {FindEntities = function() return world.blockers end}
    SpawnPrefab = function(name) error("unexpected dash prefab: " .. tostring(name)) end

    inst.x, inst.z, inst.rotation = 0, 0, 0
    inst.Transform = {
        GetWorldPosition = function() return inst.x, 0, inst.z end,
        GetRotation = function() return inst.rotation end,
    }
    function inst:ForceFacePoint(x, _, z)
        self.rotation = math.atan2(self.z - z, x - self.x) / DEGREES
    end
    function inst:GetPhysicsRadius() return .5 end
    function inst:GetCurrentPlatform() return self.platform end
    function inst:ClearBufferedAction() end
    inst.AnimState = {
        PlayAnimation = function(_, name) inst.animation = name end,
        PushAnimation = function(_, name) inst.queued_animation = name end,
        SetDeltaTimeMultiplier = function(_, rate) inst.animation_rate = rate end,
    }
    inst.SoundEmitter = {PlaySound = function() end}
    inst.Physics = {
        SetMotorVelOverride = function(_, speed) inst.speed = speed end,
        ClearMotorVelOverride = function() inst.speed = nil end,
        Teleport = function(_, x, _, z)
            inst.x, inst.z = x, z
            inst.teleports = (inst.teleports or 0) + 1
        end,
    }
    inst.sg = {name = "idle", statemem = {}}
    function inst.sg:HasState(name) return states[name] ~= nil end
    function inst.sg:HasStateTag(tag)
        local state = states[self.name]
        if not state then return false end
        for _, state_tag in ipairs(state.tags) do
            if state_tag == tag then return true end
        end
        return false
    end
    function inst.sg:SetTimeout(value) self.timeout = value end
    function inst.sg:GoToState(name, plan)
        local previous = states[self.name]
        if previous then previous.onexit(inst) end
        self.name, self.statemem, self.frame = name, {}, 0
        if states[name] then states[name].onenter(inst, plan) end
    end
    function inst:Advance(count)
        for _ = 1, count do
            local state = states[self.sg.name]
            if not state then break end
            if self.speed then
                local angle = self.rotation * DEGREES
                self.x = self.x + math.cos(angle) * self.speed * FRAMES
                self.z = self.z - math.sin(angle) * self.speed * FRAMES
            end
            self.sg.frame = self.sg.frame + 1
            self.sg.timeout = self.sg.timeout - FRAMES
            if self.sg.timeout <= .0001 then
                state.ontimeout(self)
            else
                for _, event in ipairs(state.timeline or {}) do
                    if event.frame == self.sg.frame then event.fn(self) end
                end
                if state.onupdate then state.onupdate(self) end
            end
        end
    end

    inst.components.health = {IsDead = function() return inst.dead == true end}
    inst.components.locomotor = {Stop = function() end}
    inst.components.combat = {
        GetAttacked_Internal = function() inst.hits = (inst.hits or 0) + 1 return true end,
    }
    inst.components.luminejourney = {active_element = "wind", CanResonate = function() return true end}
    for _, name in ipairs({"_lumine_energy", "_lumine_wind_skills", "_lumine_wind_dash_ready",
        "_lumine_wind_tornado_ready"}) do
        inst[name] = inst[name] or {set = function() end}
    end
    inst.components.lumineenergy = require("components/lumineenergy")(inst)
    inst.components.lumineenergy:Add(40)
    inst.components.luminewind = require("components/luminewind")(inst)
    return inst, inst.components.luminewind, world
end

local function Blocker(x, radius)
    return {
        IsValid = function() return true end,
        GetPhysicsRadius = function() return radius end,
        Transform = {GetWorldPosition = function() return x, 0, 0 end},
        Physics = {IsActive = function() return true end},
    }
end

return function(test)
    test("aimed dash travels five units continuously and charges once", function()
        local inst, wind = Setup()
        assert(wind:CastDash(0, 3))
        assert(inst.animation == "atk_leap_lag" and inst.x == 0 and inst.z == 0)
        assert(inst.components.lumineenergy.current == 20 and wind.dash_ready == 36)
        assert(not wind:CastDash())
        inst:Advance(15)
        assert(math.abs(inst.x) < .001 and math.abs(inst.z - 5) < .001)
        assert(inst.sg.name == "idle" and inst.speed == nil and inst.teleports == nil)
        assert(not wind:CastDash() and inst.components.lumineenergy.current == 20)
    end)

    test("facing fallback and shoreline stop without crossing", function()
        local inst, wind, world = Setup()
        world.shore = 3
        assert(wind:CastDash(0 / 0, math.huge))
        inst:Advance(15)
        assert(inst.x >= 2.5 and inst.x < 3 and inst.z == 0 and inst.speed == nil)
    end)

    test("a blocked start does not consume energy or start cooldown", function()
        local inst, wind, world = Setup()
        world.blockers = {Blocker(1, .5)}
        assert(not wind:CastDash())
        assert(inst.components.lumineenergy.current == 40 and wind.dash_ready == 0)
    end)

    test("obstacles added mid-dash stop the motor", function()
        local inst, wind, world = Setup()
        assert(wind:CastDash())
        inst:Advance(1)
        world.blockers = {Blocker(3, .5)}
        inst:Advance(15)
        assert(inst.x > .8 and inst.x <= 2 and inst.sg.name == "idle" and inst.speed == nil)
    end)

    test("a new obstacle can invalidate the previous recovery point", function()
        local inst, wind, world = Setup()
        assert(wind:CastDash())
        inst:Advance(2)
        world.blockers = {Blocker(2, .5)}
        inst:Advance(1)
        assert(inst.x >= 0 and inst.x <= 1 and inst.teleports == 1 and inst.speed == nil)
    end)

    test("ordinary and planar attacks are dodged only during the dash", function()
        local inst, wind = Setup()
        local combat, attacker = inst.components.combat, {}
        assert(combat:GetAttacked_Internal(attacker, 30))
        assert(wind:CastDash())
        assert(not combat:GetAttacked_Internal(attacker, 30))
        assert(not combat:GetAttacked_Internal(attacker, 0, nil, nil, {planar = 30}))
        assert(combat:GetAttacked_Internal(nil, 30))
        inst.sg:GoToState("hit")
        assert(inst.speed == nil and combat:GetAttacked_Internal(attacker, 30))
        assert(inst.hits == 3 and #inst.events == 2)
    end)

    test("an older cooldown is capped and zero energy blocks casting", function()
        local inst, wind = Setup()
        wind:OnLoad({dash_remaining = 9})
        assert(wind.dash_ready == 36)
        wind:OnLoad({dash_remaining = 0})
        inst.components.lumineenergy:Add(-40)
        assert(not wind:CastDash() and inst.sg.name == "idle" and wind.dash_ready == 30)
    end)

    test("wind tornado uses the aimed contact frame and pays only once", function()
        local inst, wind = Setup()
        local spawned = 0
        SpawnPrefab = function(name)
            assert(name == "lumine_wind_tornado")
            spawned = spawned + 1
            return {
                Transform = {SetPosition = function(_, x, _, z)
                    assert(math.abs(x) < .001 and z == 1.5)
                end},
                SetCaster = function(_, caster, dx, dz)
                    assert(caster == inst and dx == 0 and dz == 1)
                end,
            }
        end
        assert(wind:CastTornado(0, 6))
        assert(inst.animation == "staff_pre" and inst.animation_rate == 2)
        inst:Advance(4)
        assert(inst.animation == "atk_pre" and inst.queued_animation == "atk" and inst.animation_rate == 1.6)
        inst:Advance(4)
        assert(spawned == 0 and inst.components.lumineenergy.current == 40 and wind.tornado_ready == 0)
        inst:Advance(1)
        assert(spawned == 1 and inst.components.lumineenergy.current == 5 and wind.tornado_ready == 65)
        inst:Advance(10)
        assert(spawned == 1 and inst.animation_rate == 1 and inst.sg.name == "idle")
    end)

    test("a hit before wind tornado contact interrupts without wasting energy", function()
        local inst, wind = Setup()
        assert(wind:CastTornado())
        inst:Advance(8)
        inst.sg:GoToState("hit")
        inst:Advance(10)
        assert(wind.tornado_ready == 0 and inst.components.lumineenergy.current == 40)
        assert(inst.animation_rate == 1)
    end)

    test("wind tornado rechecks the path at contact", function()
        local inst, wind, world = Setup()
        assert(wind:CastTornado())
        inst:Advance(8)
        world.shore = 1.1
        inst:Advance(1)
        assert(wind.tornado_ready == 0 and inst.components.lumineenergy.current == 40)
    end)

    test("resetting wind cooldowns clears both saved timers", function()
        local _, wind = Setup()
        wind:OnLoad({dash_remaining = 3, tornado_remaining = 20})
        wind:ResetCooldowns()
        local saved = wind:OnSave()
        assert(wind.dash_ready == 0 and wind.tornado_ready == 0)
        assert(saved.dash_remaining == 0 and saved.tornado_remaining == 0)
    end)
end
