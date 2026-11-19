local F = require("fixtures")
local Rules = require("pyro/rules")
local Cast = require("flight/lumine_pyro_cast")

local function Near(actual, expected)
    assert(math.abs(actual - expected) < .0001, tostring(actual) .. " expected " .. tostring(expected))
end

local function Setup()
    F.world()
    local w = {time = 10, entities = {}, tasks = {}}
    GetTime = function() return w.time end
    FRAMES, DEGREES, MAX_PHYSICS_RADIUS = 1 / 30, math.pi / 180, 4
    Vector3 = function(x, y, z) return {x = x, y = y, z = z} end
    TheWorld.Map = {
        IsValidTileAtPoint = function() return true end,
        IsGroundTargetBlocked = function(_, point) return w.wall and point.x >= w.wall end,
    }
    TheSim = {FindEntities = function(_, x, _, z, radius, required, _, any)
        local found = {}
        for _, e in ipairs(w.entities) do
            local matches = required and e.components.combat or any and e:HasAnyTag(unpack(any))
            if matches and e:IsValid() and e:GetDistanceSqToPoint(x, 0, z) <= radius ^ 2 then
                found[#found + 1] = e
            end
        end
        return found
    end}
    local function Entity(prefab, x, z)
        local e = {prefab = prefab, x = x or 0, z = z or 0, tags = {}, handlers = {}, components = {}}
        e.Transform = {
            GetWorldPosition = function() return e.x, e.y or 0, e.z end,
            SetPosition = function(_, xx, yy, zz) e.x, e.y, e.z = xx, yy, zz end,
            GetRotation = function() return e.rotation or 0 end,
            SetRotation = function(_, rotation) e.rotation = rotation end,
        }
        e.entity = {IsVisible = function() return true end}
        function e:IsValid() return not self.removed end
        function e:GetDistanceSqToPoint(xx, _, zz) return (self.x - xx)^2 + (self.z - zz)^2 end
        function e:GetPhysicsRadius(default) return self.radius or default end
        function e:HasTag(tag) return self.tags[tag] == true end
        function e:HasAnyTag(...)
            for i = 1, select("#", ...) do if self:HasTag(select(i, ...)) then return true end end
            return false
        end
        function e:ListenForEvent(name, fn, source)
            local handlers = (source or self).handlers
            handlers[name] = handlers[name] or {}
            handlers[name][fn] = true
        end
        function e:RemoveEventCallback(name, fn) self.handlers[name][fn] = nil end
        function e:PushEvent(name, data)
            for fn in pairs(self.handlers[name] or {}) do fn(self, data) end
        end
        function e:Remove()
            self.removed = true
            self:PushEvent("onremove")
        end
        function e:AddChild(child) child.parent = self end
        local function Task(delay, fn, period)
            local task = {time = w.time + delay, owner = e, fn = fn, period = period}
            function task:Cancel() self.time = math.huge end
            w.tasks[#w.tasks + 1] = task
            return task
        end
        function e:DoTaskInTime(delay, fn) return Task(delay, fn) end
        function e:DoPeriodicTask(interval, fn, delay) return Task(delay or interval, fn, interval) end
        w.entities[#w.entities + 1] = e
        return e
    end

    function w.Advance(seconds)
        local limit = w.time + seconds
        while true do
            local next_task
            for _, task in ipairs(w.tasks) do
                if task.owner:IsValid() and task.time <= limit and (not next_task or task.time < next_task.time) then
                    next_task = task
                end
            end
            if not next_task then break end
            w.time = next_task.time
            next_task.time = next_task.period and w.time + next_task.period or math.huge
            next_task.fn(next_task.owner)
        end
        w.time = limit
    end

    function w.Target(x, z, tag)
        local e = Entity("test_target", x, z)
        e.tags[tag or "monster"] = true
        e.damage, e.hits = 0, 0
        e.scorch_damage, e.scorch_ticks = 0, 0
        e.components.health = {
            IsDead = function() return e.dead end,
            IsInvincible = function() return e.invincible end,
            GetFireDamageScale = function() return e.fire_scale or 1 end,
            DoDelta = function(_, amount, overtime, cause, _, owner)
                assert(overtime and cause == "lumine_pyro_scorch" and owner:HasTag("player"))
                e.scorch_damage, e.scorch_ticks = e.scorch_damage - amount, e.scorch_ticks + 1
            end,
        }
        e.components.combat = {
            IsAlly = function(_, other) return other.ally end,
            CanBeAttacked = function() return not e.invincible end,
            GetAttacked = function(_, _, damage)
                e.hits, e.damage = e.hits + 1, e.damage + damage
            end,
        }
        return e
    end

    SpawnPrefab = function(name)
        if name == w.missing then return end
        local entity = Entity(name)
        entity.spawned_at = w.time
        if name == "lumine_pyro_fireball" then
            function entity:PlayImpact()
                assert(self.move_task == nil and not self.impact)
                self.impact = {x = self.x, y = self.y, z = self.z}
                self:DoTaskInTime(.9, self.Remove)
            end
        end
        return entity
    end
    function w.List(prefab)
        local result = {}
        for _, entity in ipairs(w.entities) do
            if entity.prefab == prefab then result[#result + 1] = entity end
        end
        return result
    end
    local player = w.Target(0, 0, "player")
    w.player = player
    local c = player.components
    local function Mods()
        return {
            SetModifier = function(self, _, n, key) self[key] = n end,
            RemoveModifier = function(self, _, key) self[key] = nil end,
        }
    end
    c.luminejourney = {active_element = "pyro", CanResonate = function() return not w.locked end}
    c.combat.externaldamagemultipliers = Mods()
    c.hunger = {burnratemodifiers = Mods()}
    c.sanity = {DoDelta = function(_, amount) return amount end}
    local function Netvar(initial)
        return {n = initial, set = function(self, n) self.n = n end, value = function(self) return self.n end}
    end
    player._lumine_energy = Netvar(0)
    player._lumine_pyro_ring_ready = Netvar(0)
    player._lumine_pyro_burst = Netvar(false)
    player._lumine_pyro_streak = Netvar(0)
    player.AnimState = {
        PlayAnimation = function(_, name) player.anim = name end,
        PushAnimation = function() end,
        SetFrame = function(_, frame) player.anim_frame = frame end,
        GetSymbolPosition = function() return 0, 1.4, 0, true end,
    }
    player.SoundEmitter = {PlaySound = function() end}
    player.ClearBufferedAction = function() end
    c.locomotor = {Stop = function() end}
    c.lumineenergy = require("components/lumineenergy")(player)
    w.tasks[1]:Cancel()
    c.lumineenergy:Refill()
    local states = {idle = {name = "idle", tags = {}}}
    State = function(def) return def end
    Cast.Install(function(_, def) states[def.name] = def end)
    player.sg = {currentstate = states.idle}
    function player.sg:HasStateTag(tag)
        for _, value in ipairs(self.currentstate.tags) do if value == tag then return true end end
        return false
    end
    function player.sg:HasAnyStateTag(...)
        for i = 1, select("#", ...) do if self:HasStateTag(select(i, ...)) then return true end end
        return false
    end
    function player.sg:SetTimeout(delay)
        local current = self.currentstate
        player:DoTaskInTime(delay, function() if self.currentstate == current then current.ontimeout(player) end end)
    end
    function player.sg:GoToState(name, param)
        if self.currentstate.onexit then self.currentstate.onexit(player) end
        self.currentstate = states[name]
        if self.currentstate.onenter then self.currentstate.onenter(player, param) end
        player:PushEvent("newstate")
    end
    local pyro = require("components/luminepyro")(player)
    c.luminepyro = pyro
    return w, pyro, c.lumineenergy
end

return function(test)
    test("normal ring follows the caster and has exactly four area pulses", function()
        local w, pyro, energy = Setup()
        local first = w.Target(1, 0)
        local outside = w.Target(1.8, 0)
        local second = w.Target(8, 0)
        local friend = w.Target(8, 0, "companion")
        Near(w.player.components.combat.customdamagemultfn(), 1.1)
        Near(w.player.components.combat.customspdamagemultfn(), 1.1)
        assert(pyro:Press(1) and not pyro:Press(1))
        assert(energy.current == 82 and pyro.ring.parent == w.player and not w.player.anim)
        w.Advance(.1)
        assert(first.hits == 1 and outside.hits == 0 and second.hits == 0)
        w.player.x = 8
        w.Advance(6)
        assert(first.hits == 1 and second.hits == 3 and friend.hits == 0 and pyro.ring == nil)
        Near(second.damage, 72)
        Near(first.scorch_damage, 20)
        assert(first.scorch_ticks == 4 and outside.scorch_ticks == 0 and friend.scorch_ticks == 0)
        assert(not pyro:Press(1))
        local saved = pyro:OnSave()
        pyro:ResetCooldowns()
        pyro:OnLoad(saved)
        assert(not pyro:Press(1))
        w.Advance(5)
        assert(pyro:Press(1))
    end)

    test("burst applies reversible hunger and ongoing sanity costs", function()
        local w, pyro, energy = Setup()
        local c = w.player.components
        w.locked = true
        assert(not pyro:Press(1) and not pyro:ToggleBurst())
        w.locked = nil
        assert(pyro:ToggleBurst() and w.player._lumine_pyro_burst:value())
        assert(w.player.anim == "pyrocast_pre" and energy.current == 100)
        Near(c.hunger.burnratemodifiers.lumine_pyro_burst, 1.5)
        Near(c.sanity:DoDelta(-8, true), -12)
        Near(c.sanity:DoDelta(-8, false), -8)
        Near(c.sanity:DoDelta(8, true), 8)
        assert(pyro:ToggleBurst() and not w.player._lumine_pyro_burst:value())
        assert(not c.hunger.burnratemodifiers.lumine_pyro_burst and pyro.burst_fx == nil)
        Near(c.sanity:DoDelta(-8, true), -8)
    end)

    test("held input accelerates to the cadence cap and release resets the combo", function()
        local w, pyro, energy = Setup()
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(1) and not pyro:Press(1))
        assert(energy.current == 93)
        local intervals = {.5, .42, .34, .28, .23, .23}
        for _, interval in ipairs(intervals) do
            w.Advance(interval * .6)
            pyro:RenewHold(1)
            w.Advance(interval * .4 + .00001)
        end
        local orbs = w.List("lumine_pyro_fireball")
        assert(#orbs == 7 and energy.current == 51)
        for n, orb in ipairs(orbs) do
            Near(orb.damage, ({35, 45, 55, 65, 75, 75, 75})[n])
            if n > 1 then Near(orb.spawned_at - orbs[n-1].spawned_at, intervals[n-1]) end
        end
        assert(w.player._lumine_pyro_streak:value() == 5)
        pyro:Release(2)
        assert(pyro.hold_input == 1)
        pyro:Release(1)
        w.Advance(.51)
        assert(#w.List("lumine_pyro_fireball") == 7 and energy.current == 51)
        assert(pyro:Press(2))
        pyro:Release(2)
        Near(w.List("lumine_pyro_fireball")[8].damage, 35)
        assert(w.player._lumine_pyro_streak:value() == 0 and energy.current == 44)
    end)

    test("single explosion uses facing, includes larger targets and protects allies", function()
        local w, pyro, energy = Setup()
        local main = w.Target(0, -4)
        local side = w.Target(1.7, -4)
        local large = w.Target(4, -4, "epic")
        large.radius = 1.8
        local wrong = w.Target(3, 0)
        local structure = w.Target(.5, -4, "structure")
        structure.tags.hostile = true
        local friend = w.Target(0, -3)
        friend.ally = true
        local summon = w.Target(0, -3, "lunarplanttentacle")
        summon.tags.hostile = true
        local invincible = w.Target(.5, -4, "epic")
        invincible.invincible = true
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        w.player.rotation = 90
        assert(pyro:Press() and energy.current == 93)
        w.Advance(.8)
        for _, target in ipairs({main, side, large}) do assert(target.hits == 1) Near(target.damage, 38.5) end
        for _, target in ipairs({wrong, structure, friend, summon, invincible, w.player}) do assert(target.hits == 0) end
        local orb = w.List("lumine_pyro_fireball")[1]
        assert(orb.impact and orb.impact.y >= Rules.orb.cruise_height and orb.move_task == nil)
        Near(orb.x, 0)
        Near(orb.z, -4 + Rules.orb.contact)
        local ground = w.List("lumine_pyro_impact_ground")[1]
        Near(ground.y, 0)
        Near(ground.x, orb.impact.x)
        Near(ground.z, orb.impact.z)
        w.Advance(.55)
        assert(not orb:IsValid() and main.hits == 1)
    end)

    test("mouse aim updates between shots while controller and invalid targets use facing", function()
        local w, pyro = Setup()
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(1, 0, -10))
        local first = w.List("lumine_pyro_fireball")[1]
        Near(first.dx, 0)
        Near(first.dz, -1)
        Near(w.player.rotation, 90)
        pyro:RenewHold(1, 10, 0)
        w.Advance(.51)
        local second = w.List("lumine_pyro_fireball")[2]
        Near(second.dx, 1)
        Near(second.dz, 0)
        pyro:Release(1)
        w.Advance(.51)
        assert(pyro:Press(nil, math.huge, 0))
        local fallback = w.List("lumine_pyro_fireball")[3]
        Near(fallback.dx, 1)
        Near(fallback.dz, 0)
    end)

    test("insufficient energy, lost input, attack and element switch clean state", function()
        local w, pyro, energy = Setup()
        energy:Add(-93)
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(1) and energy.current == 0 and not pyro.burst and not pyro.hold_task)
        assert(w.List("lumine_pyro_fireball")[1]:IsValid())
        w.Advance(1)
        assert(not pyro:ToggleBurst())
        energy:Refill()
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(1))
        w.Advance(1.2)
        assert(pyro.burst and not pyro.hold_task and energy.current == 86)
        assert(pyro:Press(1))
        w.player:PushEvent("attacked", {damageresolved = 12})
        assert(not pyro.burst and not pyro.hold_task and w.player.sg.currentstate.name == Cast.RELEASE)
        w.Advance(.4)
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(2))
        w.player.components.luminejourney.active_element = "wind"
        w.player:PushEvent("lumine_element_resonated")
        assert(not pyro.burst and not pyro.hold_task and not next(pyro.orbs))
        Near(w.player.components.combat.customdamagemultfn(), 1)
        Near(pyro:GetDamageMultiplier(), 1)
        Near(w.player.components.combat.customspdamagemultfn(), 1)
    end)

    test("death and component reload end all transient effects", function()
        local w, pyro, energy = Setup()
        assert(pyro:Press())
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press(1))
        w.player:PushEvent("death")
        assert(not pyro.burst and not pyro.hold_task and not pyro.ring and not next(pyro.orbs))
        w.Advance(.4)
        assert(pyro:ToggleBurst())
        pyro:OnLoad({ring_remaining = 4})
        assert(not pyro.burst and not pyro.hold_task)
        Near(pyro.ring_ready - GetTime(), 4)
        assert(energy.current == 75)
    end)

    test("the orb explodes at a solid building but expires harmlessly after ten units", function()
        local w, pyro = Setup()
        local building = w.Target(3, 0, "structure")
        building.radius = .4
        building.Physics = {IsActive = function() return true end}
        local nearby = w.Target(1.9, 1.7)
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press())
        local orb = w.List("lumine_pyro_fireball")[1]
        w.Advance(.8)
        assert(orb.impact and orb.impact.x < 3 and orb.impact.x > 2 and orb.impact.y > 0)
        assert(orb.x == orb.impact.x and nearby.hits == 1 and building.hits == 0)
        building:Remove()
        nearby:Remove()
        local distant = w.Target(11, 0)
        assert(pyro:Press())
        orb = w.List("lumine_pyro_fireball")[2]
        w.Advance(.8)
        assert(not orb:IsValid() and not orb.impact and distant.hits == 0)
        Near(orb.x, 10)
    end)

    test("scorch replaces the passive multiplier, refreshes without stacking, and expires", function()
        local w, pyro = Setup()
        local scorched = w.Target(1, 0)
        local resistant = w.Target(1, .3)
        resistant.fire_scale = 0
        local other = w.Target(2, 0)
        local combat = w.player.components.combat
        assert(pyro:Press())
        w.Advance(.1)
        local mark = assert(scorched._lumine_pyro_scorch)
        assert(not resistant._lumine_pyro_scorch and mark.fx.parent == scorched)
        Near(combat.customdamagemultfn(w.player, other), 1.1)
        Near(combat.customdamagemultfn(w.player, scorched), 1.25)
        Near(combat.customspdamagemultfn(w.player, scorched), 1.25)
        require("lumine_direct_damage")(w.player, scorched, 10)
        Near(scorched.damage, 34.5)
        w.Advance(1.5)
        assert(scorched._lumine_pyro_scorch == mark and #w.List("lumine_pyro_scorch_fx") == 1)
        Near(scorched.scorch_damage, 5)
        w.player.x = 10
        w.Advance(4)
        assert(not scorched._lumine_pyro_scorch and not mark.fx:IsValid())
        Near(scorched.scorch_damage, 25)
        Near(combat.customdamagemultfn(w.player, scorched), 1.1)
    end)

    test("raised hand launch still detects a wall within the muzzle offset", function()
        local w, pyro = Setup()
        assert(pyro:ToggleBurst())
        w.Advance(.31)
        assert(pyro:Press())
        local orb = w.List("lumine_pyro_fireball")[1]
        Near(orb.x, Rules.orb.launch_offset)
        assert(orb.y > 1 and w.player.anim_frame == 3)
        w.Advance(.6)
        Near(orb.y, Rules.orb.cruise_height)
        w.wall = .4
        assert(pyro:Press())
        orb = w.List("lumine_pyro_fireball")[2]
        assert(orb.impact and orb.impact.x < .4 and orb.impact.y > 1)
    end)

    test("client keeps real key and button holds alive, then releases them", function()
        local w = Setup()
        local Input = require("pyro/input")
        local sent, held = {}, true
        local cursor = {x = 15, z = 6}
        local over_hud = false
        local controls = Input.New(function(operation, input, x, z)
            sent[#sent + 1] = operation .. input .. (x and ("@" .. x .. "," .. z) or "")
        end, function() return "mouse" end)
        CONTROL_PRIMARY, CONTROL_ACCEPT = 100, 101
        ThePlayer = w.player
        w.player.HUD = {IsChatInputScreenOpen = function() return false end}
        w.player._lumine_element_active = {value = function() return 6 end}
        w.player._lumine_pyro_burst:set(true)
        TheFrontEnd = {isprimary = true, GetActiveScreen = function() return w.player.HUD end}
        TheInput = {
            IsKeyDown = function(_, key) assert(key == 51) return held end,
            IsControlPressed = function(_, control) assert(control == CONTROL_PRIMARY) return held end,
            ControllerAttached = function() return false end,
            GetHUDEntityUnderMouse = function() return over_hud end,
            GetWorldPosition = function() return cursor end,
        }
        controls.Press(w.player, Input.KEY, 51)
        controls.Press(w.player, Input.KEY, 51)
        cursor = {x = 2, z = 8}
        w.Advance(.13)
        controls.Release(Input.KEY, 53)
        controls.Release(Input.KEY, 51)
        w.Advance(.5)
        assert(table.concat(sent, ";") == "press1@15,6;renew1@2,8;release1")
        local button = {down = true, IsVisible = function() return true end}
        over_hud = true
        controls.Press(w.player, Input.BUTTON, nil, button)
        TheFrontEnd.isprimary = false
        w.Advance(.13)
        held = false
        w.Advance(.13)
        assert(table.concat(sent, ";") == "press1@15,6;renew1@2,8;release1;press2;renew2;release2")
    end)
end
