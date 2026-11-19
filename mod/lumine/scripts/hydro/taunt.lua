local Rules = require("hydro/rules").bubble
local Targets = require("lumine_dendro_targets")

local function Restore(bubble, enemy, previous)
    local combat = enemy:IsValid() and enemy.components.combat
    if not combat or combat.target ~= bubble then return end
    if previous and previous:IsValid() and combat:CanTarget(previous) and combat:ShouldAggro(previous) then
        combat:SetTarget(previous)
    else
        combat:DropTarget()
    end
end

local M = {}

function M.Clear(bubble)
    local data = bubble.hydro
    for enemy, previous in pairs(data.taunted) do
        Restore(bubble, enemy, previous)
        data.taunted[enemy] = nil
    end
end

function M.Scan(bubble)
    local data = bubble.hydro
    local owner = data.caster.inst
    for enemy, previous in pairs(data.taunted) do
        if not Targets.IsWaveTarget(owner, enemy) or not enemy:IsNear(bubble, Rules.taunt_range) then
            Restore(bubble, enemy, previous)
            data.taunted[enemy] = nil
        end
    end
    local x, _, z = bubble.Transform:GetWorldPosition()
    for _, enemy in ipairs(Targets.Find(x, z, Rules.taunt_range)) do
        if Targets.IsWaveTarget(owner, enemy) and not enemy:HasTag("notaunt")
            and (enemy.components.locomotor or enemy:HasTag("lunarthrall_plant")) then
            local combat = enemy.components.combat
            local previous = combat.target
            if previous ~= bubble and (not previous or not previous:HasTag("lumine_hydro_bubble"))
                and combat:CanTarget(bubble) and combat:ShouldAggro(bubble) then
                if enemy:HasTag("epic") then
                    -- Bosses may accept a normal suggestion or retarget from attack events.
                    combat:SuggestTarget(bubble)
                else
                    combat:SetTarget(bubble)
                end
                if combat.target == bubble then data.taunted[enemy] = previous or false end
            end
        end
    end
end

return M
