local M = {}

-- The first five points cost 23 of the 40 currently obtainable observations.
-- Price follows the number of exchanges, including after a skill reset.
function M.Cost(exchange_number)
    local prior = exchange_number - 1
    return 2 + prior + math.floor(prior * prior / 8)
end

function M.Encode(available, count, cost)
    return string.format("%d:%d:%d", available, count, cost or 0)
end

function M.Decode(snapshot)
    local available, count, cost = snapshot:match("^(%d+):(%d+):(%d+)$")
    return tonumber(available), tonumber(count), tonumber(cost)
end

return M
