local Elements = require("lumine_statue_elements")
local STAT_BONUS = Elements.bonus

local Bonus = Class(function(self, inst)
    self.inst = inst
    self.count = 0
    local health = inst.components.health
    local save_health = health.OnSave
    if save_health then
        function health:OnSave(...)
            local data, refs = save_health(self, ...)
            if data and data.maxhealth then
                data.maxhealth = data.maxhealth - inst.components.luminestatuebonus.count * STAT_BONUS.health
            end
            return data, refs
        end
    end
    local function Track()
        local index = TheWorld.components.luminestatueindex
        if index then index:Track(inst) end
    end
    inst:ListenForEvent("ms_respawnedfromghost", Track)
    inst:ListenForEvent("ms_playerjoined", function(_, player) if player == inst then Track() end end, TheWorld)
    inst:DoTaskInTime(0, Track)
end)

local function Percent(current, maximum)
    return math.max(0, math.min(1, current / math.max(1, maximum)))
end

function Bonus:Ratios()
    local c = self.inst.components
    return {health = Percent(c.health.currenthealth, c.health:GetMaxWithPenalty()),
        sanity = Percent(c.sanity.current, c.sanity:GetMaxWithPenalty()),
        hunger = c.hunger:GetPercent()}
end

function Bonus:Apply(mask)
    local count = Elements.Count(mask)
    local delta = count - self.count
    if delta == 0 and not self.loaded_ratios then return end
    local c = self.inst.components
    local ratios = self.loaded_ratios or self:Ratios()
    self.loaded_ratios, self.count = nil, count
    local dead = c.health:IsDead() or self.inst:HasTag("playerghost")
    -- Native max-field setters replicate without filling the stat to its cap.
    c.health.maxhealth = c.health.maxhealth + delta * STAT_BONUS.health
    if not dead then
        c.health:SetVal(c.health:GetMaxWithPenalty() * ratios.health, "lumine_statue_bonus")
        c.health:ForceUpdateHUD(true)
    end
    c.sanity.max = c.sanity.max + delta * STAT_BONUS.sanity
    c.sanity:SetCurrent(c.sanity:GetMaxWithPenalty() * ratios.sanity)
    c.hunger.max = c.hunger.max + delta * STAT_BONUS.hunger
    c.hunger:SetPercent(ratios.hunger, true)
end

function Bonus:OnSave()
    if self.count > 0 or self.loaded_ratios then return {ratios = self.loaded_ratios or self:Ratios()} end
end

function Bonus:OnLoad(data)
    self.loaded_ratios = data.ratios
end

return Bonus
