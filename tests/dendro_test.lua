local F = require("fixtures")
local Rules = require("lumine_dendro_rules")
local EnergyRules = require("lumine_energy_rules")
local Cast = require("flight/lumine_dendro_cast")

local function Setup()
    F.world()
    local now, tasks, spawns, enemies = 40, {}, {}, {}
    GetTime = function() return now end
    TWOPI, DEGREES, FRAMES, MAX_PHYSICS_RADIUS = 2 * math.pi, math.pi / 180, 1 / 30, 4
    TheWorld.Map = {
        IsPointNearHole = function() return false end,
        IsValidTileAtPoint = function() return false end,
        IsOceanTileAtPoint = function() return false end,
    }
    State = function(state) return state end
    FrameEvent = function(frame, fn) return {time = frame * FRAMES, fn = fn} end
    local cast_state
    Cast.Install(function(graph, state)
        assert(graph == "wilson")
        cast_state = state
    end)
    FindWalkableOffset = function() return {x = 1.6, z = 0} end
    local function Entity(prefab, x, z)
        local inst = F.player()
        inst.prefab, inst.x, inst.z = prefab, x or 0, z or 0
        inst.handlers = {}
        inst.Transform = {
            GetWorldPosition = function() return inst.x, 0, inst.z end,
            SetPosition = function(_, px, _, pz) inst.x, inst.z = px, pz end,
            GetRotation = function() return inst.angle or 0 end,
            SetScale = function(_, scale) inst.scale = scale end,
        }
        function inst:GetPosition() return {x = self.x, y = 0, z = self.z} end
        function inst:GetPhysicsRadius(default) return self.radius or default end
        function inst:HasAnyTag(...)
            for i = 1, select("#", ...) do
                if self:HasTag(select(i, ...)) then return true end
            end
            return false
        end
        inst.entity = {
            IsVisible = function() return not inst.invisible end,
            SetParent = function(_, parent) inst.parent = parent end,
        }
        function inst:ListenForEvent(name, fn, source)
            source = source or self
            source.handlers[name] = source.handlers[name] or {}
            source.handlers[name][fn] = self
        end
        function inst:RemoveEventCallback(name, fn, source)
            local list = (source or self).handlers[name]
            if list then list[fn] = nil end
        end
        function inst:PushEvent(name, data)
            local callbacks = {}
            for fn in pairs(self.handlers[name] or {}) do callbacks[#callbacks + 1] = fn end
            for _, fn in ipairs(callbacks) do
                local listener = self.handlers[name][fn]
                if listener and listener:IsValid() then fn(self, data) end
            end
        end
        function inst:Remove()
            self:PushEvent("onremove")
            self.removed = true
        end
        local function Schedule(delay, fn, initial, periodic)
            local task = {time = now + (initial or delay), fn = fn,
                period = periodic and delay, inst = inst}
            function task:Cancel() self.time = math.huge end
            tasks[#tasks + 1] = task
            return task
        end
        function inst:DoTaskInTime(delay, fn) return Schedule(delay, fn) end
        function inst:DoPeriodicTask(delay, fn, initial) return Schedule(delay, fn, initial, true) end
        inst.components.health = {maxhealth = 2000, IsDead = function() return inst.dead end,
            IsInvincible = function() return inst.invulnerable end}
        inst.components.combat = {
            CanTarget = function() return not inst.locked_target end,
            CanBeAttacked = function() return not inst.protected end,
            IsAlly = function(_, target) return target.ally end,
            SetDefaultDamage = function(self, damage) self.damage = damage end,
            SetTarget = function(self, target) self.target = target end,
            DoAttack = function(self) self.attacks = (self.attacks or 0) + 1 end,
            GetAttacked = function(_, source, damage, _, stimuli)
                inst.hits = (inst.hits or 0) + 1
                inst.damage = (inst.damage or 0) + (inst.invulnerable and 0 or damage)
                inst:PushEvent("attacked", {attacker = source, stimuli = stimuli,
                    damageresolved = inst.invulnerable and 0 or damage})
            end,
        }
        inst.components.locomotor = {
            SetExternalSpeedMultiplier = function(_, _, _, speed) inst.speed = speed end,
            RemoveExternalSpeedMultiplier = function() inst.speed = nil end,
        }
        inst.components.planardamage = {SetBaseDamage = function(_, damage) inst.planar = damage end}
        inst.AnimState = {
            SetDeltaTimeMultiplier = function() end,
            Hide = function(_, symbol) inst.hidden_symbol = symbol end,
        }
        inst.SoundEmitter = {PlaySound = function() end}
        return inst
    end
    SpawnPrefab = function(name)
        local inst = Entity(name)
        if name == "sleepcloud_lunar" then
            inst._drowsytask = inst:DoPeriodicTask(.5, function() error("vanilla sleep must not run") end)
            inst.components.timer = {SetTimeLeft = function(_, timer, duration)
                assert(timer == "disperse")
                inst:DoTaskInTime(duration + 3, inst.Remove)
            end}
            function inst:SetOwner(source) self.owner = source end
        end
        function inst:Pop()
            self.popped = true
            self:DoTaskInTime(.6, self.Remove)
        end
        function inst:Retract() self:Remove() end
        spawns[#spawns + 1] = inst
        return inst
    end
    TheSim = {FindEntities = function(_, x, _, z, radius)
        local found = {}
        for _, enemy in ipairs(enemies) do
            if (enemy.x - x)^2 + (enemy.z - z)^2 <= radius^2 then found[#found + 1] = enemy end
        end
        return found
    end}
    local owner = Entity("lumine")
    owner.AnimState = {
        PlayAnimation = function(_, name) owner.anim = name end,
        PushAnimation = function(_, name) owner.queued_anim = name end,
        SetDeltaTimeMultiplier = function(_, rate) owner.rate = rate end,
    }
    owner.components.locomotor.Stop = function() end
    owner.ClearBufferedAction = function() end
    function owner:ForceFacePoint(x, _, z) self.facing = {x = x, z = z} end
    local function NetVar()
        return {set = function(self, value) self.value = value end}
    end
    owner._lumine_dendro_root_ready = NetVar()
    owner._lumine_dendro_field_ready = NetVar()
    owner._lumine_dendro_field_until = NetVar()
    owner.sg = {currentstate = {name = "idle"}, statemem = {}}
    function owner.sg:HasAnyStateTag() return self.currentstate == cast_state end
    function owner.sg:HasState(name) return name == cast_state.name end
    function owner.sg:GoToState(name, data)
        if self.currentstate == cast_state then cast_state.onexit(owner) end
        self.currentstate = {name = name}
        self.statemem = {}
        if name == cast_state.name then
            self.currentstate = cast_state
            cast_state.onenter(owner, data)
            for _, event in ipairs(cast_state.timeline) do
                owner:DoTaskInTime(event.time, function()
                    if self.currentstate == cast_state then event.fn(owner) end
                end)
            end
        end
    end
    function owner.sg:SetTimeout(timeout)
        owner:DoTaskInTime(timeout, function()
            if self.currentstate == cast_state then cast_state.ontimeout(owner) end
        end)
    end
    local energy = {current = 100}
    function energy:CanSpend(key) return self.current >= EnergyRules.SKILL_COST[key] end
    function energy:Spend(key)
        if not self:CanSpend(key) then return false end
        self.current = self.current - EnergyRules.SKILL_COST[key]
        return true
    end
    owner.components.lumineenergy = energy
    owner.components.luminejourney = {active_element = "dendro", CanResonate = function() return not owner.locked end}
    local Dendro = require("components/luminedendro")
    local skill = Dendro(owner)
    owner.components.luminedendro = skill
    local world = {owner = owner, skill = skill, spawns = spawns}
    function world.second_caster()
        local other = Entity("lumine")
        other.components.luminejourney = owner.components.luminejourney
        other._lumine_dendro_field_until = NetVar()
        return Dendro(other)
    end
    function world.enemy(x, z)
        local enemy = Entity("spider", x, z)
        enemy.tags.monster = true
        enemies[#enemies + 1] = enemy
        return enemy
    end
    function world.advance(seconds)
        local ending = now + seconds
        while true do
            local next_task
            for _, task in ipairs(tasks) do
                if task.time <= ending and (not next_task or task.time < next_task.time) then next_task = task end
            end
            if not next_task then break end
            now = next_task.time
            next_task.time = next_task.period and now + next_task.period or math.huge
            if next_task.inst:IsValid() then next_task.fn(next_task.inst) end
        end
        now = ending
    end
    function world.hit(target, luck, mod_weapon)
        local random = math.random
        math.random = function() return luck end
        local ok, err = pcall(function()
            owner:PushEvent("onhitother", {target = target, from_doattack = true,
                damageresolved = 5, weapon = {HasTag = function() return mod_weapon ~= false end}})
        end)
        math.random = random
        assert(ok, err)
    end
    return world
end

return function(test)
    test("25% roll, one attempt per tick and 2.5s successful-proc interval", function()
        local w = Setup()
        local target = w.enemy(1, 0)
        w.hit(target, .25)
        w.hit(target, 0)
        assert(#w.spawns == 0)
        w.advance(.25)
        w.hit(target, .249)
        assert(#w.spawns == 1 and w.spawns[1].components.combat.damage == Rules.VINE_DAMAGE)
        assert(w.spawns[1].planar == 0 and w.spawns[1].components.combat.target == target)
        w.advance(2.25)
        w.hit(target, 0)
        assert(#w.spawns == 1)
        w.advance(.25)
        w.hit(target, 0)
        assert(#w.spawns == 2)
    end)

    test("vine rejects vanilla weapons, friendly and invalid targets and clears on death", function()
        local w = Setup()
        local target = w.enemy(1, 0)
        w.hit(target, 0, false)
        target.ally = true
        w.hit(target, 0)
        target.ally, target.tags.structure = nil, true
        w.hit(target, 0)
        target.tags.structure = nil
        w.owner.locked = true
        w.hit(target, 0)
        assert(#w.spawns == 0)
        w.owner.locked = nil
        w.hit(target, 0)
        local vine = assert(w.spawns[1])
        vine.components.combat:DoAttack()
        target.ally = true
        vine.components.combat:DoAttack()
        assert(vine.components.combat.attacks == 1)
        w.owner:PushEvent("death")
        assert(vine.removed)
    end)

    test("native windup and attack timing, facing sector and 8s slow", function()
        local w = Setup()
        local front, edge = w.enemy(2, 0), w.enemy(4, 4)
        local side, back, distant = w.enemy(2, 2.01), w.enemy(-1, 0), w.enemy(6.01, 0)
        assert(w.skill:CastRoot() and w.owner.anim == "lunge_pre")
        w.advance(7 * FRAMES)
        assert(w.owner.anim == "atk_pre" and w.owner.queued_anim == "atk" and not front.speed)
        w.advance(4 * FRAMES)
        assert(front.speed == .65 and edge.speed == .65,
            ("front=%s edge=%s energy=%s spawns=%d"):format(tostring(front.speed), tostring(edge.speed),
                w.owner.components.lumineenergy.current, #w.spawns))
        assert(not side.speed and not back.speed and not distant.speed)
        assert(w.owner.x == 0 and w.owner.components.lumineenergy.current == 85)
        w.advance(1)
        assert(w.owner.rate == 1 and not w.skill:CastRoot())
        w.advance(7)
        assert(not front.speed and not front._lumine_dendro_root)
    end)

    test("mouse aim locks through the windup and visual fan uses the same angle", function()
        local w = Setup()
        local mouse, facing = w.enemy(1, 3), w.enemy(3, 0)
        TheWorld.Map.IsValidTileAtPoint = function() return true end
        TheWorld.Map.IsOceanTileAtPoint = function() return true end
        assert(w.skill:CastRoot(0, 30))
        assert(math.abs(w.owner.facing.x) < 1e-6 and w.owner.facing.z == 1)
        w.owner.angle = 180
        w.advance(.55)
        assert(mouse.speed == .65 and not facing.speed)
        local pulses, left, right = 0, false, false
        for _, fx in ipairs(w.spawns) do
            if not fx.parent then
                pulses = pulses + 1
                assert(fx.z > 0 and math.abs(fx.x) <= fx.z + 1e-6 and fx.x^2 + fx.z^2 <= 36)
                assert(fx.hidden_symbol == "soil01")
                left, right = left or fx.x < -3, right or fx.x > 3
            end
        end
        assert(pulses == 15 and left and right, "expected three expanding rows across the sector")
        w.advance(1)
        w.skill:ResetCooldowns()
        w.owner.angle = 180
        local fallback = w.enemy(-2, 0)
        assert(w.skill:CastRoot(0 / 0, math.huge))
        w.advance(.4)
        assert(fallback.speed == .65)
    end)

    test("large hitboxes touch the arc and edges, and protected targets keep immunity", function()
        local w = Setup()
        local arc, edge = w.enemy(7.8, 0), w.enemy(3, 5.5)
        arc.radius, edge.radius = 2, 2
        local corner, near_miss = w.enemy(3.9, 5.15), w.enemy(8.02, 0)
        corner.radius, near_miss.radius = 1.05, 2
        local treeguard, tree, immune, phased = w.enemy(3, -1), w.enemy(2, 0), w.enemy(4, 0), w.enemy(4, 1)
        treeguard.tags.tree, treeguard.tags.epic = true, true
        tree.tags.tree, tree.tags.monster = true, nil
        immune.invulnerable, phased.protected = true, true
        local stationary = w.enemy(4, -1)
        stationary.components.locomotor = nil
        w.owner.locked_target = true -- e.g. a tall target beyond melee reach
        assert(w.skill:CastRoot())
        w.advance(.4)
        assert(arc.speed == .65 and edge.speed == .65 and corner.speed == .65 and not near_miss.speed)
        assert(treeguard.speed == .65 and not tree.speed and not immune.speed and not phased.speed)
        assert(arc._lumine_dendro_root.scale > 1 and stationary._lumine_dendro_root)
        stationary:PushEvent("attacked", {attacker = w.owner, damageresolved = 10})
        assert(not stationary._lumine_dendro_root and w.spawns[#w.spawns].prefab == "lumine_dendro_sporebomb")
    end)

    test("interrupted windup spends no energy and a landed hit creates one fixed bomb", function()
        local w = Setup()
        local target = w.enemy(3, 0)
        local blast, friendly = w.enemy(3, 2.95), w.enemy(4, 2)
        local large = w.enemy(3, 4.1)
        large.radius = 1.2
        friendly.ally = true
        assert(w.skill:CastRoot())
        w.owner.sg:GoToState("hit")
        w.advance(.75)
        assert(#w.spawns == 0 and w.owner.components.lumineenergy.current == 100)
        assert(w.skill:CastRoot())
        w.advance(.75)
        target:PushEvent("attacked", {attacker = w.owner, damageresolved = 0})
        assert(target.speed == .65, "expected the wave to root the target")
        for _ = 1, 2 do target:PushEvent("attacked", {attacker = w.owner, damageresolved = 10}) end
        local bomb
        for _, spawn in ipairs(w.spawns) do
            if spawn.prefab == "lumine_dendro_sporebomb" then assert(not bomb) bomb = spawn end
        end
        assert(bomb and bomb.x == 3 and bomb.z == 0 and not target.speed)
        target.x = 20
        w.advance(1.99)
        assert(not bomb.popped and not blast.damage)
        w.advance(.02)
        assert(bomb.popped and blast.damage == 60 and large.damage == 60 and not friendly.damage and not target.damage)
        w.advance(.7)
        assert(bomb.removed)
    end)

    test("static 6-radius field lasts 10s and refreshes one target-wide poison", function()
        local w = Setup()
        local edge = w.enemy(6, 0)
        local beyond = w.enemy(6.01, 0)
        local boss = w.enemy(0, 5)
        boss.tags.epic, boss.components.health.maxhealth = true, 20000
        assert(w.skill:CastField() and not w.skill:CastField())
        local cloud = assert(w.skill.field)
        local initial_poison = edge._lumine_dendro_poison
        assert(initial_poison and cloud.x == 0 and not cloud._drowsytask and not cloud.persists)
        assert(w.owner.components.lumineenergy.current == 70)
        assert(w.owner._lumine_dendro_field_ready.value == 60 and w.owner._lumine_dendro_field_until.value == 50)
        w.owner.x = 30
        w.advance(3)
        assert(edge._lumine_dendro_poison == initial_poison and edge.damage == 60)
        assert(boss.damage == 300 and not beyond.damage)
        edge.x = 20
        w.advance(5)
        assert(edge.damage == 160 and not edge._lumine_dendro_poison)
        w.advance(2)
        assert(not w.skill.field and w.owner._lumine_dendro_field_until.value == 0 and boss.damage == 1000)
        w.advance(4)
        assert(boss.damage == 1400 and not boss._lumine_dendro_poison and cloud.removed)
    end)

    test("poison respects blocked damage and cleanup and does not reload", function()
        local w = Setup()
        local target = w.enemy(1, 0)
        target.invulnerable = true
        assert(w.skill:CastField())
        w.advance(1)
        assert(target.damage == 0 and target.hits == 1)
        target.invulnerable = nil
        w.advance(1)
        assert(target.damage == 20)
        local cloud = w.skill.field
        local saved = w.skill:OnSave()
        w.owner:PushEvent("ms_playerdespawnanddelete")
        assert(cloud.removed and not target._lumine_dendro_poison and next(w.skill.effects) == nil)
        w.advance(2)
        w.skill:OnLoad(saved)
        assert(not w.skill:CastField() and not w.skill.field)
        w.advance(17)
        assert(target.damage == 20 and not w.skill:CastField())
        w.advance(1)
        assert(w.skill:CastField())
        w.owner:PushEvent("death")
        assert(not w.skill.field and not target._lumine_dendro_poison)
    end)

    test("two casters share one poison clock and removing the target releases both", function()
        local w = Setup()
        local target = w.enemy(1, 0)
        local second = w.second_caster()
        local field = require("lumine_dendro_field")
        assert(w.skill:CastField())
        local poison = assert(target._lumine_dendro_poison)
        w.advance(.5)
        local cloud = assert(field.Prepare())
        field.Start(second, cloud)
        assert(target._lumine_dendro_poison == poison and poison.caster == second)
        w.advance(2)
        assert(target.damage == 40 and target.hits == 2)
        target:Remove()
        assert(not target._lumine_dendro_poison and not w.skill.effects[poison] and not second.effects[poison])
    end)
end
