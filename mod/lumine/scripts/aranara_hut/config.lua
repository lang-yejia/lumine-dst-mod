local M = {
    SLOTS = 3,
    WORKERS = 3,
    RADIUS = 8.5, -- Search reaches the corners of a three-by-three turf square.
    HALF_WIDTH = 6,
    FUEL_TIME_MULTIPLIER = 2,
    TICK = 1,
}

function M.IsFuel(item)
    return item ~= nil and item:HasTag(FUELTYPE.BURNABLE .. "_fuel")
        and (item.components.fuel == nil or item.components.fuel.fuelvalue > 0)
end

function M.Contains(home, target)
    if home == nil or target == nil or not target:IsValid() then return false end
    local hx, _, hz = home.Transform:GetWorldPosition()
    local tx, _, tz = target.Transform:GetWorldPosition()
    return math.abs(tx - hx) <= M.HALF_WIDTH and math.abs(tz - hz) <= M.HALF_WIDTH
end

return M
