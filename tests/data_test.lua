local Data = require("lumine_progression")
local Chapters = require("journey/chapters")
local Catalog = require("journey/catalog")
local Artifacts = require("lumine_artifact_data")

return function(test)
    test("legacy chapter IDs and order", function()
        local ids = {"night", "winter", "spring", "summer", "cave", "sail", "lunar", "pigking",
            "ancient_altar", "hermitcrab", "deerclops", "dragonfly", "minotaur", "alterguardian_phase3",
            "bearger", "moose", "beequeen", "klaus", "stalker_atrium", "crabking"}
        assert(#Data.MILESTONES >= #ids)
        for index, id in ipairs(ids) do
            assert(Data.MILESTONES[index].id == id and Chapters.index_by_id[id] == index, id)
        end
    end)
    test("complete, uniquely indexed chapters", function()
        local seen = {}
        local function nonempty(value) return type(value) == "string" and value:find("%S") ~= nil end
        for _, chapter in ipairs(Chapters.all) do
            local id = chapter.id
            assert(not seen[id] and Chapters.by_id[id] == chapter, id)
            seen[id] = true
            assert(Chapters.groups[chapter.group] and (chapter.source == "vanilla" or chapter.source == "mod"), id)
            assert(nonempty(chapter.title) and nonempty(chapter.summary) and nonempty(chapter.teaser), id)
            assert(#chapter.body > 0 and nonempty(chapter.paimon.complete), id)
            for _, paragraph in ipairs(chapter.body) do assert(nonempty(paragraph), id) end
            assert(nonempty(chapter.image.atlas) and nonempty(chapter.image.tex), id)
            for _, linked in ipairs(chapter.related or {}) do assert(Chapters.by_id[linked], id .. " -> " .. linked) end
        end
    end)
    test("reward and evidence indexes match chapter definitions", function()
        local expected = {}
        for _, entry in ipairs(Data.MILESTONES) do
            assert(entry.reward > 0 and entry.reward % 1 == 0 and Chapters.by_id[entry.id].reward == entry.reward, entry.id)
            local evidence = Data.EVIDENCE[entry.id]
            for _, prefab in ipairs(type(evidence) == "string" and {evidence} or evidence or {}) do
                assert(prefab:match("^[a-z0-9_]+$"), prefab)
                expected[prefab] = expected[prefab] or {}
                assert(not expected[prefab][entry.id], "duplicate mapping " .. prefab)
                expected[prefab][entry.id] = true
            end
        end
        for prefab, ids in pairs(Data.BY_EVIDENCE) do
            for _, id in ipairs(ids) do
                assert(expected[prefab] and expected[prefab][id], prefab .. " -> " .. id)
                expected[prefab][id] = nil
            end
        end
        for prefab, remaining in pairs(expected) do assert(next(remaining) == nil, prefab) end
        for _, chapter in ipairs(Chapters.groups.traveler) do assert(chapter.reward == 0, chapter.id) end
    end)
    test("selected catalog covers each legacy milestone exactly once", function()
        local counts = {world = 18, traveler = 4, treasures = 6, partners = 2}
        local seen = {}
        local volumes = 0
        for _, volume in ipairs(Catalog.volumes) do
            assert(#volume.entries == counts[volume.id], volume.id)
            counts[volume.id] = nil
            volumes = volumes + 1
            assert(Catalog.by_volume[volume.id] == volume, volume.id)
            assert(Catalog.by_id[volume.feature].volume_id == volume.id, volume.id)
            assert(volume.subtitle ~= "" and #volume.ink == 4, volume.id)
            local groups = {}
            for _, group in ipairs(volume.groups or {}) do groups[group] = 0 end
            for number, chapter in ipairs(volume.entries) do
                assert(chapter.number == number and chapter.volume_id == volume.id, chapter.id)
                if volume.groups then
                    assert(groups[chapter.group] ~= nil, chapter.id)
                    groups[chapter.group] = groups[chapter.group] + 1
                end
                assert(chapter.title ~= "" and chapter.intro ~= "" and chapter.body ~= "" and chapter.comment ~= "", chapter.id)
                assert(Catalog.Find(chapter.id) == chapter and chapter.image, chapter.id)
                for _, id in ipairs(chapter.related) do assert(Catalog.Find(id), chapter.id .. " -> " .. id) end
                for _, id in ipairs(chapter.milestones or {}) do
                    assert(Chapters.index_by_id[id] and not seen[id] and Catalog.Find(id) == chapter, id)
                    assert(chapter.unlock == (Data.EVIDENCE[id] and "evidence" or "explore"), id)
                    seen[id] = true
                end
                if not chapter.milestones then assert(chapter.unlock == "collection" and not chapter.reward, chapter.id) end
            end
            for group, count in pairs(groups) do assert(count > 0, group) end
        end
        assert(volumes == 4 and next(counts) == nil)
        for _, milestone in ipairs(Data.MILESTONES) do assert(seen[milestone.id], milestone.id) end
        assert(Catalog.Find("spring") == Catalog.Find("seasons") and Catalog.Find("winter") == Catalog.Find("seasons"))
        assert(Catalog.Find("lumine_alchemy") == Catalog.Find("lumine_sword"))
        local seasons = Catalog.Find("seasons").seasons
        assert(#seasons == 4 and seasons[1].id == nil)
        for i = 2, #seasons do assert(seasons[i].id == Catalog.Find("seasons").milestones[i - 1]) end
    end)
    test("collection cards follow existing relic sets and forging routes", function()
        for _, set in ipairs(Artifacts.SETS) do
            local chapter = Catalog.Find("relic_" .. set.id)
            assert(chapter.relic_set == set.id and #set.parts == 5 and not chapter.milestones, set.id)
        end
        local forge = require("lumine_forging_data")
        local stats = require("lumine_gear_stats").by_name
        for _, id in ipairs({"lumine_sword", "lumine_armor"}) do
            local routes = Catalog.Find(id).routes
            assert(#routes == (id == "lumine_sword" and 1 or 2), id)
            for _, route in ipairs(routes) do
                assert(#route == 4, id)
                for _, prefab in ipairs(route) do assert(stats[prefab], prefab) end
                for index = 1, #route - 1 do
                    assert(forge.BY_OLD[route[index]].new == route[index + 1], route[index])
                end
            end
        end
    end)
end
