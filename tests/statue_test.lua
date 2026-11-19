local F = require("fixtures")
local Elements = require("lumine_statue_elements")

local function Setup()
    F.world()
    local index = require("components/luminestatueindex")({})
    TheWorld.components = {luminestatueindex = index}
    return index
end

local function Player(index, userid)
    local health = {maxhealth = 150, currenthealth = 60, penalty = .2}
    function health:GetMaxWithPenalty() return self.maxhealth * (1 - self.penalty) end
    function health:IsDead() return self.currenthealth == 0 end
    function health:SetVal(v) self.currenthealth = v end
    function health:ForceUpdateHUD() end
    function health:OnSave() return {maxhealth = self.maxhealth} end
    local sanity = {max = 200, current = 100}
    function sanity:GetMaxWithPenalty() return self.max end
    function sanity:SetCurrent(v) self.current = v end
    local hunger = {max = 150, current = 75}
    function hunger:GetPercent() return self.current / self.max end
    function hunger:SetPercent(p) self.current = self.max * p end
    local player = {userid = userid, components = {health = health, sanity = sanity, hunger = hunger}}
    function player:IsValid() return true end
    function player:HasTag() return self.ghost end
    function player:ListenForEvent() end
    function player:DoTaskInTime() end
    player.components.luminestatuebonus = require("components/luminestatuebonus")(player)
    index:Track(player)
    return player, health, sanity, hunger
end

local function StatueFactory()
    Asset, MakeObstaclePhysics, MakePlacer = function() end, function() end, function() end
    ACTIONS = {HAMMER = {}}
    function Prefab(_, fn) return fn end
    function net_tinybyte()
        return {val = 0, value = function(self) return self.val end, set = function(self, v) self.val = v end}
    end
    function CreateEntity()
        local inst = {events = {}, components = {}, entity = {}, AnimState = {}}
        for _, name in ipairs({"AddTransform", "AddAnimState", "AddNetwork", "SetPristine"}) do inst.entity[name] = function() end end
        for _, name in ipairs({"SetBank", "SetBuild", "PushAnimation"}) do inst.AnimState[name] = function() end end
        function inst.AnimState:PlayAnimation(anim) self.anim = anim end
        function inst.AnimState:IsCurrentAnimation(anim) return self.anim == anim end
        function inst.AnimState:SetMultColour(...) self.tint = {...} end
        function inst:ListenForEvent(name, cb) self.events[name] = cb end
        function inst:SetDeploySmartRadius() end
        function inst:AddTag() end
        function inst:AddComponent(name)
            local component = {}
            for _, method in ipairs({"SetDist", "SetOnPlayerNear", "SetOnPlayerFar",
                "SetWorkAction", "SetWorkLeft", "DropLoot"}) do component[method] = function() end end
            function component:SetOnFinishCallback(cb) self.finish = cb end
            self.components[name] = component
        end
        function inst:Remove() self.events.onremove(self) end
        return inst
    end
    return require("prefabs/lumine_seven_statue")
end

