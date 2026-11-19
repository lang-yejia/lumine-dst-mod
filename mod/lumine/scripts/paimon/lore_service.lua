local C = require("paimon/config")
local Lore = require("paimon/lore")
local M = {}
function M.Deliver(pet, id)
    if pet and pet:IsValid() and Lore.byid[id] then
        pet.journey.pending_lore = id
        pet._next_lore = GetTime() + C.LORE_COOLDOWN
    end
end
function M.Flush(pet)
    local id = pet.journey.pending_lore
    local line = id and Lore.byid[id]
    if line and not pet.dialogue:HasUrgentPending() and pet.dialogue:Speak(line.text, 2, id) then
        pet.journey.pending_lore = nil
    end
end
function M.Request(pet, context)
    if pet.journey.pending_lore or GetTime() < (pet._next_lore or 0)
        or pet.dialogue:HasUrgentPending() or not pet.dialogue:CanSpeak(2) then return end
    pet._next_lore = GetTime() + 60
    if math.random() > C.LORE_CHANCE then return end
    local days = TheWorld.state.cycles or 0
    if TheWorld.ismastershard then
        local world = TheWorld.components.paimonworld
        if world then M.Deliver(pet, world:Claim(context, days, pet.journey.distance, pet.journey.bosses)) end
    elseif M.SendRequest then
        M.SendRequest(pet.owner.userid, context, days, pet.journey.distance, pet.journey.bosses)
    end
end

function M.InstallRPC(G, add, send, get)
    local namespace = "DS_LUMINE_PAIMON"
    M.SendRequest = function(userid, context, days, distance, bosses)
        send(get(namespace, "request"), nil, userid, context, days, distance, bosses)
    end
    add(namespace, "request", function(shardid, userid, context, days, distance, bosses)
        local world = G.TheWorld
        if not world or not world.ismastershard or not world.components.paimonworld then return end
        if type(userid) ~= "string" or type(context) ~= "string" or type(days) ~= "number"
            or type(distance) ~= "number" or type(bosses) ~= "number" then return end
        local id = world.components.paimonworld:Claim(context, days, distance, bosses)
        if id then send(get(namespace, "deliver"), shardid, userid, id) end
    end)
    add(namespace, "deliver", function(shardid, userid, id)
        if G.TheWorld.ismastershard then return end
        for _, player in ipairs(G.AllPlayers) do
            if player.userid == userid then M.Deliver(player._paimon, id); return end
        end
    end)
end
return M
