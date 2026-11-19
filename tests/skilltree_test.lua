local F = require("fixtures")
local Nodes = require("skilltree/lumine_nodes")
local Effects = require("skilltree/lumine_effects")
local Exchange = require("skilltree/lumine_exchange")
local wind, geo = Nodes.elements.wind, Nodes.elements.geo
local codex, hut = Nodes.recipes.lumine_relic_codex, Nodes.recipes.lumine_aranara_hut

local function Setup()
    F.world()
    TUNING = {SKILL_THRESHOLDS = DST_SKILL_THRESHOLDS, FIXME_DO_NOT_USE_FOR_MODS_OLD_MAX_XP_VALUE = 160}
    STRINGS = {SKILLTREE = {PANELS = {}}}
    function orderedPairs(tbl)
        local keys, i = {}, 0
        for key in pairs(tbl) do keys[#keys + 1] = key end
        table.sort(keys)
        return function()
            i = i + 1
            if keys[i] then return keys[i], tbl[keys[i]] end
        end
    end
    function string.split(value, delimiter)
        local parts, pattern = {}, "([^" .. delimiter .. "]+)"
        for part in value:gmatch(pattern) do parts[#parts + 1] = part end
        return parts
    end
    function table.count(tbl)
        local n = 0
        for _ in pairs(tbl) do n = n + 1 end
        return n
    end
    function math.clamp(value, lo, hi) return math.max(lo, math.min(hi, value)) end
    bit = {bor = function(a, b) return a + b end}
    RegisterSkilltreeIconsAtlas = function() end
    require("skilltree/lumine_native").Register()
end

local function Player(legacy, saved)
    local owner, journey = F.player(legacy)
    owner.userid = "test-user"
    owner.components.experiencecollector = {}
    owner.xpgeneration_task = {Cancel = function() owner.experience_cancelled = true end}
    function owner:RemoveComponent(name) self.components[name] = nil end
    owner.components.luminegeo = {
        EndField = function(self) self.ended = true end,
        EndShield = function(self) self.shield_ended = true end,
        Sync = function() end,
    }
    owner._lumine_skilltree = {
        value = function(self) return self.encoded or "" end,
        set = function(self, encoded) self.encoded = encoded end,
    }
    owner._lumine_insight_exchange = F.copy(owner._lumine_skilltree)
    owner.components.skilltreeupdater = {}
    require("skilltree/lumine_bridge").Attach(owner)
    local tree = require("components/lumineskilltree")(owner)
    owner.components.lumineskilltree = tree
    if saved then tree:OnLoad(F.copy(saved)) end
    tree:Initialize()
    return owner, journey, tree
end

local function BuyTwo(journey, tree)
    journey.insight = 5
    assert(tree:ExchangeInsight(1) and tree:ExchangeInsight(2))
end

return function(test)
    test("native registration, prerequisites, resources and effect mapping", function()
        Setup()
        local native = require("prefabs/skilltree_defs")
        local defs = native.SKILLTREE_DEFS.lumine
        local seen, count = {}, 0
        assert(#Nodes.branches == 5 and #Nodes.nodes == 27)
        assert(DST_SKILLTREE_PAPER:find('name="scrap_square.tex"', 1, true))
        for _, branch in ipairs(Nodes.branches) do
            assert(STRINGS.SKILLTREE.PANELS[branch.id:upper()] == branch.title)
            assert(DST_SKILLTREE_ICONS:find('name="' .. branch.icon .. '.tex"', 1, true))
            for _, node in ipairs(branch.nodes) do
                local def = defs[node.id]
                assert(not seen[node.id] and node.branch == branch.id and def.group == branch.id)
                if node.requires then
                    assert(seen[node.requires] and def.must_have_one_of[node.requires])
                end
                seen[node.id] = true
                if node.status == "implemented" then
                    assert(def.rpc_id ~= nil and Effects.handlers[node.effect.type])
                    count = count + 1
                else
                    assert(node.effect == nil and def.rpc_id == nil and not def.lock_open())
                    assert(def.desc:find("尚未开放", 1, true))
                end
                local atlas, tex = Nodes.icons[node.icon], node.icon .. ".tex"
                if atlas then
                    assert(check_mod_skilltree_icon(atlas, tex), tex)
                else
                    assert(DST_SKILLTREE_ICONS:find('name="' .. tex .. '"', 1, true), tex)
                end
            end
        end
        assert(count == 10 and native.SKILLTREE_METAINFO.lumine.TOTAL_SKILLS_COUNT == 10)
        assert(table.count(Nodes.elements) == 7)
        for _, id in pairs(Nodes.elements) do assert(Nodes.by_id[id].requires == Nodes.foundation) end
        for _, skill in ipairs(require("lumine_progression").SKILLS) do
            assert(Nodes.by_id[Nodes.legacy[skill.id]].status == "planned")
        end
    end)

    test("electro requires the native node and survives a normal reload", function()
        Setup()
        local owner, journey, tree = Player()
        assert(not journey:Resonate("electro"))
        BuyTwo(journey, tree)
        assert(not tree:Learn(Nodes.elements.electro))
        assert(tree:Learn(Nodes.foundation) and tree:Learn(Nodes.elements.electro))
        assert(journey:Resonate("electro") and owner._lumine_element_active.value == 3)
        assert(journey:GetElementMask() == 4)
        local _, loaded, restored = Player(journey:OnSave(), tree:OnSave())
        assert(loaded.active_element == "electro" and restored.elements.electro)
        assert(restored:Reset() and loaded.active_element == nil)
    end)

    test("dendro requires its existing node and preserves resonance across reload", function()
        Setup()
        local owner, journey, tree = Player()
        assert(not journey:Resonate("dendro"))
        BuyTwo(journey, tree)
        assert(not tree:Learn(Nodes.elements.dendro))
        assert(tree:Learn(Nodes.foundation) and tree:Learn(Nodes.elements.dendro))
        assert(journey:Resonate("dendro") and owner._lumine_element_active.value == 4)
        assert(journey:GetElementMask() == 8)
        local _, loaded, restored = Player(journey:OnSave(), tree:OnSave())
        assert(loaded.active_element == "dendro" and restored.elements.dendro)
        assert(restored:Reset() and loaded.active_element == nil)
    end)

    test("hydro uses the existing native node and restores resonance from a save", function()
        Setup()
        local owner, journey, tree = Player()
        assert(not journey:Resonate("hydro"))
        BuyTwo(journey, tree)
        assert(not tree:Learn(Nodes.elements.hydro))
        assert(tree:Learn(Nodes.foundation) and tree:Learn(Nodes.elements.hydro))
        assert(journey:Resonate("hydro") and owner._lumine_element_active.value == 5)
        assert(journey:GetElementMask() == 16)
        local _, loaded, restored = Player(journey:OnSave(), tree:OnSave())
        assert(loaded.active_element == "hydro" and restored.elements.hydro)
        assert(restored:Reset() and loaded.active_element == nil)
    end)

    test("pyro unlocks at its existing node and persists through reload", function()
        Setup()
        local owner, journey, tree = Player()
        assert(not journey:Resonate("pyro"))
        BuyTwo(journey, tree)
        assert(not tree:Learn(Nodes.elements.pyro))
        assert(tree:Learn(Nodes.foundation) and tree:Learn(Nodes.elements.pyro))
        assert(journey:Resonate("pyro") and owner._lumine_element_active.value == 6)
        assert(journey:GetElementMask() == 32)
        local _, loaded, restored = Player(journey:OnSave(), tree:OnSave())
        assert(loaded.active_element == "pyro" and restored.elements.pyro)
        assert(restored:Reset() and loaded.active_element == nil)
    end)

    test("cryo uses its existing node and survives reload and resetting", function()
        Setup()
        local owner, journey, tree = Player()
        assert(not journey:Resonate("cryo"))
        BuyTwo(journey, tree)
        assert(not tree:Learn(Nodes.elements.cryo))
        assert(tree:Learn(Nodes.foundation) and tree:Learn(Nodes.elements.cryo))
        assert(journey:Resonate("cryo") and owner._lumine_element_active.value==7)
        assert(journey:GetElementMask()==64)
        local _, loaded, restored = Player(journey:OnSave(),tree:OnSave())
        assert(loaded.active_element=="cryo" and restored.elements.cryo)
        assert(restored:Reset() and loaded.active_element==nil)
    end)

    test("observations are the sole new source of points; native grants are blocked", function()
        local owner, journey, tree = Player()
        local updater = owner.components.skilltreeupdater
        updater:AddSkillXP(100, nil, true)
        updater:SetPlayerSkillSelection({31})
        updater:ActivateSkill(wind, nil, true)
        assert(updater:GetSkillXP() == 0 and not updater:IsActivated(wind))
        assert(not tree:Learn(Nodes.foundation))
        assert(owner.experience_cancelled and owner.xpgeneration_task == nil)
        assert(owner.components.experiencecollector == nil and tree.AddExperience == nil)
        assert(not tree:ExchangeInsight(1))
        journey:Complete("night")
        assert(updater:GetSkillXP() == 0 and not tree:ExchangeInsight(1))
        journey:Complete("winter")
        local available, count, cost = Exchange.Decode(owner._lumine_insight_exchange:value())
        assert(available == 3 and count == 0 and cost == 2)
        assert(not tree:ExchangeInsight(2) and not tree:ExchangeInsight("1"))
        owner.tags.playerghost = true
        assert(not tree:ExchangeInsight(1))
        owner.tags.playerghost = nil
        assert(tree:ExchangeInsight(1) and journey.insight == 3 and journey:GetAvailableInsight() == 1)
        assert(not tree:ExchangeInsight(1))
        assert(updater:GetAvailableSkillPoints() == 1)
        assert(not tree:Learn(wind) and not tree:Learn(Nodes.elements.pyro))
        assert(tree:Learn(Nodes.foundation) and tree.features.element_foundation)
        assert(not tree:Learn(Nodes.foundation) and not tree:Learn(wind))
        journey:Complete("spring")
        assert(tree:ExchangeInsight(2) and journey:GetAvailableInsight() == 0)
        assert(tree:Learn(wind) and updater:IsActivated(wind) and journey:Resonate("wind"))
        assert(not journey:Resonate("geo"))
        assert(updater:GetPlayerSkillSelection()[1] > 0)
    end)

    test("rising prices, persisted balance, reset and native cap", function()
        local owner, journey, tree = Player({insight = 30, skills = {rations = true}})
        local sum, previous = 0, 0
        for index = 1, #TUNING.SKILL_THRESHOLDS do
            local price = Exchange.Cost(index)
            assert(price > previous)
            if index <= 5 then sum = sum + price end
            previous = price
        end
        assert(sum == 23)
        local total = 0
        for _, milestone in ipairs(require("lumine_progression").MILESTONES) do total = total + milestone.reward end
        assert(total == 40 and total - sum - Exchange.Cost(6) == 7 and Exchange.Cost(7) > 7)
        assert(tree:ExchangeInsight(1) and tree:Learn(codex) and tree:ExchangeInsight(2))
        assert(tree:Reset() and tree:GetNextExchangeCost() == 4)
        assert(journey:GetAvailableInsight() == 23)
        local _, reloaded, reloaded_tree = Player(journey:OnSave(), tree:OnSave())
        assert(reloaded:GetAvailableInsight() == 23 and reloaded_tree:GetNextExchangeCost() == 4)
        assert(not reloaded_tree:ExchangeInsight(2) and reloaded_tree:ExchangeInsight(3))
        assert(reloaded:GetAvailableInsight() == 19)

        local _, funded, capped = Player({insight = 10000})
        for index = 1, #TUNING.SKILL_THRESHOLDS do assert(capped:ExchangeInsight(index)) end
        local remaining = funded:GetAvailableInsight()
        assert(capped:GetNextExchangeCost() == nil and not capped:ExchangeInsight(#TUNING.SKILL_THRESHOLDS + 1))
        assert(funded:GetAvailableInsight() == remaining)
    end)

    test("legacy elements and purchases migrate once; respec survives reload", function()
        local owner, journey, tree = Player({element_schema_version = 3, insight = 12, skills = {swift = true},
            elements = {wind = true, geo = true}, active_element = "geo", done = {night = true}})
        local updater = owner.components.skilltreeupdater
        assert(updater:IsActivated(Nodes.foundation) and updater:IsActivated(wind) and updater:IsActivated(geo))
        assert(updater:GetAvailableSkillPoints() == 0 and journey.active_element == "geo")
        assert(journey.insight == 12 and journey:GetAvailableInsight() == 9 and journey.done.night)
        assert(tree:Reset() and journey.active_element == nil and owner.components.luminegeo.ended)
        assert(owner.components.luminegeo.shield_ended and updater:GetAvailableSkillPoints() == 3)
        local _, reloaded, reloaded_tree = Player(journey:OnSave(), tree:OnSave())
        assert(not reloaded_tree.elements.wind and not reloaded_tree.elements.geo)
        assert(reloaded.insight == 12 and reloaded.skills.swift and reloaded.elements.wind)
        local _, old, old_tree = Player({skills = {wind_dash = true}, element_schema_version = 1,
            active_element = "none", insight = 3})
        assert(old_tree.elements.wind and not old_tree.elements.geo and old.active_element == nil and old.skills.wind_dash)
        local _, active_only, active_tree = Player({element_schema_version = 3, active_element = "geo"})
        assert(active_only.active_element == "geo" and active_tree.elements.geo and not active_tree.elements.wind)
        local previous_owner, _, previous_tree = Player({insight = 5},
            {version = 1, xp = TUNING.SKILL_THRESHOLDS[1], skills = {[codex] = true}})
        assert(previous_owner.components.skilltreeupdater:IsActivated(codex))
        assert(previous_tree:GetNextExchangeCost() == 2 and previous_tree:GetExchangeSpent() == 0)
    end)

    test("native builder and final recipe gate track both upgrades", function()
        local owner, journey, tree = Player()
        local updater = owner.components.skilltreeupdater
        local registered = {}
        local read = assert(loadstring(DST_SKILLTREE_RECIPES, "@mod/lumine/modmain.lua recipes"))
        setfenv(read, {
            SkillNodes = Nodes, CanBuildTravelRecipe = Effects.CanBuildRecipe, TECH = {SCIENCE_TWO = {}},
            Ingredient = function(prefab, count) return {prefab, count} end,
            AddCharacterRecipe = function(name, ingredients, tech, config)
                config.name, config.ingredients, config.tech = name, ingredients, tech
                registered[name] = config
            end,
        })
        read()
        local codex_recipe, hut_recipe = registered.lumine_relic_codex, registered.lumine_aranara_hut
        assert(codex_recipe.builder_tag == "lumine" and codex_recipe.builder_skill == codex)
        assert(hut_recipe.builder_tag == "lumine" and hut_recipe.builder_skill == hut)
        assert(codex_recipe.tech == hut_recipe.tech and hut_recipe.placer == "lumine_aranara_hut_placer")
        local function Ingredients(recipe)
            local labels = {}
            for i, ingredient in ipairs(recipe.ingredients) do labels[i] = table.concat(ingredient, ":") end
            return table.concat(labels, " ")
        end
        assert(Ingredients(codex_recipe) == "papyrus:2 goldnugget:2 moonrocknugget:1 livinglog:1")
        assert(Ingredients(hut_recipe) == "rope:2 cutstone:3 livinglog:2 boards:3 treegrowthsolution:1 mandrake:1")
        local function Allowed(recipe)
            return updater:IsActivated(recipe.builder_skill) and recipe.canbuild(recipe, owner)
        end
        assert(not Allowed(codex_recipe) and not Allowed(hut_recipe))
        BuyTwo(journey, tree)
        assert(tree:Learn(codex) and Allowed(codex_recipe) and not Allowed(hut_recipe))
        assert(tree:Learn(hut) and Allowed(hut_recipe))
        assert(not Effects.CanBuildRecipe(codex_recipe, {components = {}}))
        assert(tree:Reset() and not Allowed(codex_recipe) and not Allowed(hut_recipe))
    end)

    test("client snapshots replace stale skills and never accept a placeholder", function()
        local owner, journey, tree = Player()
        BuyTwo(journey, tree)
        assert(tree:Learn(Nodes.foundation) and tree:Learn(wind))
        local mirror = {components = {skilltreeupdater = {}}, _lumine_skilltree = owner._lumine_skilltree,
            ListenForEvent = function() end}
        require("skilltree/lumine_bridge").Attach(mirror)
        assert(mirror.components.skilltreeupdater:IsActivated(wind))
        tree:Reset()
        assert(not mirror.components.skilltreeupdater:IsActivated(wind))
        mirror._lumine_skilltree:set("lumine_element_mastery,lumine_element_geo|12")
        assert(not mirror.components.skilltreeupdater:IsActivated(geo))
        assert(not mirror.components.skilltreeupdater:IsActivated("lumine_element_mastery"))
    end)

    test("native reroll data carries server allocations through another character's save", function()
        local owner, journey, tree = Player()
        local bridge = require("skilltree/lumine_bridge")
        local function AddReroll(inst)
            inst.SaveForReroll = function() return {age = 10} end
            inst.LoadForReroll = function(self, data) self.age = data.age end
            inst.AddComponent = function(self, name)
                self.components[name] = require("components/" .. name)(self)
                return self.components[name]
            end
            bridge.AttachReroll(inst)
        end
        AddReroll(owner)
        journey.insight = 4
        assert(tree:ExchangeInsight(1))
        assert(tree:Learn(codex))
        local wilson = {components = {}}
        AddReroll(wilson)
        wilson:LoadForReroll(owner:SaveForReroll())
        assert(wilson.age == 10 and not Effects.CanBuildRecipe({name = "lumine_relic_codex"}, wilson))
        local saved = wilson.components.lumineskilltreecarry:OnSave()
        assert(saved.add_component_if_missing)
        local restored = {components = {}}
        AddReroll(restored)
        restored:AddComponent("lumineskilltreecarry"):OnLoad(saved)
        local returned, returned_journey, returned_tree = Player()
        AddReroll(returned)
        returned:LoadForReroll(restored:SaveForReroll())
        assert(returned_journey.insight == 4 and returned_journey:GetAvailableInsight() == 2)
        assert(returned_tree.recipes.lumine_relic_codex and returned_tree:GetNextExchangeCost() == 3)
    end)
end
