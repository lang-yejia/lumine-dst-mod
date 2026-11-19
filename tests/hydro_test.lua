local F = require("fixtures")
local Cost = require("lumine_energy_rules").SKILL_COST

local function Setup()
    F.world()
    local w = {now = 30, effects = {}, enemies = {}, tasks = {}, random = 0}
    GetTime = function() return w.now end
    MAX_PHYSICS_RADIUS, TWOPI, DEGREES = 4, 2 * math.pi, math.pi / 180
    Vector3 = function(x, y, z) return {x = x, y = y, z = z} end
    FindWalkableOffset = function() return {x = 1.35, z = 0} end
    TheWorld.Map = {
        IsValidTileAtPoint = function() return true end,
        IsGroundTargetBlocked = function(_, point) return w.wall and point.x >= w.wall end,
    }
    TheSim = {FindEntities = function(_, x, _, z, radius, tags)
        local found = {}
        if tags then
            for _, e in ipairs(w.enemies) do
                if e:IsValid() and e:GetDistanceSqToPoint(x, 0, z) <= radius ^ 2 then found[#found + 1] = e end
            end
        end
        return found
    end}

    local function Entity(name, x, z)
        local e = {prefab = name, x = x, z = z, components = {}, tags = {}, events = {}}
        e.entity = {IsVisible = function() return true end}
        e.Transform = {
            SetPosition = function(_, a, _, b) e.x, e.z = a, b end,
            GetRotation = function() return e.angle or 0 end,
            SetRotation = function(_, a) e.angle = a end,
            GetWorldPosition = function() return e.x, 0, e.z end,
            SetScale = function() end,
        }
        e.Physics = {
            Teleport = e.Transform.SetPosition,
            SetMotorVelOverride = function(_, speed) e.motor_speed = speed end,
            ClearMotorVelOverride = function() e.motor_speed = nil end,
            Stop = function() e.motor_speed = nil end,
        }
        e.AnimState = {
            SetMultColour = function(_, _, _, _, a) e.alpha = a end,
            SetDeltaTimeMultiplier = function() end,
            IsCurrentAnimation = function(_, name) return e.animation == name end,
            PlayAnimation = function(_, name) e.animation = name end,
            PushAnimation = function(_, name, loop) e.queued_animation, e.queued_loop = name, loop end,
        }
        function e:GetPosition() return Vector3(self.x, 0, self.z) end
        function e:GetDistanceSqToPoint(a, _, b) return (a - self.x)^2 + (b - self.z)^2 end
        function e:GetPhysicsRadius(default) return self.radius or default end
        function e:IsNear(other, r) return self:GetDistanceSqToPoint(other.x, 0, other.z) <= r^2 end
        function e:IsValid() return not self.removed end
        function e:HasTag(tag) return self.tags[tag] == true end
        function e:HasAnyTag(...)
            for i = 1, select("#", ...) do if self:HasTag(select(i, ...)) then return true end end
            return false
        end
        function e:AddTag(tag) self.tags[tag] = true end
        function e:RemoveTag(tag) self.tags[tag] = nil end
        function e:Hide() self.hidden = true end
        function e:ListenForEvent(event, fn)
            self.events[event] = self.events[event] or {}
            table.insert(self.events[event], fn)
        end
        function e:PushEvent(event, data)
            for _, fn in ipairs(self.events[event] or {}) do fn(self, data) end
        end
        function e:Remove() self:PushEvent("onremove") self.removed = true end
        local function AddTask(delay, fn, repeating, initial)
            local task = {owner = e, time = w.now + (initial or delay), fn = fn, period = repeating and delay}
            function task:Cancel() self.time = math.huge end
            w.tasks[#w.tasks + 1] = task
            return task
        end
        function e:DoTaskInTime(delay, fn) return AddTask(delay, fn) end
        function e:DoPeriodicTask(delay, fn, initial) return AddTask(delay, fn, true, initial) end
        local max = name == "lumine_hydro_bubble" and 400 or 1000
        local health = {currenthealth = max, maxhealth = max}
        function health:IsDead() return self.currenthealth <= 0 end
        function health:IsHurt() return self.currenthealth < self.maxhealth end
        function health:GetPercent() return self.currenthealth / self.maxhealth end
        function health:IsInvincible() return e.invincible end
        function health:DoDelta(n)
            if self:IsDead() or self:IsInvincible() then return end
            local old = self:GetPercent()
            self.currenthealth = math.max(0, math.min(self.currenthealth + n, self.maxhealth))
            if self:IsDead() then e:PushEvent("death") end
            e:PushEvent("healthdelta", {oldpercent = old, newpercent = self:GetPercent()})
        end
        e.components.health = health
        e.components.locomotor = {}
        local combat = {}
        function combat:ShouldAggro(target) return not target.ignored end
        function combat:CanTarget(target) return target:IsValid() and not target:HasTag("notarget") end
        function combat:CanBeAttacked() return not e.protected end
        function combat:IsAlly(target) return target.ally end
        function combat:SetTarget(target) self.target = target end
        function combat:SuggestTarget(target) if not self.target then self:SetTarget(target) end end
        function combat:DropTarget() self.target = nil end
        function combat:GetAttacked(attacker, damage, _, stimuli)
            if e.invincible then return end
            health:DoDelta(-damage)
            e[stimuli or "hit"] = (e[stimuli or "hit"] or 0) + 1
        end
        e.components.combat = combat
        return e
    end

    local function MoveTo(time)
        for _, effect in ipairs(w.effects) do
            if effect:IsValid() and effect.motor_speed then
                local distance = effect.motor_speed * (time - w.now)
                local angle = effect.Transform:GetRotation() * DEGREES
                effect.x = effect.x + math.cos(angle) * distance
                effect.z = effect.z - math.sin(angle) * distance
            end
        end
        w.now = time
    end

    function w.advance(seconds)
        local stop = w.now + seconds
        while true do
            local next_task
            for _, task in ipairs(w.tasks) do
                if task.time <= stop and task.owner:IsValid() and (not next_task or task.time < next_task.time) then
                    next_task = task
                end
            end
            if not next_task then break end
            MoveTo(next_task.time)
            next_task.time = next_task.period and w.now + next_task.period or math.huge
            next_task.fn(next_task.owner)
        end
        MoveTo(stop)
    end
    function w.enemy(x, z)
        local e = Entity("enemy", x, z)
        e:AddTag("monster")
        table.insert(w.enemies, e)
        return e
    end
    SpawnPrefab = function(name)
        local e = Entity(name, 0, 0)
        w.effects[#w.effects + 1] = e
        return e
    end
    local owner = Entity("lumine", 0, 0)
    w.owner = owner
    owner.components.luminejourney = {active_element = "hydro", CanResonate = function() return true end}
    owner.components.hunger = {current = 100, DoDelta = function(self, n) self.current = self.current + n end}
    owner.components.lumineenergy = {current = 100, CanSpend = function(self, id) return self.current >= Cost[id] end,
        Spend = function(self, id)
        if self.current < Cost[id] then return false end
        self.current = self.current - Cost[id]
        return true
    end}
    owner.sg = {currentstate = {name = "lumine_hydro_cast"}}
    function owner.sg:HasState(name) return name == "lumine_hydro_cast" end
    function owner.sg:HasAnyStateTag() return false end
    function owner.sg:GoToState(_, aim) self.aim = aim end
    for _, field in ipairs({"stream_ready", "bubble_ready", "bubble_until", "bubble_hp"}) do
        owner["_lumine_hydro_" .. field] = {set = function(self, v) self.value = v end}
    end
    w.skill = require("components/luminehydro")(owner)
    function w.onhit(enemy, random, sword)
        local original = math.random
        math.random = function() return random end
        local ok, err = pcall(w.skill.OnHit, w.skill, {target=enemy, weapon={HasTag=function() return sword end},
            damageresolved=1, from_doattack=true})
        math.random = original
        assert(ok, err)
    end
    function w.cast(skill) return w.skill:Release({skill = skill, rotation = 0, dx = 1, dz = 0}) end
    return w
end

return function(test)
    test("drop proc is single-roll, 20 percent and gated by weapon and 3s interval", function()
        local w = Setup()
        local t = w.enemy(2, 0)
        w.onhit(t, .2, true)
        w.onhit(t, 0, true)
        assert(#w.effects == 0)
        w.advance(.1)
        w.onhit(t, 0, false)
        assert(#w.effects == 0)
        w.onhit(t, .199, true)
        assert(#w.effects == 1)
        w.advance(2.95)
        w.onhit(t, 0, true)
        assert(#w.effects == 1)
        w.advance(.1)
        t.components.health:DoDelta(-1000)
        t:AddTag("noattack")
        w.onhit(t, 0, true)
        assert(#w.effects == 2)
    end)

    test("only owner contact can pay 5 hunger for 15 HP, cap and expiry", function()
        local w = Setup()
        local t = w.enemy(2, 0)
        w.onhit(t, 0, true)
        local d = w.effects[1]
        t.x = d.x
        w.advance(.2)
        assert(d:IsValid())
        w.owner.x = d.x
        w.advance(.2)
        assert(d:IsValid() and w.owner.components.hunger.current == 100)
        w.owner.components.health:DoDelta(-9)
        w.owner.components.hunger.current = 4
        w.advance(.3)
        assert(d:IsValid() and w.owner.components.health.currenthealth == 991)
        w.owner.components.hunger.current = 10
        w.advance(.2)
        assert(not d:IsValid() and w.owner.components.hunger.current == 5 and w.owner.components.health.currenthealth == 1000)
        w.advance(3)
        w.onhit(t, 0, true)
        local next_drop = w.effects[#w.effects]
        w.advance(12.1)
        assert(not next_drop:IsValid())
    end)

    test("stream passes through enemies once, blocks at terrain, wet clears safely", function()
        local w = Setup()
        w.wall = 4.6
        local a, b, behind, side = w.enemy(2, .8), w.enemy(4, 0), w.enemy(5.2, 0), w.enemy(3, 1.5)
        b:AddTag("wet")
        assert(w.cast("stream") and not w.cast("stream"))
        w.advance(.8)
        assert(a.components.health.currenthealth == 945 and b.components.health.currenthealth == 945)
        assert(a.lumine_hydro_stream == 1 and a:HasTag("wet") and b:HasTag("wet"))
        assert(not behind.lumine_hydro_stream and not side.lumine_hydro_stream and w.effects[1].removed)
        assert(w.owner.components.lumineenergy.current == 88)
        w.advance(5.1)
        assert(not a:HasTag("wet") and b:HasTag("wet"))
    end)

    test("stream follows validated mouse or facing direction using the same visual angle", function()
        local w = Setup()
        w.owner.angle = 180
        assert(w.skill:Cast("stream", 0, 45))
        local aim = assert(w.owner.sg.aim)
        assert(math.abs(aim.dx) < .001 and aim.dz == 1 and aim.rotation == -90)
        local forward, mouse = w.enemy(-3, 0), w.enemy(0, 3)
        assert(w.skill:Release(aim))
        w.advance(.6)
        assert(mouse.lumine_hydro_stream == 1 and not forward.lumine_hydro_stream)
        w.skill:ResetCooldowns()
        assert(w.skill:Cast("stream", math.huge, 0 / 0))
        aim = assert(w.owner.sg.aim)
        assert(aim.dx == -1 and math.abs(aim.dz) < .001)
    end)

    test("bubble uses mouse direction while facing remains the fallback", function()
        local w = Setup()
        w.owner.angle = 180
        assert(w.skill:Cast("bubble"))
        assert(w.owner.sg.aim.rotation == 180 and w.owner.sg.aim.dx == -1)
        assert(w.skill:Cast("bubble", 0, 45))
        local aim = w.owner.sg.aim
        assert(aim.rotation == -90 and math.abs(aim.dx) < .001 and aim.dz == 1)
        assert(w.skill:Release(aim))
        local b = w.skill.bubble
        w.advance(.6)
        assert(b.z > 1.8 and math.abs(b.x) < .001)
    end)

    test("bubble moves, stops at a blocker, controls normal targets and respects boss aggro", function()
        local w = Setup()
        w.wall = 3.5
        local a, boss, idle_boss, friend, immune = w.enemy(2, 0), w.enemy(4, 0), w.enemy(3, 1), w.enemy(3, -1), w.enemy(3, 2)
        boss:AddTag("epic")
        idle_boss:AddTag("epic")
        immune:AddTag("notaunt")
        friend.ally = true
        a.components.combat.target, boss.components.combat.target = w.owner, w.owner
        assert(w.cast("bubble"))
        local b = w.skill.bubble
        assert(a.components.combat.target == b and idle_boss.components.combat.target == b)
        assert(boss.components.combat.target == w.owner and not friend.components.combat.target and not immune.components.combat.target)
        assert(b.motor_speed == 1.25)
        w.advance(.5)
        assert(b.x > 1.74 and b.x < 1.775 and b.motor_speed < 1.25)
        w.advance(2.1)
        assert(b.x < 3.5 and b.x > 3.4 and not b.hydro.move_task)
        assert(a.lumine_hydro_pulse == 2 and boss.lumine_hydro_pulse == 2 and not friend.lumine_hydro_pulse)
        w.owner.components.luminejourney.active_element = "none"
        w.owner:PushEvent("lumine_element_resonated")
        assert(b.removed and a.components.combat.target == w.owner and not idle_boss.components.combat.target)
        assert(not a.lumine_hydro_blast and next(w.skill.effects) == nil)
    end)

    test("bubble decelerates to rest before its lifetime ends", function()
        local w = Setup()
        assert(w.cast("bubble"))
        local b = w.skill.bubble
        assert(b.motor_speed == 1.25)
        w.advance(2.05)
        local speed = b.motor_speed
        assert(speed > .8 and speed < .86)
        w.advance(2)
        assert(b.motor_speed > .38 and b.motor_speed < .44)
        w.advance(2)
        local stopped = b.x
        assert(not b.motor_speed and not b.hydro.move_task and b:IsValid())
        w.advance(1)
        assert(b.x == stopped and b:IsValid())
    end)

    test("native-style damage dims bubble and either expiry path bursts once", function()
        for _, lethal in ipairs({true, false}) do
            local w = Setup()
            w.wall = 2.4
            local target = w.enemy(2, 0)
            assert(w.cast("bubble"))
            local b = w.skill.bubble
            assert(b.components.health.currenthealth == 400)
            b.components.combat:GetAttacked(target, 300)
            assert(b.alpha == .85 and w.owner._lumine_hydro_bubble_hp.value == 100)
            assert(b.animation == "orb_hit" and b.queued_animation == "orb" and b.queued_loop)
            b.animation = "orb"
            b.components.health:DoDelta(10)
            assert(b.animation == "orb")
            if lethal then
                b.components.combat:GetAttacked(target, 110)
                b:PushEvent("death")
                assert(target.lumine_hydro_blast == 1 and not target.components.combat.target)
            end
            w.advance(8.1)
            assert(target.lumine_hydro_blast == 1 and b.removed and not w.skill.bubble)
            local pulses = target.lumine_hydro_pulse
            w.advance(1)
            assert(pulses == target.lumine_hydro_pulse and w.owner._lumine_hydro_bubble_hp.value == 0)
        end
    end)

    test("a player removal clears the water bubble and preserves only cooldown values", function()
        local w = Setup()
        local enemy = w.enemy(2, 0)
        assert(w.cast("stream") and w.cast("bubble"))
        local b = w.skill.bubble
        w.advance(.5)
        local save = w.skill:OnSave()
        assert(save.stream == 6.5 and save.bubble == 24.5)
        w.owner:PushEvent("ms_playerdespawnanddelete")
        assert(b.removed and not enemy.lumine_hydro_blast and not enemy.components.combat.target)
        local fresh = Setup()
        fresh.skill:OnLoad(save)
        assert(not fresh.skill.bubble and not fresh.cast("bubble") and not fresh.cast("stream"))
        fresh.advance(6.6)
        assert(fresh.cast("stream") and not fresh.cast("bubble"))
    end)
end
