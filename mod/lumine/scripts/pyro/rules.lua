local M = {
    damage_multiplier = 1.1,
    scorched_multiplier = 1.25,
    drain_multiplier = 1.5,
    ring = {radius = 1.5, visual_scale = .83, duration = 6, interval = 1.5, damage = 20, cooldown = 11, cost = 18},
    scorch = {duration = 4, interval = 1, damage = 4},
    orb = {
        radius = 2.5, range = 10, speed = 15, contact = .46, intervals = {.5, .42, .34, .28, .23}, cost = 7,
        visual_scale = 1.5, launch_offset = .62, launch_height = 1.28, cruise_height = .9,
    },
    hold_timeout = .9,
    hold_heartbeat = .12,
}

function M.OrbDamage(shot)
    return 35 + 10 * (math.min(5, shot) - 1)
end

function M.OrbInterval(shot)
    return M.orb.intervals[math.min(#M.orb.intervals, shot)]
end

return M
