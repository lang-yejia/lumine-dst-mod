local Rules = require("pyro/rules")
local Attacks = require("pyro/attacks")
local Scorch = require("pyro/scorch")
local Cast = require("flight/lumine_pyro_cast")
local ResolveDirection = require("flight/lumine_wind_aim")
local BURST_MOD = "lumine_pyro_burst"

local function ClearFX(fx)
    if fx and fx:IsValid() then fx:Remove() end
end

local Pyro = Class(function(self, inst)
    self.inst = inst
    self.ring_ready, self.fire_ready, self.streak = 0, 0, 0
    self.orbs = {}
    self.listeners = {
        lumine_element_resonated = function() self:RefreshResonance() end,
        lumine_energy_changed = function() self:CheckEnergy() end,
        death = function() self:ClearCombat() end,
        ms_becameghost = function() self:ClearCombat() end,
        onremove = function() self:ClearCombat() end,
        attacked = function(_, data)
            if self.burst and data and (data.damageresolved or 0) > 0 then
                self:EndBurst(true)
            end
        end,
        newstate = function()
            if (self.burst or self.ring or next(self.orbs)) and not self:CanMaintain() then self:ClearCombat() end
        end,
    }
    for name, callback in pairs(self.listeners) do inst:ListenForEvent(name, callback) end

    local sanity = inst.components.sanity
    self.base_sanity_delta = sanity.DoDelta
    self.sanity_delta = function(component, delta, overtime, ...)
        if self.burst and overtime and delta < 0 then delta = delta * Rules.drain_multiplier end
        return self.base_sanity_delta(component, delta, overtime, ...)
    end
    sanity.DoDelta = self.sanity_delta

    local combat = inst.components.combat
    self.base_normal_multiplier = combat.customdamagemultfn
    self.normal_multiplier = function(owner, target, ...)
        local previous = self.base_normal_multiplier and self.base_normal_multiplier(owner, target, ...) or 1
        return previous * self:GetDamageMultiplier(target)
    end
    combat.customdamagemultfn = self.normal_multiplier
    self.base_special_multiplier = combat.customspdamagemultfn
    self.special_multiplier = function(owner, target, ...)
        local previous = self.base_special_multiplier and self.base_special_multiplier(owner, target, ...) or 1
        return previous * self:GetDamageMultiplier(target)
    end
    combat.customspdamagemultfn = self.special_multiplier
    self:RefreshResonance()
end)

function Pyro:IsResonating()
    local journey = self.inst.components.luminejourney
    return journey ~= nil and journey.active_element == "pyro" and journey:CanResonate("pyro")
end

function Pyro:CanMaintain()
    local inst = self.inst
    return inst:IsValid() and self:IsResonating() and not inst.components.health:IsDead()
        and not inst:HasAnyTag("playerghost", "lumine_gliding")
        and not (inst.sg and inst.sg:HasAnyStateTag("dead", "sleeping", "bedroll", "tent",
            "devoured", "suspended", "frozen", "flight", "drowning", "knockback", "stunned"))
end

function Pyro:CanCast()
    local sg = self.inst.sg
    return self:CanMaintain() and sg ~= nil and not sg:HasStateTag("busy")
end

function Pyro:RefreshResonance()
    if not self:IsResonating() then self:ClearCombat() end
end

function Pyro:GetDamageMultiplier(target)
    if not self:IsResonating() then return 1 end
    return Scorch.IsActive(target) and Rules.scorched_multiplier or Rules.damage_multiplier
end

function Pyro:CastRing()
    if not self:CanCast() then return false, "现在无法释放流火之刃" end
    local now = GetTime()
    if now < self.ring_ready then return false, "流火之刃正在冷却" end
    local energy = self.inst.components.lumineenergy
    if not energy:CanSpendAmount(Rules.ring.cost) then return false, "元素力不足" end

    local ring = SpawnPrefab("lumine_pyro_ring_fx")
    if not ring then return false end
    energy:SpendAmount(Rules.ring.cost)
    self.ring_ready = now + Rules.ring.cooldown
    self.inst._lumine_pyro_ring_ready:set(self.ring_ready)
    ClearFX(self.ring)
    self.ring = ring
    self.inst:ListenForEvent("onremove", function()
        if self.ring == ring then self.ring = nil end
    end, ring)
    Attacks.StartRing(self.inst, ring)
    return true
end

function Pyro:ToggleBurst()
    if self.burst then self:EndBurst(true) return true end
    if not self:CanCast() then return false, "现在无法开启爆炎状态" end
    local inst = self.inst
    if not inst.components.lumineenergy:CanSpendAmount(Rules.orb.cost) then return false, "元素力不足" end
    local fx = SpawnPrefab("lumine_pyro_burst_fx")
    if not fx then return false end

    inst:AddChild(fx)
    self.burst, self.burst_fx = true, fx
    inst.components.hunger.burnratemodifiers:SetModifier(inst, Rules.drain_multiplier, BURST_MOD)
    inst._lumine_pyro_burst:set(true)
    inst.sg:GoToState(Cast.ENTER)
    return true
end

