local M = {}
local OBSTACLES = {"wall", "structure", "tree", "boulder"}

function M.CanTravel(x, z, radius, collide_structures)
    local map = TheWorld.Map
    if not map:IsValidTileAtPoint(x, 0, z) or map:IsGroundTargetBlocked(Vector3(x, 0, z), radius) then
        return false
    end
    for _, obstacle in ipairs(TheSim:FindEntities(x, 0, z, MAX_PHYSICS_RADIUS + radius, nil, {"INLIMBO"}, OBSTACLES)) do
        if obstacle.Physics and obstacle.Physics:IsActive()
            and (obstacle:HasTag("wall") or not obstacle.components.combat
                or collide_structures and obstacle:HasTag("structure")) then
            local reach = radius + obstacle:GetPhysicsRadius(0)
            if obstacle:GetDistanceSqToPoint(x, 0, z) < reach * reach then return false end
        end
    end
    return true
end

function M.SafeStep(x, z, dx, dz, distance, radius, collide_structures)
    local samples = math.max(1, math.ceil(distance / .24))
    for i = 1, samples do
        local step = distance * i / samples
        if not M.CanTravel(x + dx * step, z + dz * step, radius, collide_structures) then
            return distance * (i - 1) / samples
        end
    end
    return distance
end

return M