return function(test)
    test("conversion is single-use and reserved for the builder", function()
        local index = Setup()
        local a = Player(index, "A")
        local b = Player(index, "B")
        local statue = StatueFactory()()
        assert(statue._statue_element:value() == 0)
        statue.events.onbuilt(statue, {builder = a})
        assert(not statue:Offer("wind", b))
        assert(not statue:Offer("invalid", a))
        assert(statue:Offer("wind", a) and statue:HasOffered("wind"))
        assert(not statue:Offer("wind", a) and not statue:Offer("geo", a))
        assert(statue.fixed_element == "wind" and statue.statue_owner == "A")
        assert(index:Mask("A") == 1 and index:Mask("B") == 0)
    end)

    test("seven bonuses, duplicate destruction, final destruction and rebuilding", function()
        local index = Setup()
        local a, health, sanity, hunger = Player(index, "A")
        local factory, statues = StatueFactory(), {}
        for i, id in ipairs(Elements.order) do
            statues[i] = factory()
            assert(statues[i]:Offer(id, a))
            assert(health.maxhealth == 150 + i * 20)
        end
        assert(health.maxhealth == 290 and sanity.max == 270 and hunger.max == 220)
        assert(health:OnSave().maxhealth == 150)
        assert(health.currenthealth == health:GetMaxWithPenalty() / 2 and sanity.current == 135 and hunger.current == 110)
        local duplicate = factory()
        assert(duplicate:Offer("wind", a) and health.maxhealth == 290)
        duplicate:Remove()
        assert(health.maxhealth == 290)
        statues[1].components.workable.finish(statues[1])
        assert(health.maxhealth == 270)
        local rebuilt = factory()
        assert(rebuilt:Offer("wind", a) and health.maxhealth == 290)
    end)

    test("save ratios survive native stat clamping and remote contributions are reapplied once", function()
        local index = Setup()
        local old, health = Player(index, "A")
        index:Receive("caves", "A", 127)
        health.currenthealth = 174
        local ratio = old.components.luminestatuebonus:OnSave().ratios.health
        local worldsave = index:OnSave()
        index = Setup()
        index:OnLoad(worldsave)
        local new, restored = Player(index, "A")
        new.components.luminestatuebonus:OnLoad({ratios = {health = ratio, sanity = .5, hunger = .5}})
        index:Refresh("A")
        index:Refresh("A")
        assert(restored.maxhealth == 290 and math.abs(restored.currenthealth - 174) < .001)
    end)

    test("legacy migration keeps known elements and never invents an owner", function()
        local index = Setup()
        local factory = StatueFactory()
        local legacy = factory()
        legacy:OnLoad({last_element = "geo", offered = {wind = true, geo = true}, owner = "A"})
        assert(legacy.fixed_element == "geo" and legacy.statue_owner == nil)
        assert(legacy._statue_element:value() == 2 and index:Mask("A") == 0)
        assert(Elements.LegacyElement({offered = {wind = true, geo = true}}) == nil)
        assert(Elements.LegacyElement({offered = {wind = true}}) == "wind")
        local a = Player(index, "A")
        local statue = factory()
        assert(statue:Offer("cryo", a))
        local saved = {workable = {workleft = 4}}
        assert(statue:OnSave(saved) == nil, "prefab OnSave must not return entity references")
        assert(saved.element == "cryo" and saved.owner == "A" and saved.fixed_version == 1)
        assert(saved.workable.workleft == 4)
        index = Setup()
        local restored = factory()
        restored:OnLoad(saved)
        local b, health = Player(index, "A")
        index:Refresh(b.userid)
        index:Change(restored, true)
        assert(restored.fixed_element == "cryo" and health.maxhealth == 170)
        assert(restored.AnimState.tint[4] == 1)
    end)

    test("unattuned statue preserves builder ownership without contributing a bonus", function()
        local index = Setup()
        local factory = StatueFactory()
        local original = factory()
        original.events.onbuilt(original, {builder = {userid = "A"}})
        local data = {}
        assert(original:OnSave(data) == nil)
        local restored = factory()
        restored:OnLoad(data)
        assert(restored._statue_element:value() == 0 and restored.statue_owner == "A")
        assert(index:Mask("A") == 0 and not restored:Offer("geo", {userid = "B"}))
        assert(restored:Offer("geo", {userid = "A"}) and index:Mask("A") == 2)
    end)

    test("remote masks deduplicate, clear, preserve external bonuses and never revive ghosts", function()
        local index = Setup()
        local player, health, sanity, hunger = Player(index, "A")
        local statue = StatueFactory()()
        assert(statue:Offer("wind", player))
        health.maxhealth = health.maxhealth + 35
        index:Receive("caves", "A", 3)
        assert(health.maxhealth == 225 and sanity.max == 220 and hunger.max == 170)
        index:Receive("caves", "B", 127)
        assert(health.maxhealth == 225)
        health.currenthealth, player.ghost = 0, true
        index:Receive("caves", "A", 0)
        assert(health.maxhealth == 205 and health.currenthealth == 0)
        statue:Remove()
        assert(health.maxhealth == 185 and sanity.max == 200 and hunger.max == 150)
    end)

    test("wire IDs, unique colours and prefab item mapping", function()
        local colors = {}
        local factory = StatueFactory()
        local index = Setup()
        local a = Player(index, "A")
        for i, id in ipairs(Elements.order) do
            local element = Elements[id]
            local statue = factory()
            assert(element.wire == i and Elements.by_item[element.item] == id)
            assert(statue:Offer(id, a) and statue._statue_element:value() == i)
            local color = table.concat(statue.AnimState.tint, ":")
            assert(not colors[color] and statue.AnimState.tint[4] == 1)
            colors[color] = true
        end
        assert(Elements.Count(index:Mask("A")) == 7)
    end)

    test("shards publish changes and answer zero after a missed removal", function()
        local index = Setup()
        local hooks, handlers, worlds, sent = {}, {}, {}, {}
        local world = {ismastersim = true, components = {}}
        function world:AddComponent(name) self.components[name] = index return index end
        function world:DoPeriodicTask(_, callback) self.recheck = callback end
        local G = {TheWorld = world, ShardList = {caves = true}}
        hooks.add = function(_, name, fn) handlers[name] = fn end
        hooks.get = function(_, name) return name end
        hooks.world = function(name, fn) worlds[name] = fn end
        hooks.send = function(...) sent[#sent + 1] = {...} end
        require("lumine_statue_network").Install(G, hooks)
        worlds.forest(world)
        local player, health = Player(index, "A")
        assert(sent[#sent][1] == "query")
        local statue = StatueFactory()()
        assert(statue:Offer("wind", player))
        assert(sent[#sent][1] == "mask" and sent[#sent][4] == 1)
        handlers.mask("caves", "A", 3)
        assert(health.maxhealth == 190)
        handlers.mask("caves", "A", 128)
        assert(health.maxhealth == 190)
        world.recheck()
        assert(sent[#sent][1] == "query")
        handlers.mask("caves", "A", 0)
        assert(health.maxhealth == 170)
        statue:Remove()
        handlers.query("caves", "A")
        assert(sent[#sent][1] == "mask" and sent[#sent][4] == 0)
    end)
end