function Pyro:EndHold(animate)
    if self.hold_task then self.hold_task:Cancel() self.hold_task = nil end
    self.hold_input, self.hold_until, self.streak = nil, nil, 0
    self.aim_x, self.aim_z = nil, nil
    self.inst._lumine_pyro_streak:set(0)
    local sg = self.inst.sg
    if animate and sg and sg:HasStateTag("lumine_pyro_shot") then
        sg:GoToState(Cast.RELEASE, true)
    end
end

function Pyro:EndBurst(animate)
    local inst = self.inst
    if not self.burst then self:EndHold(false) return end
    self.burst = false
    self:EndHold(animate)
    ClearFX(self.burst_fx)
    self.burst_fx = nil
    inst.components.hunger.burnratemodifiers:RemoveModifier(inst, BURST_MOD)
    inst._lumine_pyro_burst:set(false)
    if animate and (self:CanCast() or self:CanMaintain() and inst.sg
        and inst.sg.currentstate.name == Cast.ENTER) then
        inst.sg:GoToState(Cast.RELEASE)
    end
end

function Pyro:CheckEnergy()
    if self.burst and not self.firing and not self.inst.components.lumineenergy:CanSpendAmount(Rules.orb.cost) then
        self:EndBurst(true)
    end
end

function Pyro:FireOrb()
    local inst = self.inst
    local energy = inst.components.lumineenergy
    if not energy:CanSpendAmount(Rules.orb.cost) then
        self:EndBurst(true)
        return false, "元素力不足"
    end
    local orb = SpawnPrefab("lumine_pyro_fireball")
    if not orb then return false end

    self.streak = math.min(5, self.streak + 1)
    self.fire_ready = GetTime() + Rules.OrbInterval(1)
    self.firing = true
    energy:SpendAmount(Rules.orb.cost)
    self.firing = false
    self.orbs[orb] = true
    inst:ListenForEvent("onremove", function() self.orbs[orb] = nil end, orb)
    local x, _, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, inst.Transform:GetRotation(), self.aim_x, self.aim_z)
    local rotation = math.atan2(-dz, dx) / DEGREES
    inst.Transform:SetRotation(rotation)
    Cast.PlayShot(inst)
    Attacks.LaunchOrb(inst, orb, Rules.OrbDamage(self.streak), dx, dz, rotation)
    inst._lumine_pyro_streak:set(self.streak)
    self:CheckEnergy()
    return true
end

function Pyro:ScheduleShot()
    self.hold_task = self.inst:DoTaskInTime(Rules.OrbInterval(self.streak), function()
        self.hold_task = nil
        if not self:CanMaintain() then
            self:ClearCombat()
        elseif GetTime() >= self.hold_until or not self.inst.sg:HasStateTag("lumine_pyro_shot") then
            self:EndHold(true)
        elseif not self:FireOrb() then
            self:EndHold(true)
        elseif self.hold_input then
            self:ScheduleShot()
        end
    end)
end

function Pyro:Press(input, aim_x, aim_z)
    if not self.burst then return self:CastRing() end
    if self.hold_input or GetTime() < self.fire_ready then return false end
    if not self:CanCast() then return false, "现在无法发射火焰球" end
    local inst = self.inst
    inst.sg:GoToState(Cast.CHANNEL)
    self.aim_x, self.aim_z = aim_x, aim_z
    local ok, reason = self:FireOrb()
    if ok and self.burst and input ~= nil then
        self.hold_input = input
        self.hold_until = GetTime() + Rules.hold_timeout
        self:ScheduleShot()
    else
        self:EndHold(true)
    end
    return ok, reason
end

function Pyro:RenewHold(input, aim_x, aim_z)
    local now = GetTime()
    if self.hold_input and self.hold_input == input and now < self.hold_until then
        self.hold_until = now + Rules.hold_timeout
        self.aim_x, self.aim_z = aim_x, aim_z
    end
end

function Pyro:Release(input)
    if self.hold_input == input then self:EndHold(true) end
end

function Pyro:ClearCombat()
    local inst = self.inst
    self:EndBurst(inst:IsValid() and inst.sg and inst.sg:HasStateTag("lumine_pyro_shot"))
    ClearFX(self.ring)
    self.ring = nil
    for orb in pairs(self.orbs) do ClearFX(orb) end
end

function Pyro:ResetCooldowns()
    self.ring_ready = 0
    self.inst._lumine_pyro_ring_ready:set(0)
end

function Pyro:OnSave()
    return {ring_remaining = math.max(0, self.ring_ready - GetTime())}
end

function Pyro:OnLoad(data)
    self:ClearCombat()
    local remaining = math.min(Rules.ring.cooldown, math.max(0, tonumber(data.ring_remaining) or 0))
    self.ring_ready = remaining > 0 and GetTime() + remaining or 0
    self.inst._lumine_pyro_ring_ready:set(self.ring_ready)
end

function Pyro:OnRemoveFromEntity()
    self:ClearCombat()
    local inst = self.inst
    for name, callback in pairs(self.listeners) do inst:RemoveEventCallback(name, callback) end
    local combat = inst.components.combat
    if combat.customdamagemultfn == self.normal_multiplier then
        combat.customdamagemultfn = self.base_normal_multiplier
    end
    if combat.customspdamagemultfn == self.special_multiplier then
        combat.customspdamagemultfn = self.base_special_multiplier
    end
    local sanity = inst.components.sanity
    if sanity.DoDelta == self.sanity_delta then sanity.DoDelta = self.base_sanity_delta end
end

return Pyro
