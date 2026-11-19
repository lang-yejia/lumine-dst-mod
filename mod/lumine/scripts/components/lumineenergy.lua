local Rules = require("lumine_energy_rules")
local MAX = Rules.MAX_ENERGY
local COST = Rules.SKILL_COST

local LumineEnergy = Class(function(self, inst)
    self.inst = inst
    self.current = 0
    self.last_drop = setmetatable({}, {__mode="k"})
    inst._lumine_energy:set(0)
    inst:DoPeriodicTask(1, function() self:Regenerate() end)
    inst:ListenForEvent("onattackother", function(_, data) self:OnAttack(data) end)
end)

function LumineEnergy:Add(amount)
    local previous = self.current
    self.current = math.max(0, math.min(MAX, previous + amount))
    self.inst._lumine_energy:set(self.current)
    if previous > 0 and self.current == 0 then self.inst:PushEvent("lumine_energy_depleted") end
    if previous ~= self.current then self.inst:PushEvent("lumine_energy_changed") end
end

function LumineEnergy:Regenerate()
    local inst = self.inst
    if inst:HasTag("playerghost") or inst:HasTag("lumine_gliding") then return end
    local artifacts, electro = inst.components.lumineartifacts, inst.components.lumineelectro
    local relic_bonus = artifacts and artifacts:HasActivePiece(4) and Rules.RELIC_REGEN_PER_SECOND or 0
    local multiplier = electro and electro:GetRegenMultiplier() or 1
    self:Add(Rules.REGEN_PER_SECOND * multiplier + relic_bonus)
end

function LumineEnergy:Refill()
    self:Add(MAX - self.current)
end

function LumineEnergy:CanSpend(skill)
    local cost = COST[skill] or 0
    return self:CanSpendAmount(cost), cost
end

function LumineEnergy:CanSpendAmount(amount)
    return self.current + .0001 >= amount
end

function LumineEnergy:SpendAmount(amount)
    if not self:CanSpendAmount(amount) then return false end
    self:Add(-amount)
    return true
end

function LumineEnergy:Spend(skill)
    return self:SpendAmount(COST[skill] or 0)
end

function LumineEnergy:OnAttack(data)
    local target = data and data.target
    if target == nil or not target:IsValid() or target.components.health == nil
        or target:HasTag("player") or target:HasTag("wall") then return end
    local boss = target:HasTag("epic")
    local now = GetTime()
    local interval = boss and 8 or 3
    if now - (self.last_drop[target] or -100) < interval then return end
    self.last_drop[target] = now
    if math.random() >= (boss and .22 or .20) then return end
    local item = SpawnPrefab(boss and "lumine_element_orb" or "lumine_element_particle")
    if item ~= nil then
        local x, y, z = target.Transform:GetWorldPosition()
        local angle = math.random() * 2 * PI
        item.Transform:SetPosition(x + math.cos(angle)*.6, y, z + math.sin(angle)*.6)
    end
end

function LumineEnergy:OnSave() return {current=self.current} end
function LumineEnergy:OnLoad(data)
    if data ~= nil then self:Add(tonumber(data.current) or 0) end
end

return LumineEnergy
