-- Flight reactions share the normal speech scheduler. Recheck the situation
-- before speaking so a queued ocean warning cannot play after safe landing.
local Ground = require("flight/lumine_flight_ground")
local Rules = require("lumine_energy_rules")
local M = {}
local function State(pet)
    local owner = pet.owner
    if not owner or not owner:IsValid() or pet._dormant or owner:HasTag("playerghost")
        or owner:HasTag("INLIMBO") or (owner.components.health and owner.components.health:IsDead()) then return end
    local phase = owner.lumine_glider_phase and owner.lumine_glider_phase:value() or 0
    return owner, phase, owner._lumine_glider
end

function M.Valid(pet, event)
    if event:sub(1, 7) ~= "glider_" then return true end
    local owner, phase, saved = State(pet)
    if not owner then return false end
    local context = pet._flight_context or {}
    if event == "glider_land" or event == "glider_boat" then
        return phase == 0 and context.landed and GetTime() - context.landed <= 8
            and (owner:GetCurrentPlatform() ~= nil) == (event == "glider_boat")
    end
    if not saved then return false end
    local x, _, z = owner.Transform:GetWorldPosition()
    local ocean = owner:GetCurrentPlatform() == nil and TheWorld.Map:IsOceanTileAtPoint(x, 0, z)
    local drain = (owner._lumine_glider_drain or Rules.WING_DRAIN_OTHER)
        * (ocean and Rules.WING_OCEAN_MULTIPLIER or 1)
    local energy = owner.components.lumineenergy
    local remaining = energy ~= nil and energy.current / drain or math.huge
    if event == "glider_takeoff" then
        return (phase == 1 or phase == 2) and context.started and GetTime() - context.started <= 3
    elseif event == "glider_plunge" then
        return phase == 3 and not (owner.sg and owner.sg.statemem.impacted)
    elseif event == "glider_short" then
        return phase == 2 and remaining > 4
    elseif event == "glider_ocean" then
        return phase == 2 and remaining > 4 and not owner:GetCurrentPlatform()
            and TheWorld.Map:IsOceanTileAtPoint(x, 0, z)
    elseif event == "glider_warning" then
        return phase == 2 and remaining > 0 and remaining <= 4
            and not Ground.CanLand(owner, x, z)
    end
    return false
end

function M.Poll(pet)
    local owner, phase = State(pet)
    if not owner then pet._flight_context = nil; return end
    local context = pet._flight_context or { phase = 0 }
    pet._flight_context = context
    local function Offer(event)
        if M.Valid(pet, event) then pet.dialogue:Offer(event) end
    end
    if phase ~= context.phase then
        if phase == 1 then
            context.started, context.landed = GetTime(), nil
            Offer("glider_takeoff")
        elseif phase == 3 then
            Offer("glider_plunge")
        elseif phase == 0 and context.phase > 0 then
            context.landed = GetTime()
            local x, _, z = owner.Transform:GetWorldPosition()
            if Ground.CanLand(owner, x, z) then
                Offer(owner:GetCurrentPlatform() and "glider_boat" or "glider_land")
            end
        end
        context.phase = phase
    end
    if phase == 2 then
        if M.Valid(pet, "glider_warning") then Offer("glider_warning")
        elseif M.Valid(pet, "glider_ocean") then Offer("glider_ocean")
        else Offer("glider_short") end
    end
end
return M
