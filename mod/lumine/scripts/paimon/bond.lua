-- 使用原版 petleash 的独立 prefab 配额，继承存档、跨分片、回滚和重选人物流程。
-- 派蒙没有 follower 组件，既不加入 leader.followers，也不占普通宠物名额。
local C = require("paimon/config")
local Eligibility = require("paimon/eligibility")
local Identity = require("compat/lumine_identity")
local M = {}
function M.AttachPlayer(inst)
    if not TheWorld.ismastersim or inst._paimon_bond_installed then return end
    local leash = inst.components.petleash
    if not leash then return end
    inst._paimon_bond_installed = true
    leash:SetMaxPetsForPrefab("lumine_paimon", 1)
    local oldspawn, olddespawn = leash.onspawnfn, leash.ondespawnfn
    leash:SetOnSpawnFn(function(owner, pet)
        if pet.prefab ~= "lumine_paimon" then
            if oldspawn then oldspawn(owner, pet) end
            return
        end
        if Eligibility.Allows(owner) then
            pet:BindTo(owner)
        else
            -- 换人或关闭全角色配置后读档：只归还一次，不封存物资。
            pet:DoTaskInTime(0, function()
                if not owner:IsValid() then return end
                pet.Transform:SetPosition(owner.Transform:GetWorldPosition())
                pet.components.container:DropEverything()
                pet:Remove()
            end)
        end
    end)
    leash:SetOnDespawnFn(function(owner, pet)
        if pet.prefab == "lumine_paimon" then pet:Remove()
        elseif olddespawn then olddespawn(owner, pet)
        else pet:Remove() end
    end)
    -- Wonkey's original identity is not known until load. Install cleanup for
    -- every player and decide from the actual pet when the player departs.
    local ondespawn = inst.OnDespawn
    inst.OnDespawn = function(owner, migrationdata, ...)
        local pet = owner._paimon
        if pet and pet:IsValid() then
            local container = pet.components.container
            container:Close()
            local pos = owner:GetPosition()
            if migrationdata == nil and (GetGameModeProperty("drop_everything_on_despawn")
                or TUNING.DROP_EVERYTHING_ON_DESPAWN) then
                container:DropEverything(pos)
            else
                container:DropEverythingWithTag("irreplaceable", pos)
            end
        end
        if ondespawn then return ondespawn(owner, migrationdata, ...) end
    end
    -- Run eligibility after preload/reroll has established the original identity.
    inst:DoTaskInTime(0, function()
        if Eligibility.Allows(inst) and leash:GetNumPetsForPrefab("lumine_paimon") == 0 then
            local x, y, z = inst.Transform:GetWorldPosition()
            leash:SpawnPetAt(x + C.SPAWN_OFFSET, y, z, "lumine_paimon")
        end
    end)
    inst:ListenForEvent("ms_playerseamlessswaped", function()
        if inst.prefab ~= "wonkey" or not Identity.IsTraveler(inst) then return end
        local pet = inst._paimon
        if not pet or not pet:IsValid() then return end
        -- Let the transformation animation and the previous sentence finish.
        -- This event is not fired by saves or shard migration.
        pet:DoTaskInTime(1, function()
            if inst:IsValid() and pet.owner == inst then
                local dialogue = pet.dialogue
                -- Queue before the next speech slot, so ordinary chatter cannot
                -- take that slot first and let this one-off reaction expire.
                local lifetime = math.max(8, dialogue.nextspeech - GetTime() + 8,
                    dialogue.speaking_until - GetTime() + 8)
                dialogue:Offer("monkey_transform", lifetime)
            end
        end)
    end)
end
return M
