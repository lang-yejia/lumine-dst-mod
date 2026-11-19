local F = require("fixtures")
local Rules = require("cryo/rules")
local Cast = require("flight/lumine_cryo_cast")

local function Near(a, b)
    assert(math.abs(a - b) < .0001, tostring(a) .. " expected " .. tostring(b))
end

local function Setup()
    F.world()
    FRAMES, PI, TWOPI, DEGREES, MAX_PHYSICS_RADIUS = 1/30, math.pi, math.pi*2, math.pi/180, 4
    EQUIPSLOTS = {HANDS = "hands"}
    Vector3 = function(x, y, z) return {x = x, y = y, z = z} end
    math.clamp = function(n, a, b) return math.min(b, math.max(a, n)) end
    local w = {time = 30, entities = {}, tasks = {}}
    GetTime = function() return w.time end
    TheWorld.Map = {
        IsValidTileAtPoint = function(_, x) return x < 50 end,
        IsGroundTargetBlocked = function() return w.blocked end,
    }
    TheSim = {FindEntities = function(_, x, _, z, radius)
        local result = {}
        for _, e in ipairs(w.entities) do
            if e.components.combat and e:IsValid() and e:GetDistanceSqToPoint(x, 0, z) <= radius ^ 2 then
                result[#result + 1] = e
            end
        end
        return result
    end}

    local function Entity(prefab, x, z)
        local e = {prefab = prefab, x = x or 0, y = 0, z = z or 0, components = {}, events = {}, tags = {}}
        e.entity = {IsVisible = function() return not e.removed end, SetParent = function() end}
        e.Transform = {
            GetWorldPosition = function() return e.x, e.y, e.z end,
            SetPosition = function(_, a, b, c) e.x, e.y, e.z = a, b, c end,
            GetRotation = function() return e.rotation or 0 end,
            SetRotation = function(_, n) e.rotation = n end,
            SetScale = function() end,
        }
        e.AnimState = {
            PlayAnimation = function(_, name) e.animation = name end,
            PushAnimation = function() end, SetFrame = function() end, SetAddColour = function() end,
            SetMultColour = function() end, SetDeltaTimeMultiplier = function() end,
        }
        e.SoundEmitter = {PlaySound = function() end}
        e.Light = {SetColour = function() end}
        e.Follower = {FollowSymbol = function(_, guid) e.following = guid end}
        e.GUID = #w.entities + 1
        function e:IsValid() return not self.removed end
        function e:AddTag(tag) self.tags[tag] = true end
        function e:RemoveTag(tag) self.tags[tag] = nil end
        function e:HasTag(tag) return self.tags[tag] end
        function e:HasAnyTag(...)
            for i = 1, select("#", ...) do if self:HasTag(select(i, ...)) then return true end end
            return false
        end
        function e:GetPhysicsRadius(default) return self.radius or default end
        function e:GetDistanceSqToPoint(a, _, c) return (self.x-a)^2 + (self.z-c)^2 end
        function e:GetDistanceSqToInst(other) return self:GetDistanceSqToPoint(other.x, 0, other.z) end
        function e:AddChild(child)
            child.parent = self
            self.children = self.children or {}
            self.children[child] = true
        end
        function e:ListenForEvent(name, fn, source)
            local owner = source or self
            owner.events[name] = owner.events[name] or {}
            owner.events[name][fn] = true
        end
        function e:RemoveEventCallback(name, fn, source)
            local owner = source or self
            if owner.events[name] then owner.events[name][fn] = nil end
        end
        function e:PushEvent(name, data)
            local copied = {}
            for fn in pairs(self.events[name] or {}) do copied[#copied + 1] = fn end
            for _, fn in ipairs(copied) do fn(self, data) end
        end
        function e:Remove()
            if self.removed then return end
            self:PushEvent("onremove")
            self.removed = true
            for child in pairs(self.children or {}) do child:Remove() end
        end
        function e:StopBrain() self.brain_stopped = true end
        function e:RestartBrain() self.brain_stopped = nil end
        local function Task(delay, fn, period, ...)
            local task = {owner = e, time = w.time + delay, fn = fn, period = period, args = {...}}
            function task:Cancel() self.time = math.huge end
            w.tasks[#w.tasks + 1] = task
            return task
        end
        function e:DoTaskInTime(delay, fn, ...) return Task(delay, fn, nil, ...) end
        function e:DoPeriodicTask(period, fn, initial, ...) return Task(initial or period, fn, period, ...) end
        function e:RestartFX() self.restarted = true end
        function e:SetUp() end
        function e:ClearBufferedAction() end
        function e:ForceFacePoint(a, _, c) self.rotation = math.atan2(self.z-c, a-self.x) / DEGREES end
        w.entities[#w.entities+1] = e
        return e
    end

    function w.Advance(seconds)
        local limit = w.time + seconds
        while true do
            local chosen
            for _, task in ipairs(w.tasks) do
                if task.owner:IsValid() and task.time <= limit and (not chosen or task.time < chosen.time) then chosen = task end
            end
            if not chosen then break end
            w.time = chosen.time
            chosen.time = chosen.period and w.time+chosen.period or math.huge
            chosen.fn(chosen.owner, unpack(chosen.args))
        end
        w.time = limit
    end

    function w.Actor(prefab, x, z)
        local e = Entity(prefab, x, z)
        e.tags[prefab == "lumine" and "player" or "monster"] = true
        local health = {currenthealth = 1000, maxhealth = 1000}
        function health:IsDead() return self.currenthealth <= 0 end
        function health:IsInvincible() return e.invincible end
        function health:DoDelta(n)
            if self:IsInvincible() then return 0 end
            self.currenthealth = math.max(0, self.currenthealth + n)
            if self:IsDead() then e:PushEvent("death") end
            return n
        end
        e.components.health = health
        e.components.locomotor = {Stop = function() end}
        local combat = {hits = 0}
        function combat:IsAlly(target) return target.ally end
        function combat:CanBeAttacked() return not e.invincible and not health:IsDead() end
        function combat:SetTarget(target) self.target = target end
        function combat:BlankOutAttacks() end
        function combat:CalcDamage(target, weapon)
            return weapon and weapon.damage or 10, weapon and weapon.planar and {planar = weapon.planar} or nil
        end
        function combat:GetWeapon() return e.weapon end
        function combat:GetAttacked_Internal(attacker, damage, weapon, stimuli, special, from_doattack)
            if health:IsDead() or health:IsInvincible() then return false end
            self.hits = self.hits + 1
            local total = damage or 0
            for _, n in pairs(special or {}) do total = total + n end
            health:DoDelta(-total)
            local data = {attacker = attacker, target = e, damage = total, damageresolved = total,
                weapon = weapon, stimuli = stimuli, from_doattack = from_doattack}
            e:PushEvent("attacked", data)
            attacker:PushEvent("onhitother", data)
            return true
        end
        function combat:GetAttacked(...) return self:GetAttacked_Internal(...) end
        function combat:DoAttack(target, weapon, projectile)
            weapon = weapon or e.weapon
            if not target or e.whiff then return end
            for _, victim in ipairs(e.splash or {target}) do
                local damage, special = self:CalcDamage(victim, weapon)
                victim.components.combat:GetAttacked_Internal(e, damage, weapon, nil, special, true)
                if e.double_callback then
                    e:PushEvent("onhitother", {target = victim, damage = damage, damageresolved = damage,
                        weapon = weapon, from_doattack = true})
                end
            end
        end
        function combat:DoAreaAttack(target, weapon) return self:DoAttack(target, weapon) end
        e.components.combat = combat
        e.components.inventory = {GetEquippedItem = function() return e.weapon end}
        e.components.freezable = require("native_freezable")(e)
        return e
    end
    SpawnPrefab = function(name) return Entity(name) end
    function w.Count(name)
        local count = 0
        for _, e in ipairs(w.entities) do if e.prefab == name then count = count+1 end end
        return count
    end
    function w.Weapon(name, damage, planar)
        local weapon = Entity(name)
        weapon.damage, weapon.planar = damage or 10, planar
        weapon.components.weapon = {}
        return weapon
    end
    local owner = w.Actor("lumine", 0, 0)
    w.owner = owner
    local function Net(value) return {set = function(self,n) value=n end, value = function() return value end} end
    for _, key in ipairs({"shield", "shield_ready", "charges", "infusion_ready", "meteor_ready", "field_until"}) do
        owner["_lumine_cryo_"..key] = Net(0)
    end
    owner.components.luminejourney = {active_element = "cryo", CanResonate = function() return not w.locked end}
    owner.components.lumineenergy = {
        current = 100,
        CanSpendAmount = function(self, n) return self.current >= n end,
        SpendAmount = function(self, n) if self.current < n then return false end self.current=self.current-n return true end,
    }
    local states = {idle = {name = "idle", tags = {}}}
    State = function(def) return def end
    FrameEvent = function(frame, fn) return {time = frame * FRAMES, fn = fn} end
    Cast.Install(function(_, state) states[state.name] = state end)
    owner.sg = {currentstate = states.idle, statemem = {}}
    function owner.sg:HasStateTag(tag)
        for _, value in ipairs(self.currentstate.tags) do if value == tag then return true end end
        return false
    end
    function owner.sg:HasAnyStateTag(...)
        for i = 1, select("#",...) do if self:HasStateTag(select(i,...)) then return true end end
        return false
    end
    function owner.sg:SetTimeout(seconds)
        local id = self.id
        owner:DoTaskInTime(seconds, function() if self.id==id then self.currentstate.ontimeout(owner) end end)
    end
    function owner.sg:GoToState(name, point)
        if self.currentstate.onexit then self.currentstate.onexit(owner) end
        self.id = (self.id or 0)+1
        self.currentstate, self.statemem = states[name], {}
        if self.currentstate.onenter then self.currentstate.onenter(owner, point) end
        local id = self.id
        for _, event in ipairs(self.currentstate.timeline or {}) do
            owner:DoTaskInTime(event.time, function() if self.id==id then event.fn(owner) end end)
        end
    end
    local cryo = require("components/luminecryo")(owner)
    owner.components.luminecryo = cryo
    w.Advance(0)
    return w, cryo
end

return function(test)
    test("shield blocks a lethal regular and planar hit before health changes, then recharges", function()
        local w, cryo = Setup()
        local enemy = w.Actor("spider", 2, 0)
        assert(cryo.shield)
        w.owner.components.health:DoDelta(-5, true, "hunger")
        assert(cryo.shield)
        local hp = w.owner.components.health.currenthealth
        assert(not w.owner.components.combat:GetAttacked(enemy, 9999, nil, nil, {planar = 500}, true))
        assert(w.owner.components.health.currenthealth==hp and not cryo.shield)
        assert(enemy.components.freezable:IsFrozen())
        w.Advance(2.01)
        assert(not enemy.components.freezable:IsFrozen())
        w.owner.components.health:DoDelta(-10, true, "hunger")
        w.owner.components.combat:GetAttacked(enemy, 10)
        assert(w.owner.components.health.currenthealth==hp-20)
        w.Advance(18)
        assert(cryo.shield)
        w.owner.invincible = true
        w.owner.components.combat:GetAttacked(enemy, 50)
        assert(cryo.shield)
    end)

    test("native freeze shatters once for both regular and planar damage, including direct skills", function()
        local w, cryo = Setup()
        local enemy = w.Actor("spider", 3, 0)
        enemy.components.freezable:AddColdness(2, 3)
        local weapon = w.Weapon("spear", 10, 7)
        local damage, special = w.owner.components.combat:CalcDamage(enemy, weapon)
        assert(damage==20 and special.planar==14 and enemy.components.freezable:IsFrozen())
        w.owner.double_callback = true
        w.owner.components.combat:DoAttack(enemy, weapon)
        Near(enemy.components.health.currenthealth, 966)
        assert(not enemy.components.freezable:IsFrozen())
        w.owner.components.combat:DoAttack(enemy, weapon)
        Near(enemy.components.health.currenthealth, 949)
        enemy.components.freezable:AddColdness(2, 3)
        require("lumine_direct_damage")(w.owner, enemy, 30, nil, "lumine_cryo")
        Near(enemy.components.health.currenthealth, 889)
        assert(not enemy.components.freezable:IsFrozen())
    end)

    test("infusion requires an actual registered sword, charges only valid hits, and binds to the weapon", function()
        local w, cryo = Setup()
        local weapon = w.Weapon("spear")
        weapon.tags.lumine_sword = true
        w.owner.weapon = weapon
        assert(not cryo:Cast("infusion"))
        weapon = w.Weapon("lumine_dull_blade")
        w.owner.weapon = weapon
        assert(cryo:Cast("infusion"))
        w.Advance(.8)
        assert(cryo.charges==4 and cryo.weapon==weapon)
        local enemy = w.Actor("spider", 3, 0)
        w.owner.whiff = true
        w.owner.components.combat:DoAttack(enemy)
        assert(cryo.charges==4)
        w.owner.whiff = nil
        w.owner.double_callback = true
        w.owner.components.combat:DoAttack(enemy)
        assert(cryo.charges==3 and w.Count("deerclops_icespike_fx")==3)
        w.owner:PushEvent("unequip", {item=weapon})
        assert(cryo.charges==0 and not cryo.weapon_fx)
        w.owner.weapon = w.Weapon("lumine_aquila_favonia")
        w.owner.components.combat:DoAttack(enemy)
        assert(w.Count("deerclops_icespike_fx")==3)
    end)

    test("an attack hitting several enemies spends one charge and creates one pillar group", function()
        local w, cryo = Setup()
        w.owner.weapon = w.Weapon("lumine_dull_blade")
        assert(cryo:Cast("infusion"))
        w.Advance(.8)
        local first, second = w.Actor("spider",3,0), w.Actor("spider",4,0)
        w.owner.splash, w.owner.double_callback = {first,second}, true
        w.owner.components.combat:DoAttack(first)
        assert(cryo.charges==3 and w.Count("deerclops_icespike_fx")==3)
        Near(first.components.health.currenthealth,960)
        Near(second.components.health.currenthealth,960)
        assert(first.components.freezable:IsFrozen() and second.components.freezable:IsFrozen())
    end)

    test("four infused hits shatter first then refreeze, and leave no charges or weapon FX", function()
        local w, cryo = Setup()
        w.owner.weapon = w.Weapon("lumine_dull_blade")
        assert(cryo:Cast("infusion"))
        w.Advance(.8)
        local enemy = w.Actor("spider",3,0)
        for _=1,4 do w.owner.components.combat:DoAttack(enemy) end
        assert(cryo.charges==0 and not cryo.weapon and not cryo.weapon_fx)
        Near(enemy.components.health.currenthealth,810)
        assert(w.Count("deerclops_icespike_fx")==12)
        w.Advance(1.51)
        assert(not enemy.components.freezable:IsFrozen())
    end)

    test("meteor clamps the mouse range, pays at release, and creates a fixed eight second field", function()
        local w, cryo = Setup()
        local enemy = w.Actor("spider",12,0)
        local ally = w.Actor("spider",12,1)
        ally.ally = true
        assert(cryo:Cast("meteor",100,0))
        Near(w.owner.sg.statemem.cast.x,12)
        assert(w.owner.components.lumineenergy.current==100)
        w.Advance(.59)
        assert(w.owner.components.lumineenergy.current==100)
        w.Advance(.02)
        assert(w.owner.components.lumineenergy.current==60)
        w.Advance(.8)
        Near(enemy.components.health.currenthealth,900)
        Near(ally.components.health.currenthealth,1000)
        assert(enemy.components.freezable:IsFrozen() and cryo.field)
        w.Advance(3.01)
        assert(not enemy.components.freezable:IsFrozen())
        w.Advance(5)
        assert(not cryo.field and w.owner._lumine_cryo_field_until:value()==0)
    end)

    test("native boss resistance remains intact, immune bosses still take impact damage", function()
        local w, cryo = Setup()
        local boss = w.Actor("boss",3,0)
        boss.components.freezable:SetResistance(10)
        boss.components.freezable.diminishingreturns = true
        local immune = w.Actor("boss",3,1)
        immune.components.freezable:OnRemoveFromEntity()
        immune.components.freezable = nil
        require("cryo/attacks").Area(cryo,3,0,4.5,100,3)
        assert(not boss.components.freezable:IsFrozen() and boss.components.freezable.resistance==10)
        Near(boss.components.health.currenthealth,900)
        Near(immune.components.health.currenthealth,900)
        assert(boss.components.freezable.coldness==2)
    end)

    test("field takes precedence over charges and uses an independent target trigger interval", function()
        local w, cryo = Setup()
        w.owner.weapon = w.Weapon("lumine_dull_blade")
        assert(cryo:Cast("infusion"))
        w.Advance(.8)
        assert(cryo:Cast("meteor",0,0))
        w.Advance(1.2)
        assert(cryo:InField())
        local first,second = w.Actor("spider",3,0),w.Actor("spider",-3,0)
        w.owner.components.combat:DoAttack(first)
        w.owner.components.combat:DoAttack(first)
        assert(w.Count("deerclops_icespike_fx")==3 and cryo.charges==4)
        w.owner.components.combat:DoAttack(second)
        assert(w.Count("deerclops_icespike_fx")==6 and cryo.charges==4)
        w.Advance(.76)
        w.owner.components.combat:DoAttack(first)
        assert(w.Count("deerclops_icespike_fx")==9 and cryo.charges==4)
        w.owner.x=6
        w.owner.components.combat:DoAttack(first)
        assert(cryo.charges==3)
    end)

    test("interrupted casts, death, save reload and element changes preserve cooldowns and clean effects", function()
        local w, cryo = Setup()
        assert(cryo:Cast("meteor",8,0))
        w.owner.sg:GoToState("idle")
        w.Advance(.8)
        assert(w.owner.components.lumineenergy.current==100 and not cryo.field)
        assert(cryo:Cast("meteor",8,0))
        w.Advance(1.4)
        assert(cryo.field)
        local enemy = w.Actor("spider",8,0)
        require("cryo/freeze")(cryo, enemy, 3)
        assert(enemy.components.freezable:IsFrozen())
        cryo:BreakShield()
        local saved = cryo:OnSave()
        cryo:OnLoad(saved)
        assert(not cryo.field and not cryo.weapon and not next(cryo.effects))
        assert(cryo.shield_ready>w.time and cryo.meteor_ready>w.time)
        w.owner.components.luminejourney.active_element="wind"
        w.owner:PushEvent("lumine_element_resonated")
        w.owner:PushEvent("death")
        assert(not cryo.shield and not next(cryo.effects))
    end)

    test("two players own independent shields and field buffs", function()
        local w, first = Setup()
        local second_owner = w.Actor("lumine",0,1)
        for _, key in ipairs({"shield","shield_ready","charges","infusion_ready","meteor_ready","field_until"}) do
            local value = 0
            second_owner["_lumine_cryo_"..key] = {
                set = function(_, n) value=n end, value = function() return value end,
            }
        end
        second_owner.components.luminejourney = {active_element="cryo",CanResonate=function()return true end}
        local second = require("components/luminecryo")(second_owner)
        second_owner.components.luminecryo = second
        second:Refresh()
        assert(first.shield and second.shield)
        local enemy = w.Actor("spider",3,0)
        w.owner.components.combat:GetAttacked(enemy,5000)
        assert(not first.shield and second.shield and second_owner.components.health.currenthealth==1000)
        first.field = SpawnPrefab("lumine_cryo_field")
        first.field_until=w.time+8
        assert(first:InField() and not second:InField())
        first:Clear()
        assert(second.shield)
    end)

    test("a repeated callback for one projectile cannot consume another infusion charge", function()
        local w, cryo = Setup()
        w.owner.weapon = w.Weapon("lumine_dull_blade")
        assert(cryo:Cast("infusion"))
        w.Advance(.8)
        local enemy = w.Actor("spider",3,0)
        local projectile = SpawnPrefab("test_projectile")
        w.owner.components.combat:DoAttack(enemy,nil,projectile)
        w.owner.components.combat:DoAttack(enemy,nil,projectile)
        assert(cryo.charges==3 and w.Count("deerclops_icespike_fx")==3)
    end)
end
