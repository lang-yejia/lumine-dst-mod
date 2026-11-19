-- Only companion/weapon privileges survive the monkey curse, never Lumine's
-- gameplay tag or character components. This tag is replicated by the engine.
local M = { TAG = "lumine_traveler" }

function M.IsTraveler(owner)
    return owner ~= nil and (owner.prefab == "lumine"
        or owner:HasTag("lumine") or owner:HasTag(M.TAG))
end

local function PrepareLoad(inst, data)
    local swap = data and data.seamlessplayerswapper
    local main = swap and swap.main_data
    if inst.prefab == "lumine" or (inst.prefab == "wonkey" and main and main.prefab == "lumine") then
        inst:AddTag(M.TAG)
    else
        inst:RemoveTag(M.TAG)
    end
end

function M.Attach(inst)
    if inst.prefab == "lumine" then inst:AddTag(M.TAG) end
    if not TheWorld.ismastersim or inst._lumine_identity_installed then return end
    inst._lumine_identity_installed = true
    -- Normal saves/migration load components in unspecified order. Prime the
    -- identity before either inventory or petleash can reject restored items.
    local preload = inst.OnPreLoad
    inst.OnPreLoad = function(owner, data, ...)
        PrepareLoad(owner, data)
        if preload then return preload(owner, data, ...) end
    end
    -- Native LoadForReroll restores petleash BEFORE seamlessplayerswapper.
    -- Real portal rerolls omit main_data, so they cannot inherit this privilege.
    local load = inst.LoadForReroll
    inst.LoadForReroll = function(owner, data, ...)
        PrepareLoad(owner, data)
        if load then return load(owner, data, ...) end
    end
end

return M
