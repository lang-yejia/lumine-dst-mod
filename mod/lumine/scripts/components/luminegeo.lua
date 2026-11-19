local SHIELD_DURATION = 6
local SHIELD_COOLDOWN = 35
local SHIELD_CAPACITY = 100
local FIELD_COOLDOWN = 50

local LumineGeo = Class(function(self, inst)
    self.inst = inst
    self.shield_ready = 0
    self.field_ready = 0
    self.shield_task = nil
    self.shield_fx = nil
    self.shield_remaining = 0
    inst._lumine_geo_shield_left:set(0)
    -- Combat combines regular and planar damage before calling Health:DoDelta.
    -- Intercept this player's post-armour damage so both types share one pool.
    local health = inst.components.health
    local original_delta = health.DoDelta
    self.original_do_delta = original_delta
    self.shield_do_delta = function(h, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        if self.shield_remaining > 0 and afflicter ~= nil and type(amount) == "number" and amount < 0
            and not ignore_absorb and (ignore_invincible or not h:IsInvincible()) then
            local absorbed = math.min(-amount, self.shield_remaining)
            self.shield_remaining = self.shield_remaining - absorbed
            inst._lumine_geo_shield_left:set(self.shield_remaining)
            amount = amount + absorbed
            if self.shield_remaining <= 0 then self:EndShield() end
            if amount == 0 then return 0 end
        end
        return original_delta(h, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
    health.DoDelta = self.shield_do_delta
    inst:ListenForEvent("death", function() self:EndShield() end)
    inst:DoTaskInTime(0, function() if inst:IsValid() then self:Sync() end end)
end)

function LumineGeo:Sync()
    local journey = self.inst.components.luminejourney
    local active = journey ~= nil and journey.active_element == "geo"
    self.inst._lumine_geo_skills:set(active and 3 or 0)
    self.inst._lumine_geo_shield_ready:set(self.shield_ready)
    self.inst._lumine_geo_field_ready:set(self.field_ready)
end

function LumineGeo:ResetCooldowns()
    self.shield_ready, self.field_ready = 0, 0
    self:Sync()
end

function LumineGeo:CanCast(id)
    local inst = self.inst
    local journey = inst.components.luminejourney
    if journey == nil or journey.active_element ~= "geo" or not journey:CanResonate("geo") then
        return false, "请先在七天神像与岩元素共鸣"
    end
    if inst:HasTag("playerghost") or inst.components.health == nil or inst.components.health:IsDead() then
        return false, "现在无法施放技能"
    end
    if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
        return false, "骑乘时无法施放岩元素技能"
    end
    if inst.sg ~= nil and (inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("sleeping")) then
        return false, "现在无法施放技能"
    end
    local ready = id == "geo_shield" and self.shield_ready or self.field_ready
    if ready > GetTime() then return false, "技能冷却中：" .. math.ceil(ready - GetTime()) .. " 秒" end
    local energy = inst.components.lumineenergy
    if energy ~= nil and not energy:CanSpend(id) then return false, "元素力不足" end
    return true
end

function LumineGeo:EndShield()
    self.shield_remaining = 0
    self.inst._lumine_geo_shield_left:set(0)
    if self.shield_task ~= nil then self.shield_task:Cancel() self.shield_task = nil end
    if self.shield_fx ~= nil and self.shield_fx:IsValid() then self.shield_fx:kill_fx() end
    self.shield_fx = nil
end

function LumineGeo:CastShield()
    local ok, reason = self:CanCast("geo_shield")
    if not ok then return false, reason end
    self.inst.components.lumineenergy:Spend("geo_shield")
    self:EndShield()
    self.shield_remaining = SHIELD_CAPACITY
    self.inst._lumine_geo_shield_left:set(self.shield_remaining)
    self.shield_fx = SpawnPrefab("forcefieldfx")
    if self.shield_fx ~= nil then
        self.shield_fx.entity:SetParent(self.inst.entity)
        self.shield_fx.AnimState:SetMultColour(1, 0.72, 0.25, 0.85)
        self.shield_fx.Light:SetColour(1, 0.66, 0.18)
    end
    self.shield_task = self.inst:DoTaskInTime(SHIELD_DURATION, function() self:EndShield() end)
    self.shield_ready = GetTime() + SHIELD_COOLDOWN
    self:Sync()
    return true
end

function LumineGeo:CastField()
    local ok, reason = self:CanCast("geo_field")
    if not ok then return false, reason end
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local field = SpawnPrefab("lumine_geo_field")
    if field == nil then return false, "岩域生成失败" end
    self.active_field = field
    field.Transform:SetPosition(x, 0, z)
    self.inst.components.lumineenergy:Spend("geo_field")
    self.field_ready = GetTime() + FIELD_COOLDOWN
    self:Sync()
    return true
end

function LumineGeo:EndField()
    if self.active_field ~= nil and self.active_field:IsValid() then self.active_field:Remove() end
    self.active_field = nil
end

function LumineGeo:OnSave()
    return {
        shield_remaining = math.max(0, self.shield_ready - GetTime()),
        field_remaining = math.max(0, self.field_ready - GetTime()),
    }
end

function LumineGeo:OnLoad(data)
    if data ~= nil then
        self.shield_ready = GetTime() + math.max(0, tonumber(data.shield_remaining) or 0)
        self.field_ready = GetTime() + math.max(0, tonumber(data.field_remaining) or 0)
    end
    self.inst:DoTaskInTime(0, function() if self.inst:IsValid() then self:Sync() end end)
end

function LumineGeo:OnRemoveFromEntity()
    self:EndShield()
    self:EndField()
    local health = self.inst.components.health
    if health ~= nil and health.DoDelta == self.shield_do_delta then
        health.DoDelta = self.original_do_delta
    end
end

return LumineGeo
