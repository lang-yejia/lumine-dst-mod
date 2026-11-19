-- Airspace is independent of walkability. Keep a full tile inside the engine's
-- finite map rectangle, including in caves where interior gaps are INVALID tiles.
local Ground = {}

function Ground.InBounds(x, z)
    if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z
        or math.abs(x) == math.huge or math.abs(z) == math.huge then return false end
    local map = TheWorld.Map
    local tx, tz = map:GetTileCoordsAtPoint(x, 0, z)
    local w, h = map:GetSize()
    return tx >= 1 and tz >= 1 and tx < w - 1 and tz < h - 1
end

function Ground.CanLand(inst, x, z)
    if not Ground.InBounds(x, z) then return false end
    local map, radius = TheWorld.Map, inst:GetPhysicsRadius(.5) + .15
    local platform = map:GetPlatformAtPoint(x, z)
    if platform and (not platform:IsValid() or platform:HasTag("INLIMBO")
        or (platform.components.health and platform.components.health:IsDead())) then return false end
    local function Supported(px, pz)
        return map:IsAboveGroundAtPoint(px, 0, pz, false)
            or (platform ~= nil and map:GetPlatformAtPoint(px, pz) == platform)
    end
    -- Test the whole landing footprint, not just its centre at a shoreline.
    -- The same registered platform must support it at deck edges, too.
    if not Supported(x, z) then return false end
    for i = 0, 7 do
        local angle = i * math.pi / 4
        if not Supported(x + math.cos(angle) * radius, z + math.sin(angle) * radius) then
            return false
        end
    end
    if map:IsGroundTargetBlocked(Vector3(x, 0, z), radius) then return false end
    for _, other in ipairs(TheSim:FindEntities(x, 0, z, radius + 6, nil, { "INLIMBO", "FX", "NOBLOCK" })) do
        -- A boat's hull is an obstacle to other boats, not to its passengers.
        -- Deck structures (including the otter den itself) still block landing.
        if other ~= inst and other ~= platform and other.Physics and other.Physics:IsActive() then
            local group = other.Physics:GetCollisionGroup()
            if group == COLLISION.OBSTACLES or group == COLLISION.SMALLOBSTACLES then
                local clearance = radius + other:GetPhysicsRadius(0)
                if other:GetDistanceSqToPoint(x, 0, z) < clearance * clearance then return false end
            end
        end
    end
    return true
end

function Ground.FindLanding(inst, point)
    if not point or not Ground.InBounds(point.x, point.z) then return end
    if Ground.CanLand(inst, point.x, point.z) then return point end
    -- A wall may have been built on the last safe spot while the owner was away.
    for radius = 1, 12 do
        for i = 0, 15 do
            local angle = i * math.pi / 8
            local x, z = point.x + math.cos(angle) * radius, point.z + math.sin(angle) * radius
            if Ground.CanLand(inst, x, z) then return { x = x, z = z } end
        end
    end
end

function Ground.RecoveryPoint(inst, saved)
    local point = Ground.FindLanding(inst, saved.safe) or Ground.FindLanding(inst, saved.origin)
    if point then return point end
    local portal = TheSim:FindFirstEntityWithTag("multiplayer_portal")
    if portal then
        local x, _, z = portal.Transform:GetWorldPosition()
        point = Ground.FindLanding(inst, { x = x, z = z })
        if point then return point end
    end
    -- Last resort for heavily edited worlds: locate an actual clear land tile.
    local map = TheWorld.Map
    local w, h = map:GetSize()
    for tx = 1, w - 2 do
        for tz = 1, h - 2 do
            if map:IsTileLandNoDocks(map:GetTile(tx, tz)) then
                local x, _, z = map:GetTileCenterPoint(tx, tz)
                if Ground.CanLand(inst, x, z) then return { x = x, z = z } end
            end
        end
    end
end

return Ground
