local Cast = require("flight/lumine_electro_cast")
local FireOrb = require("lumine_electro_orb")
local FX = require("lumine_electro_fx")
local Rules = require("lumine_energy_rules").ELECTRO
local DRAIN = Rules.INFUSION_DRAIN_PER_SECOND * Rules.INFUSION_INTERVAL

local function IsEnemy(inst, target)
    if not target or target == inst or not target:IsValid() or target:HasAnyTag("INLIMBO", "wall", "structure") then
        return false
    end
    local components = target.components
    return components.health ~= nil and components.combat ~= nil
        and (not components.follower or components.follower.leader ~= inst)
        and not inst.components.combat:IsAlly(target)
end

local function EndAttack(self, previous, ...)
    self.attack = previous
    return ...
end

local Electro = Class(function(self, inst)
    self.inst = inst
    self.combat_until, self.burst_ready, self.burst_until = 0, 0, 0
    self.infused = false
    self.spent_projectiles = setmetatable({}, {__mode = "k"})
    self.listeners = {
        onhitother = function(_, data) self:OnHit(data) end,
        attacked = function(_, data)
            if data and (data.damageresolved or 0) > 0 and IsEnemy(inst, data.attacker) then
                self:MarkCombat()
            end
        end,
        lumine_element_resonated = function()
            self.combat_until = 0
            if not self:CanMaintain() then self:StopInfusion() end
        end,
        newstate = function()
            if self.infused and not self:CanMaintain() then self:StopInfusion() end
        end,
        death = function()
            self.combat_until = 0
            self:StopInfusion()
        end,
        lumine_energy_depleted = function() self:StopInfusion() end,
        ms_playerdespawnanddelete = function() self:StopInfusion() end,
    }
    for name, callback in pairs(self.listeners) do inst:ListenForEvent(name, callback) end

    local combat = inst.components.combat
    local original = combat.DoAttack
    self.base_attack = original
    self.electro_attack = function(component, target, weapon, projectile, stimuli, ...)
        if not self.infused or not self:CanMaintain() then
            return original(component, target, weapon, projectile, stimuli, ...)
        end
        local held = weapon or component:GetWeapon()
        local weapon_component = held and held.components.weapon
        if not weapon_component then
            return original(component, target, weapon, projectile, stimuli, ...)
        end

        local previous = self.attack
        local attack = {projectile = projectile}
        self.attack = attack
        -- Same electric stimulus as the food buff uses. Keep weapon-specific stimuli and existing buffs.
        if stimuli == nil and inst.components.electricattacks == nil and weapon_component.stimuli ~= "electric" then
            local override = weapon_component.overridestimulifn
            stimuli = override and override(held, inst, target or component.target) or nil
            if stimuli == nil then
                stimuli, attack.infused = "electric", true
            end
        end
        return EndAttack(self, previous, original(component, target, weapon, projectile, stimuli, ...))
    end
    combat.DoAttack = self.electro_attack
end)

function Electro:CanMaintain()
    local inst = self.inst
    local journey, health = inst.components.luminejourney, inst.components.health
    return journey ~= nil and journey.active_element == "electro" and journey:CanResonate("electro")
        and health ~= nil and not health:IsDead() and not inst:HasAnyTag("playerghost", "lumine_gliding")
        and not (inst.sg and inst.sg:HasAnyStateTag("dead", "sleeping", "bedroll", "tent",
            "devoured", "suspended", "frozen", "flight", "drowning"))
end

function Electro:MarkCombat()
    if self:CanMaintain() then self.combat_until = GetTime() + Rules.COMBAT_DURATION end
end

function Electro:GetRegenMultiplier()
    return GetTime() < self.combat_until and self:CanMaintain() and Rules.COMBAT_REGEN_MULTIPLIER or 1
end

function Electro:EndBurst()
    if self.burst_task then self.burst_task:Cancel() self.burst_task = nil end
    self.burst_until = 0
    self.inst._lumine_electro_burst:set(0)
end

function Electro:StopInfusion()
    if not self.infused then return end
    self.infused = false
    if self.drain_task then self.drain_task:Cancel() self.drain_task = nil end
    if self.deadline_task then self.deadline_task:Cancel() self.deadline_task = nil end
    self.inst._lumine_electro_infused:set(false)
    self:EndBurst()
