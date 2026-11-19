local F = require("fixtures")
local Rules = require("lumine_energy_rules")
local Cast = require("flight/lumine_electro_cast")

local function Setup()
    F.world()
    FRAMES = 1 / 30
    FrameEvent = function(frame, fn) return {frame = frame, fn = fn} end
    State = function(definition) return definition end
    local state
    Cast.Install(function(graph, definition)
        assert(graph == "wilson" and definition.name == Cast.STATE)
        state = definition
    end)

    local owner = F.player()
    local now, tasks, orbs, sparks, enemies = 0, {}, {}, 0, {}
    GetTime = function() return now end
    Vector3 = function(x, y, z) return {x = x, y = y, z = z} end
    TheSim = {FindEntities = function(_, x, _, z, range, _, exclude)
        local found = {}
        for _, enemy in ipairs(enemies) do
            if enemy:GetDistanceSqToPoint(x, 0, z) <= range * range
                and not enemy:HasAnyTag(unpack(exclude)) then
                found[#found + 1] = enemy
            end
        end
        return found
    end}
    local function Schedule(delay, fn, periodic)
        local task = {at = now + delay, fn = fn, period = periodic and delay or nil}
        function task:Cancel() self.at = math.huge end
        tasks[#tasks + 1] = task
        return task
    end
    function owner:DoPeriodicTask(delay, fn) return Schedule(delay, fn, true) end
    function owner:DoTaskInTime(delay, fn) return Schedule(delay, fn) end
    function owner:Advance(seconds)
        local limit = now + seconds
        while true do
            local next_task
            for _, task in ipairs(tasks) do
                if task.at <= limit and (not next_task or task.at < next_task.at) then next_task = task end
            end
            if not next_task then break end
            now = next_task.at
            next_task.at = next_task.period and now + next_task.period or math.huge
            next_task.fn()
        end
        now = limit
    end
    function owner:HasAnyTag(...)
        for i = 1, select("#", ...) do if self:HasTag(select(i, ...)) then return true end end
        return false
    end
    function owner:ClearBufferedAction() end
    function owner:RemoveEventCallback(name) self.handlers[name] = nil end
    owner.sg = {statemem = {}}
    function owner.sg:HasAnyStateTag(...) return self.forced == true end
    function owner.sg:HasStateTag(tag) return tag == "busy" and self.state == Cast.STATE end
    function owner.sg:HasState(name) return name == Cast.STATE end
    function owner.sg:GoToState(name)
        if self.state == Cast.STATE then state.onexit(owner) end
        self.state = name
        self.statemem = {}
        if name == Cast.STATE then
            state.onenter(owner)
            for _, event in ipairs(state.timeline) do
                Schedule(event.frame * FRAMES, function() if self.state == name then event.fn(owner) end end)
            end
        end
        owner:PushEvent("newstate")
    end
    function owner.sg:SetTimeout(timeout)
        Schedule(timeout, function()
            if self.state == Cast.STATE then state.ontimeout(owner) end
        end)
    end
    owner.AnimState = {PlayAnimation = function(_, name) owner.anim = name end,
        PushAnimation = function() end, SetDeltaTimeMultiplier = function(_, rate) owner.rate = rate end}
    owner.SoundEmitter = {PlaySound = function() end}
    local function NetVar(initial)
        return {stored = initial, set = function(self, v) self.stored = v end,
            value = function(self) return self.stored end}
    end
    for _, key in ipairs({"energy", "electro_infused", "electro_burst", "electro_ready"}) do
        owner["_lumine_" .. key] = NetVar(0)
    end
    owner.components.health = {IsDead = function() return owner.dead == true end}
    owner.components.locomotor = {Stop = function() end}
    owner.components.luminejourney = {active_element = "electro", CanResonate = function() return not owner.locked end}
    owner.weapon = {components = {weapon = {damage = 34}}}
    owner.components.combat = {
        IsAlly = function(_, target) return target.ally == true end,
        CanTarget = function(_, target) return target:IsValid() end,
        GetWeapon = function() return owner.weapon end,
        DoAttack = function(_, target, weapon, _, stimuli)
            owner.stimuli = stimuli
            if target then
                for _ = 1, 2 do
                    owner:PushEvent("onhitother", {target = target, weapon = weapon or owner.weapon,
                        stimuli = stimuli, damageresolved = 12, from_doattack = true})
                end
            end
        end,
    }
    IsEntityElectricImmune = function(target) return target.immune end
    SpawnPrefab = function(name)
        if name == "staffcastfx" then return nil end
        if name == "lumine_electro_sparks" or name == "lumine_electro_immune_sparks" then
            return {AlignToTarget = function(_, target, source)
                assert(source:IsValid())
                assert(name == (target.immune and "lumine_electro_immune_sparks" or "lumine_electro_sparks"))
                sparks = sparks + 1
            end}
        end
        local inst = {AnimState = {
            SetMultColour = function(_, r, g, b)
                assert(b > r and r > g, "expected purple impact tint")
            end,
            SetAddColour = function() end,
            SetSymbolMultColour = function(_, symbol, r, g, b)
                assert(symbol == "light_bar" and b > r and r > g)
            end,
        }}
        inst.Transform = {
            SetPosition = function(_, x, y, z) inst.x, inst.y, inst.z = x, y, z end,
            GetWorldPosition = function() return inst.x, inst.y, inst.z end,
        }
        inst.Physics = {Teleport = inst.Transform.SetPosition}
        function inst:IsValid() return not self.removed end
        function inst:Remove() self.removed = true end
        function inst:Hide() self.hidden = true end
        function inst:Show() self.hidden = false end
        function inst:DoTaskInTime(delay, fn, ...)
            local args = {...}
            return Schedule(delay, function() if self:IsValid() then fn(self, unpack(args)) end end)
        end
        if name == "brilliance_projectile_blast_fx" then return inst end
        assert(name == "brilliance_projectile_fx")
        orbs[#orbs + 1] = inst
        inst.components = {projectile = {
            SetOnThrownFn = function() end,
            SetOnHitFn = function(_, fn) inst.onhit = fn end,
            SetSpeed = function(_, speed) inst.speed = speed end,
            SetBounced = function(_, bounced) inst.bounced = bounced end,
            Throw = function(_, projectile_owner, target, caster)
                assert(projectile_owner == inst and caster == owner)
                inst.target = target
            end,
        }}
        return inst
    end
    local energy = require("components/lumineenergy")(owner)
    owner.components.lumineenergy = energy
    local electro = require("components/lumineelectro")(owner)
    owner.components.lumineelectro = electro
    return owner, energy, electro, orbs, function() return sparks end, enemies
end

local function Enemy(x, tags)
    local target = {x = x or 0, entity = {IsVisible = function() return true end},
        components = {combat = {}, health = {IsDead = function() return false end}}}
    tags = tags or {monster = true}
    function target:IsValid() return not self.removed end
    function target:HasAnyTag(...)
        for i = 1, select("#", ...) do
            if tags[select(i, ...)] then return true end
        end
        return false
    end
    function target:GetDistanceSqToPoint(px, _, pz) return (self.x - px)^2 + pz^2 end
    function target.components.combat:GetAttacked(_, damage, _, stimuli)
        assert(damage == Rules.ELECTRO.ORB_DAMAGE and stimuli == "electric")
        target.hits = (target.hits or 0) + 1
    end
    return target
end

local function Impact(orb)
    local target = orb.target
    orb.Transform:SetPosition(target.x, .6, 0)
    orb.onhit(orb, nil, target)
end

return function(test)
    test("battle regeneration boosts base regeneration once and expires", function()
        local owner, energy, electro = Setup()
        owner.components.lumineartifacts = {HasActivePiece = function() return true end}
        owner:Advance(1)
        assert(math.abs(energy.current - 11 / 60) < .0001)
        owner:PushEvent("attacked", {damageresolved = 10, attacker = Enemy()})
        for _ = 1, 2 do electro:MarkCombat() end
        assert(electro:GetRegenMultiplier() == 1.5)
        owner:Advance(1)
        assert(math.abs(energy.current - (11 + 16) / 60) < .0001)
        owner:Advance(6)
        assert(electro:GetRegenMultiplier() == 1)
    end)

    test("full energy including combat and relic recovery lasts less than twenty seconds", function()
        local owner, energy, electro = Setup()
        owner.components.lumineartifacts = {HasActivePiece = function() return true end}
        assert(not electro:ToggleInfusion())
        energy:Refill()
        assert(electro:ToggleInfusion() and owner._lumine_electro_infused:value())
        for _ = 1, 19 do electro:MarkCombat() owner:Advance(1) end
        owner:Advance(.75)
        assert(not electro.infused and not owner._lumine_electro_infused:value())
    end)

    test("replenishment cannot exceed absolute infusion deadline", function()
        local owner, energy, electro = Setup()
        energy:Refill()
        assert(electro:ToggleInfusion())
        for _ = 1, 20 do energy:Refill() owner:Advance(1) end
        assert(not electro.infused and not electro.drain_task and energy.current > 90)
    end)

    test("cast takes effect after the staff action, then only burst expires", function()
        local owner, energy, electro = Setup()
        assert(not electro:CastBurst())
        energy:Refill()
        assert(electro:ToggleInfusion() and electro:CastBurst())
        assert(owner.anim == "staff_pre" and owner.rate == 2.5 and electro.burst_until == 0)
        owner:Advance(.75)
        assert(electro.burst_until > 5 and electro.burst_ready > 12)
        assert(owner._lumine_electro_burst:value() == electro.burst_until)
        owner:Advance(5)
        assert(electro.infused and electro.burst_until == 0 and owner.rate == 1)
        assert(not electro:CastBurst())
    end)

    test("one orb per confirmed weapon attack or bouncing projectile and exactly two energy", function()
        local owner, energy, electro, orbs, sparks = Setup()
        energy:Refill()
        assert(electro:ToggleInfusion() and electro:CastBurst())
        owner:Advance(1)
        local before, target = energy.current, Enemy()
        owner.components.combat:DoAttack(nil)
        assert(#orbs == 0 and energy.current == before)
        owner.components.combat:DoAttack(target)
        assert(#orbs == 1 and energy.current == before - 2 and owner.stimuli == "electric" and sparks() > 0)
        Impact(orbs[1])
        owner:Advance(.11)
        assert(target.hits == 1 and orbs[1].removed and #orbs == 1)
        local projectile = {IsValid = function() return true end}
        target.immune = true
        owner.components.combat:DoAttack(target, owner.weapon, projectile)
        owner.components.combat:DoAttack(target, owner.weapon, projectile)
        assert(#orbs == 2 and energy.current == before - 4)
        owner.weapon = nil
        owner.components.combat:DoAttack(target)
        assert(#orbs == 2 and energy.current == before - 4 and owner.stimuli == nil)
    end)

    test("one paid orb bounces between enemies and stops after five hits", function()
        local owner, energy, electro, orbs, _, enemies = Setup()
        local first, second, third = Enemy(1), Enemy(4), Enemy(9)
        local ally, neutral, distant = Enemy(2), Enemy(3, {}), Enemy(30)
        ally.ally = true
        for _, enemy in ipairs({first, second, third, ally, neutral, distant}) do
            enemies[#enemies + 1] = enemy
        end
        energy:Refill()
        assert(electro:ToggleInfusion() and electro:CastBurst())
        owner:Advance(1)
        local before = energy.current
        owner.components.combat:DoAttack(first)
        assert(#orbs == 1 and energy.current == before - Rules.ELECTRO.ORB_COST)
        assert(electro:ToggleInfusion())
        local orb = orbs[1]
        for _, expected in ipairs({first, second, third, first, second}) do
            assert(orb:IsValid() and orb.target == expected)
            Impact(orb)
            Impact(orb)
            owner:Advance(.11)
        end
        assert(orb.bounced and orb.speed == 10 and not orb:IsValid())
        assert(first.hits == 2 and second.hits == 2 and third.hits == 1)
        assert(not ally.hits and not neutral.hits and not distant.hits)
        assert(#orbs == 1 and energy.current == before - Rules.ELECTRO.ORB_COST)
    end)

    test("lock, interruption, manual stop, depletion and reload clear battle effects", function()
        local owner, energy, electro = Setup()
        energy:Refill()
        owner.locked = true
        assert(not electro:ToggleInfusion())
        owner.locked = false
        assert(electro:ToggleInfusion() and electro:CastBurst())
        owner.sg:GoToState("hit")
        owner:Advance(1)
        assert(electro.burst_until == 0 and electro.burst_ready == 0 and electro.infused)
        assert(electro:CastBurst())
        owner:Advance(1)
        assert(electro:ToggleInfusion() and electro.burst_until == 0 and not electro.infused)
        local saved = electro:OnSave()
        assert(saved.burst_remaining > 0 and saved.infused == nil)
        electro:ResetCooldowns()
        electro:OnLoad(saved)
        assert(not electro.infused and electro.burst_ready > GetTime())
        assert(electro:ToggleInfusion())
        energy:Add(-100)
        assert(not electro.infused)
        energy:Refill()
        assert(electro:ToggleInfusion())
        owner.sg.forced = true
        owner:PushEvent("newstate")
        assert(not electro.infused)
    end)
end
