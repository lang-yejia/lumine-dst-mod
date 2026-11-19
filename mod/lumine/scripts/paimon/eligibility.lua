-- Server startup policy. Clients display the server-owned pet and guide RPCs;
-- they must not decide ownership from a local configuration override.
local M = {}
local Identity = require("compat/lumine_identity")
local all_characters = false

function M.Configure(scope)
    all_characters = scope == "all"
end

function M.Allows(owner)
    return owner ~= nil and (all_characters or Identity.IsTraveler(owner))
end

return M
