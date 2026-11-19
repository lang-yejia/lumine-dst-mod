local C = require("paimon/config")
local Lore = require("paimon/lore_service")
local Memory = require("paimon/memory")
local Guide = require("paimon/guide")
local M = {}
local ELEMENTS = { [0] = "anemo", "geo", "electro", "dendro", "hydro", "pyro", "cryo" }
local WORK = { CHOP = "chop", MINE = "mine", HAMMER = "craft" }
local LANDMARKS = {
    firepit = "fire", campfire = "fire", coldfirepit = "fire",
    treasurechest = "chest", cookpot = "crockpot", researchlab = "research",
    researchlab2 = "research", farm_plant_randomseed = "farm", farm_soil = "farm",
    multiplayer_portal = "portal", multiplayer_portal_moonrock = "portal",
    rabbit = "rabbit", pigman = "pig", chester = "chester",
    ancient_altar = "ruins", ancient_altar_broken = "ruins",
}
local function Offer(pet, event) pet.dialogue:Offer(event) end
local function Terrain(owner)
    if owner:GetCurrentPlatform() then return "ocean" end
    local x, y, z = owner.Transform:GetWorldPosition()
    local tile = TheWorld.Map:GetTileAtPoint(x, y, z)
    local names = { MARSH = "swamp", FOREST = "forest", ROCKY = "rocky", SAVANNA = "grass",
        GRASS = "grass", DESERT_DIRT = "desert",
        TILES = "ruins", TILES_GLOW = "ruins", TRIM = "ruins", TRIM_GLOW = "ruins",
        BRICK = "ruins", PEBBLEBEACH = "lunar", FUNGUSMOON = "lunar" }
    for name, event in pairs(names) do if WORLD_TILES[name] and tile == WORLD_TILES[name] then return event end end
    if TheWorld:HasTag("cave") then return "cave" end
end

function M.Update(pet, owner)
    if pet._dormant or not owner:IsValid() then return end
    local t, state = GetTime(), TheWorld.state
    local health, hunger, sanity = owner.components.health, owner.components.hunger, owner.components.sanity
    if health and health:GetPercent() < .2 then Offer(pet, "low_health") end
    if hunger and hunger:GetPercent() < .2 then Offer(pet, "low_hunger") end
    if sanity and sanity:GetPercent() < .2 then Offer(pet, "low_sanity") end
    local temperature = owner.components.temperature
    if temperature then
        if temperature:GetCurrent() < 0 then Offer(pet, "freezing")
        elseif temperature:GetCurrent() > TUNING.OVERHEAT_TEMP then Offer(pet, "overheat") end
    end
    if pet.satiety <= 0 then Offer(pet, "starving")
    elseif pet.satiety < C.AUTO_EAT_BELOW then Offer(pet, "hungry") end
    local target = owner.components.combat and owner.components.combat.target
    if target and target:IsValid() then
        pet._worried_until = t + 7
        Offer(pet, target:HasTag("epic") and "boss" or "combat")
    end
    for _, key in ipairs({ "phase", "season", "israining", "isfullmoon" }) do
        local value = state[key]
        if value ~= pet._observed[key] then
            pet._observed[key] = value
            if key == "phase" or key == "season" then Offer(pet, value)
            elseif value then Offer(pet, key == "israining" and "rain" or "fullmoon") end
        end
    end
    local x, y, z = owner.Transform:GetWorldPosition()
    if pet._lastposition then
        local dx, dz = x - pet._lastposition[1], z - pet._lastposition[2]
        local distance = math.sqrt(dx * dx + dz * dz)
        -- 传送不计作步行，避免虫洞/洞穴刷远行条件。
        if distance < 80 then pet.journey.distance = pet.journey.distance + distance end
        if distance > 10 and distance < 80 then Offer(pet, "travel") end
    end
    pet._lastposition = { x, z }
    local terrain = Terrain(owner)
    if terrain ~= pet._terrain then pet._terrain = terrain; if terrain then Offer(pet, terrain) end end
    local context = terrain
    local found = {}
    local nearby = TheSim:FindEntities(x, y, z, 10, nil, { "INLIMBO", "FX", "NOCLICK" })
    Memory.ObserveFire(pet,nearby)
    for _, entity in ipairs(nearby) do
        local event = LANDMARKS[entity.prefab]
        if entity:HasTag("farm_plant") then event = "farm" end
        if event then
            found[event] = true
            if not pet._nearby[event] then Offer(pet, event) end
            if event == "ruins" or event == "portal" then context = event end
        end
        if entity:HasTag("shadowcreature") or entity:HasTag("nightmarecreature") then context = "shadow" end
        if entity:HasTag("epic") and entity.components.health and not entity.components.health:IsDead() then Offer(pet, "boss") end
    end
    if found.fire and not pet._nearby.fire then Offer(pet, "return") end
    pet._nearby = found
    if not target then
        if pet.journey.distance > 2000 then Offer(pet, "longtrip") end
        Offer(pet, "companion")
        Offer(pet, "idle")
        if state.isnight and not TheWorld:HasTag("cave") then
            context = state.isfullmoon and "fullmoon" or "night"
        end
        -- 隐藏剧情只在明确环境/经历下抽取，战斗和濒死时不讲长故事。
        if (not health or health:GetPercent() >= .3) and not Guide.HasPending(pet) then
            Lore.Flush(pet)
            if context then Lore.Request(pet, context) end
        end
    end
