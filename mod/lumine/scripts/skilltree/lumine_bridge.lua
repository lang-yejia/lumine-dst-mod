local Nodes = require("skilltree/lumine_nodes")
local State = require("skilltree/lumine_state")
local M = {}

function M.AttachReroll(inst)
    local save, load = inst.SaveForReroll, inst.LoadForReroll
    if save == nil or load == nil then return end
    inst.SaveForReroll = function(owner, ...)
        local data = save(owner, ...)
        local tree = owner.components.lumineskilltree
        local carry = owner.components.lumineskilltreecarry
        local record = carry and carry.record
        if tree then
            tree:Initialize()
            record = {tree = tree:OnSave(), journey = owner.components.luminejourney:OnSave()}
        end
        if record then
            data = data or {}
            data.lumine_skilltree = record
        end
        return data
    end
    inst.LoadForReroll = function(owner, data, ...)
        load(owner, data, ...)
        local record = data and data.lumine_skilltree
        if not record then return end
        local tree = owner.components.lumineskilltree
        if tree then
            tree:RestoreForReroll(record)
        else
            local carry = owner.components.lumineskilltreecarry or owner:AddComponent("lumineskilltreecarry")
            carry.record = record
        end
    end
end

function M.Attach(inst)
    local updater = inst.components.skilltreeupdater
    local mirror = State.New()
    local last_encoded
    local function GetData()
        local tree = inst.components.lumineskilltree
        if tree then return tree.data end
        local encoded = inst._lumine_skilltree:value()
        if last_encoded ~= encoded then
            State.Decode(mirror, encoded)
            last_encoded = encoded
        end
        return mirror
    end

    function updater:IsActivated(id) return GetData():IsActivated(id, Nodes.character) end
    function updater:GetActivatedSkills() return GetData():GetActivatedSkills(Nodes.character) end
    function updater:GetAvailableSkillPoints() return GetData():GetAvailableSkillPoints(Nodes.character) end
    function updater:GetSkillXP() return GetData():GetSkillXP(Nodes.character) end
    function updater:GetPlayerSkillSelection() return GetData():GetPlayerSkillSelection(Nodes.character) end

    -- Original wire handlers can still address Lumine, but cannot write this
    -- character's authoritative state or persist it into the account profile.
    local function Ignore() end
    updater.ActivateSkill = Ignore
    updater.DeactivateSkill = Ignore
    updater.SetPlayerSkillSelection = Ignore
    updater.OnSave = Ignore
    updater.OnLoad = Ignore
    updater.TransferComponent = Ignore
    updater.AddSkillXP = Ignore
    function updater:SendFromSkillTreeBlob()
        local tree = inst.components.lumineskilltree
        if tree ~= nil and not tree.ready and tree:Initialize() then return end
        inst:PushEvent("onsetskillselection_server")
    end

    inst:ListenForEvent("lumine_skilltree_dirty", function()
        inst:PushEvent("unlockrecipe")
    end)
end

return M
