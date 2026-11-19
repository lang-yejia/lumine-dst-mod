local Catalog = require("journey/catalog")
local Bosses = require("journey/boss_guides")
local Routes = require("journey/expedition_routes")

local M = {}
local entries
local aliases = {
    charlie_boss = "查理 暗影女王 shrouded queen",
    shrouden = "暗影憎恶 暗影憎恨 umbral abomination",
    wagboss_robot = "战争瓦器人 战争机器人 warbot w.a.r.b.o.t.",
    stalker_atrium = "织影者 骨头 boss fuelweaver",
    alterguardian_phase3 = "天体英雄 月亮 boss 天体冠军 celestial champion",
    alterguardian_phase1_lunarrift = "天体仇灵 celestial revenant",
    alterguardian_phase4_lunarrift = "天体后裔 celestial scion",
    toadstool = "毒菌蟾蜍王",
    moose = "鹿鹅 鹅鹿",
    minotaur = "犀牛 迷宫",
}

local function Name(id)
    return STRINGS.NAMES[id:upper()] or ""
end

local function Add(entry, terms, items)
    local keywords = {}
    for _, item in ipairs(items or {}) do
        keywords[#keywords + 1] = table.concat({item[1], Name(item[1]), item[3] or ""}, " ")
    end
    entry.name_key = string.lower(entry.title .. " " .. (terms or ""))
    entry.material_key = string.lower(table.concat(keywords, " "))
    entry.body_key = string.lower(entry.body or "")
    entries[#entries + 1] = entry
end

local function Build()
    entries = {}
    for _, group in ipairs(Bosses.groups) do
        for _, boss in ipairs(group.entries) do
            Add({kind="boss", id=boss.id, title=boss.title, path="首领指南 / " .. group.title, image=boss.image,
                body=table.concat({boss.where,boss.trigger,boss.prep,boss.fight,boss.loot,boss.next_step}, " ")},
                table.concat({boss.id, Name(boss.id), aliases[boss.id] or ""}, " "), boss.items)
        end
    end
    for _, kind in ipairs({"lunar", "shadow"}) do
        local route = Routes[kind]
        Add({kind=kind, title=route.title, path="探索路线", image=route.image, body=route.intro})
        for page, stage in ipairs(route.stages) do
            for lane, branch in ipairs(stage.lanes) do
                for step, node in ipairs(branch.steps) do
                    Add({kind=kind, page=page, lane=lane, step=step, title=node.title,
                        path=route.title .. " / " .. stage.title, image=node.image, body=node.text},
                        nil, node.items)
                end
            end
        end
    end
    for _, volume in ipairs(Catalog.volumes) do
        for _, chapter in ipairs(volume.entries) do
            Add({kind="chapter", id=chapter.id, title=chapter.title, path=volume.title .. " / " .. chapter.group,
                chapter=chapter, body=chapter.intro .. " " .. chapter.body})
        end
    end
end

function M.Search(query)
    if not entries then Build() end
    local words, matches = {}, {}
    for word in string.lower(query):gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return matches end
    for index, entry in ipairs(entries) do
        local score = 0
        for _, word in ipairs(words) do
            if entry.title == word then score = score + 16
            elseif entry.name_key:find(word, 1, true) then score = score + 8
            elseif entry.material_key:find(word, 1, true) then score = score + 4
            elseif entry.body_key:find(word, 1, true) then score = score + 1
            else score = 0 break end
        end
        if score > 0 then matches[#matches + 1] = {entry=entry, index=index, score=score} end
    end
    table.sort(matches, function(a,b)
        if a.score ~= b.score then return a.score > b.score end
        return a.index < b.index
    end)
    local results = {}
    for i, match in ipairs(matches) do results[i] = match.entry end
    return results
end

local related_steps = {
    crabking = "tribute",
    charlie_boss = "queen",
    shrouden = "abomination",
    bat_boss_shadow = "larynx",
    rocky_boss_shadow = "claw",
    worm_boss_shadow = "guts",
    mutatedbearger = "mutations",
    mutatedwarg = "mutations",
    daywalker2 = "siphon",
    lunar_grazer = "cages",
}

function M.BossStep(kind, id)
    for page, stage in ipairs(Routes[kind].stages) do
        for lane, branch in ipairs(stage.lanes) do
            for step, node in ipairs(branch.steps) do
                if node.boss == id or node.id == related_steps[id] then
                    return {page=page, lane=lane, step=step}
                end
            end
        end
    end
end

return M