end

function M.Attach(pet, owner)
    pet._observed, pet._nearby = {}, {}
    local function Listen(event, fn) pet:ListenForEvent(event, function(_, data) fn(data or {}) end, owner) end
    Listen("attacked", function() pet._worried_until = GetTime() + 8; Offer(pet, "attacked") end)
    Listen("killed", function(data)
        local victim = data.victim
        if victim and victim:HasTag("epic") then
            pet.journey.bosses = pet.journey.bosses + 1
            Offer(pet, "boss_victory")
            pet:DoTaskInTime(15, function() if not pet._dormant then Lore.Request(pet, "boss_victory") end end)
        else Offer(pet, "victory") end
    end)
    Listen("working", function(data)
        local action = data.target and data.target.components.workable and data.target.components.workable:GetWorkAction()
        if action and WORK[action.id] then Offer(pet, WORK[action.id]) end
    end)
    Listen("picksomething", function() Offer(pet, "pick") end)
    Listen("builditem", function() Offer(pet, "craft") end)
    Listen("buildstructure", function() Offer(pet, "craft") end)
    Listen("oneat", function() Memory.OwnerAte(pet); Offer(pet, "owner_eat") end)
    Listen("fishingcatch", function() Offer(pet, "fish") end)
    Listen("fishcaught", function() Offer(pet, "fish") end)
    Listen("onwenthome", function() Offer(pet, "sleep") end)
    Listen("death", function(data)
        Memory.Death(pet,data)
        -- 消失前的一句告别；不依赖下一轮台词调度。
        pet.dialogue.pending = {}
        pet.dialogue.cooldowns.death = nil -- 每次真实死亡都允许告别，次数用于选择内容。
        pet.dialogue:Offer("death"); pet.dialogue.nextspeech = 0; pet.dialogue.speaking_until = 0
        pet.dialogue:Update()
    end)
    Listen("ms_respawnedfromghost", function() Offer(pet, "revive") end)
    Listen("lumine_paimon_element", function(data)
        local element = ELEMENTS[data.element]
        if element then
            Memory.Element(pet,data)
            Offer(pet, element .. "_" .. (data.slot and ("skill" .. data.slot) or "switch"))
        end
    end)
    -- 原版 SG 事件可区分睡觉和钓鱼，烹饪由成功的 COOK 动作触发。
    Listen("newstate", function()
        local name = owner.sg and owner.sg.currentstate and owner.sg.currentstate.name or ""
        if name == "bedroll" or name == "tent" then Offer(pet, "sleep")
        elseif name == "fishing" or name == "oceanfishing_cast" then Offer(pet, "fish") end
    end)
    pet:DoPeriodicTask(C.OBSERVE_INTERVAL, function() M.Update(pet, owner) end, 2)
end
return M
