return function(x, z, rotation, aim_x, aim_z)
    if type(aim_x) == "number" and type(aim_z) == "number"
        and math.abs(aim_x) < math.huge and math.abs(aim_z) < math.huge then
        local dx, dz = aim_x - x, aim_z - z
        local length = math.sqrt(dx * dx + dz * dz)
        if length > .1 and length < math.huge then return dx / length, dz / length end
    end
    local angle = rotation * DEGREES
    return math.cos(angle), -math.sin(angle)
end