end

function Electro:ToggleInfusion()
    if self.infused then self:StopInfusion() return true end
    local inst = self.inst
    if not self:CanMaintain() or (inst.sg and inst.sg:HasStateTag("busy")) then
        return false, "现在无法开启雷元素附魔"
    end
    local energy = inst.components.lumineenergy
    if not energy or energy.current <= DRAIN then return false, "元素力不足" end
    energy:SpendAmount(DRAIN)
    self.infused = true
    inst._lumine_electro_infused:set(true)
    self.deadline_task = inst:DoTaskInTime(Rules.INFUSION_MAX_DURATION, function()
        self.deadline_task = nil
        self:StopInfusion()
    end)
    self.drain_task = inst:DoPeriodicTask(Rules.INFUSION_INTERVAL, function()
        if self:CanMaintain() then energy:Add(-DRAIN) else self:StopInfusion() end
    end)
    return true
end

function Electro:CastBurst()
    local inst = self.inst
    if not self.infused then return false, "请先开启雷元素附魔" end
    if not self:CanMaintain() or not inst.sg or inst.sg:HasStateTag("busy") or not inst.sg:HasState(Cast.STATE) then
        return false, "现在无法释放雷霆唤星"
    end
    if self.burst_ready > GetTime() then return false, "雷霆唤星正在冷却" end
    if not inst.components.lumineenergy:CanSpendAmount(Rules.ORB_COST) then return false, "元素力不足" end
    inst.sg:GoToState(Cast.STATE)
    return true
end

function Electro:ActivateBurst()
    if not self.infused or not self:CanMaintain() then return false end
    local now = GetTime()
    if self.burst_ready > now or not self.inst.components.lumineenergy:CanSpendAmount(Rules.ORB_COST) then return false end
    self:EndBurst()
    self.burst_until, self.burst_ready = now + Rules.BURST_DURATION, now + Rules.BURST_COOLDOWN
    self.inst._lumine_electro_burst:set(self.burst_until)
    self.inst._lumine_electro_ready:set(self.burst_ready)
    self.burst_task = self.inst:DoTaskInTime(Rules.BURST_DURATION, function()
        self.burst_task = nil
        self:EndBurst()
    end)
    return true
end

function Electro:OnHit(data)
    if not data or (data.damageresolved or 0) <= 0 or not IsEnemy(self.inst, data.target) then return end
    self:MarkCombat()
    local attack = self.attack
    if not attack or not data.from_doattack or not self.infused then return end
    if attack.infused and data.stimuli == "electric" then
        local source = attack.projectile
        FX.WeaponHit(source and source:IsValid() and source or self.inst, data.target)
    end
    if attack.emitted or GetTime() >= self.burst_until or not self:CanMaintain() then return end
    local projectile = attack.projectile
    if projectile and self.spent_projectiles[projectile] then return end
    attack.emitted = true
    local energy = self.inst.components.lumineenergy
    if not energy:CanSpendAmount(Rules.ORB_COST) then return end
    if FireOrb(self.inst, data.target, energy, Rules.ORB_COST) and projectile then
        self.spent_projectiles[projectile] = true
    end
end

function Electro:ResetCooldowns()
    self.burst_ready = 0
    self.inst._lumine_electro_ready:set(0)
end

function Electro:OnSave()
    return {burst_remaining = math.max(0, self.burst_ready - GetTime())}
end

function Electro:OnLoad(data)
    self:StopInfusion()
    self.combat_until = 0
    local remaining = math.min(Rules.BURST_COOLDOWN, math.max(0, tonumber(data.burst_remaining) or 0))
    self.burst_ready = remaining > 0 and GetTime() + remaining or 0
    self.inst._lumine_electro_ready:set(self.burst_ready)
end

function Electro:OnRemoveFromEntity()
    self:StopInfusion()
    for name, callback in pairs(self.listeners) do self.inst:RemoveEventCallback(name, callback) end
    local combat = self.inst.components.combat
    if combat and combat.DoAttack == self.electro_attack then combat.DoAttack = self.base_attack end
end

return Electro
