local F = require("fixtures")
local Data = require("lumine_progression")

return function(test)
    test("reject wrong, unexperienced and already completed evidence", function()
        F.world()
        local owner, journey, pet, _, inventory = F.player()
        assert(not journey:BeginRecording(owner:Hold(F.item("twigs")), pet))
        local item = owner:Hold(F.item("moonrocknugget"))
        assert(not journey:BeginRecording(item, pet))
        journey.done.lunar, journey.experienced.lunar = true, true
        assert(not journey:BeginRecording(item, pet))
        assert(inventory.active == item and inventory.removals == 0 and journey.insight == 0)
    end)
    test("shared evidence chooses first eligible unfinished chapter", function()
        F.world()
        local owner, journey, pet = F.player()
        local original = Data.BY_EVIDENCE.moonrocknugget
        Data.BY_EVIDENCE.moonrocknugget = {"lunar", "deerclops", "minotaur"}
        journey.done.lunar, journey.experienced.minotaur = true, true
        local accepted = journey:BeginRecording(owner:Hold(F.item("moonrocknugget")), pet)
        Data.BY_EVIDENCE.moonrocknugget = original
        assert(accepted and journey.records.active.id == "minotaur")
    end)
    test("unsafe snapshots are refused before removal", function()
        F.world()
        local owner, journey, pet, _, inventory = F.player()
        journey.experienced.lunar = true
        for _, make_unsafe in ipairs({
            function(item) item.refs = {1234} end,
            function(item) item.GetSaveRecord = function() error("broken OnSave") end end,
            function(item) item.GetSaveRecord = function() return {} end end,
            function(item) item.fields.custom = {bad = function() end} end,
            function(item) item.fields.container = {items = {{prefab = "twigs"}}} end,
            function(item) item.components.container = {GetAllItems = function() return {F.item("twigs")} end} end,
        }) do
            local item = owner:Hold(F.item("moonrocknugget"))
            make_unsafe(item)
            assert(not journey:BeginRecording(item, pet))
            assert(item:IsValid() and inventory.active == item and inventory.removals == 0)
        end
    end)
    test("empty container evidence is supported and removal refusal preserves it", function()
        F.world()
        local owner, journey, pet, bag, inventory = F.player()
        journey:Complete("alterguardian_phase3")
        local shard = owner:Hold(F.item("alterguardianhatshard", {container = {items = {}}}))
        shard.components.container = {GetAllItems = function() return {} end}
        inventory.reject = true
        assert(not journey:BeginRecording(shard, pet) and not journey.records.active and shard:IsValid())
        inventory.reject = nil
        assert(journey:BeginRecording(shard, pet))
        F.tick(journey)
        assert(journey.insight == 5 and bag.slots[1].prefab == "alterguardianhatshard")
    end)
    test("single evidence removed before an inventory callback throws remains recoverable", function()
        F.world()
        local owner, journey, pet, bag, inventory = F.player()
        journey:Complete("lunar")
        local item = owner:Hold(F.item("moonrocknugget"))
        inventory.on_remove = function() error("simulated cursor callback failure") end
        assert(journey:BeginRecording(item, pet) and not item:IsValid())
        F.tick(journey)
        assert(journey.insight == 3 and bag.slots[1] and not bag.slots[2])
    end)
    test("invalid snapshot does not award or block another delivery", function()
        local env = F.world()
        local owner, journey, pet, bag = F.player()
        journey.experienced.lunar = true
        assert(journey:BeginRecording(owner:Hold(F.item("moonrocknugget")), pet))
        env.error_prefab = "moonrocknugget"
        F.tick(journey)
        assert(not journey.done.lunar and journey.insight == 0 and not journey.records.active)
        assert(#journey.records.issues == 1 and #journey.records.pending == 0 and not env.spawned[1]:IsValid())
        env.error_prefab = nil
        assert(journey:BeginRecording(owner:Hold(F.item("moonrocknugget")), pet))
        F.tick(journey)
        assert(bag.slots[1].prefab == "moonrocknugget" and journey.insight == 3)
    end)
    test("legacy insight, skills and pending items survive migration", function()
        F.world()
        local _, journey, _, bag = F.player({insight = 13, done = {night = true},
            skills = {rations = true}, experienced = {winter = true},
            record_returns = {{prefab = "royal_jelly", data = {perishable = {time = 40}}}}})
        assert(journey.insight == 15 and journey.skills.rations and journey.done.night and journey.done.winter)
        assert(journey:GetAvailableInsight() == 15 - journey:GetSpentInsight())
        F.tick(journey, 1)
        assert(bag.slots[1].fields.perishable.time == 40 and journey.insight == 15)
        local _, reloaded = F.player(journey:OnSave())
        assert(reloaded.insight == 15 and reloaded.skills.rations)
    end)
    test("duplicate transaction tokens and corrupt legacy entries", function()
        F.world()
        local work = {token = 1, id = "lunar", item = {prefab = "moonrocknugget"}, remaining = 0}
        local _, journey, _, bag = F.player({insight = 3, done = {lunar = true},
            evidence_records = {active = work, pending = {work, work, {token = 2, item = "invalid"}}}})
        assert(#journey.records.pending == 1 and #journey.records.issues == 1 and not journey.records.active)
        F.tick(journey)
        assert(journey.insight == 3 and bag.slots[1] and not bag.slots[2] and #journey.records.pending == 0)
    end)
    test("temporarily unavailable prefab can be recovered on reload", function()
        local env = F.world()
        local owner, journey, pet = F.player()
        journey:Complete("lunar")
        assert(journey:BeginRecording(owner:Hold(F.item("moonrocknugget")), pet))
        env.fail_prefab = "moonrocknugget"
        F.tick(journey)
        assert(journey.insight == 0 and #journey.records.issues == 1)
        env.fail_prefab = nil
        local _, loaded, _, bag = F.player(journey:OnSave())
        F.tick(loaded, 1)
        assert(loaded.insight == 3 and bag.slots[1] and #loaded.records.issues == 0)
    end)
    test("independent players and server authority", function()
        F.world()
        local owner, journey, pet = F.player()
        local other, other_journey, other_pet = F.player()
        journey.experienced.lunar = true
        local foreign = other:Hold(F.item("moonrocknugget"))
        assert(not journey:BeginRecording(foreign, pet))
        local item = owner:Hold(F.item("moonrocknugget"))
        assert(not journey:BeginRecording(item, other_pet))
        owner.distance = 16
        assert(not journey:BeginRecording(item, pet))
        owner.distance = 0
        TheWorld.ismastersim = false
        assert(not journey:BeginRecording(item, pet))
        TheWorld.ismastersim = true
        assert(journey:BeginRecording(item, pet))
        F.tick(journey)
        assert(journey.insight == 3 and other_journey.insight == 0 and foreign:IsValid())
    end)
end
