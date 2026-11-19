local Rules = require("hydro/rules")
local StartDrop = require("hydro/drop")
local Targets = require("lumine_dendro_targets")
local Cast = require("flight/lumine_hydro_cast")
local StartStream = require("hydro/stream")
local StartBubble = require("hydro/bubble")
local ResolveDirection = require("flight/lumine_wind_aim")

local Hydro = Class(function(self, inst)
    self.inst = inst
    self.effects = {}
    self.ready = {stream = 0, bubble = 0}
    self.listeners = {
        onhitother = function(_, data) self:OnHit(data) end,
        death = function() self:Clear() end,
        ms_becameghost = function() self:Clear() end,
        ms_playerdespawnanddelete = function() self:Clear() end,
        onremove = function() self:Clear() end,
        lumine_element_resonated = function() if not self:CanUse() then self:Clear() end end,
    }
    for event, fn in pairs(self.listeners) do inst:ListenForEvent(event, fn) end
end)

function Hydro:CanUse()
    local inst = self.inst
    local journey, health = inst.components.luminejourney, inst.components.health
    return inst:IsValid() and journey and journey.active_element == "hydro"
        and journey:CanResonate("hydro") and health and not health:IsDead()
        and not inst:HasAnyTag("playerghost", "INLIMBO", "lumine_gliding")
end

function Hydro:Track(effect)
    self.effects[effect] = true
    effect:ListenForEvent("onremove", function() self.effects[effect] = nil end)
end

function Hydro:Clear()
    for effect in pairs(self.effects) do effect:Remove() end
end

function Hydro:OnRemoveFromEntity()
    self:Clear()
    for event, fn in pairs(self.listeners) do self.inst:RemoveEventCallback(event, fn) end
end

function Hydro:Cast(skill, aim_x, aim_z)
    local inst = self.inst
    if not self:CanUse() or not inst.sg or not inst.sg:HasState(Cast.STATE)
        or inst.sg:HasAnyStateTag("busy", "dead", "sleeping", "frozen", "flight", "drowning", "devoured", "suspended")
        or (inst.components.rider and inst.components.rider:IsRiding()) then
        return false, "现在无法使用水元素技能"
    end
    if self.ready[skill] > GetTime() then return false, "技能冷却中" end
    if not inst.components.lumineenergy:CanSpend("hydro_" .. skill) then return false, "元素力不足" end
    local rotation = inst.Transform:GetRotation()
    local x, _, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, rotation, aim_x, aim_z)
    rotation = math.atan2(-dz, dx) / DEGREES
    inst.sg:GoToState(Cast.STATE, {skill = skill, rotation = rotation, dx = dx, dz = dz})
    return true
end

function Hydro:Release(aim)
    local inst, skill = self.inst, aim.skill
    if not self:CanUse() or inst.sg.currentstate.name ~= Cast.STATE or self.ready[skill] > GetTime() then return false end
    local fx = SpawnPrefab("lumine_hydro_" .. skill)
    if not fx then return false end
    if not inst.components.lumineenergy:Spend("hydro_" .. skill) then fx:Remove() return false end
    self.ready[skill] = GetTime() + Rules[skill].cooldown
    inst["_lumine_hydro_" .. skill .. "_ready"]:set(self.ready[skill])
    if skill == "stream" then
        StartStream(fx, self, aim)
    else
        if self.bubble and self.bubble:IsValid() then self.bubble:Remove() end
        self.bubble = fx
        self.inst._lumine_hydro_bubble_until:set(GetTime() + Rules.bubble.duration)
        self.inst._lumine_hydro_bubble_hp:set(Rules.bubble.health)
        fx:ListenForEvent("onremove", function()
            if self.bubble == fx then
                self.bubble = nil
                self.inst._lumine_hydro_bubble_until:set(0)
                self.inst._lumine_hydro_bubble_hp:set(0)
            end
        end)
        StartBubble(fx, self, aim)
    end
    return true
end

function Hydro:ResetCooldowns()
    self.drop_ready = 0
    for skill in pairs(self.ready) do
        self.ready[skill] = 0
        self.inst["_lumine_hydro_" .. skill .. "_ready"]:set(0)
    end
end

function Hydro:OnSave()
    local now = GetTime()
    return {stream = math.max(0, self.ready.stream - now), bubble = math.max(0, self.ready.bubble - now)}
end

function Hydro:OnLoad(data)
    if not data then return end
    local now = GetTime()
    for skill in pairs(self.ready) do
        self.ready[skill] = now + math.max(0, math.min(Rules[skill].cooldown, tonumber(data[skill]) or 0))
        self.inst["_lumine_hydro_" .. skill .. "_ready"]:set(self.ready[skill])
    end
end

function Hydro:OnHit(data)
    if not data or not data.from_doattack or (data.damageresolved or 0) <= 0
        or data.redirected or not data.weapon or not data.weapon:HasTag("lumine_sword")
        or not self:CanUse() or not Targets.IsHitTarget(self.inst, data.target) then
        return
    end
    local now = GetTime()
    if self.last_roll == now or now < (self.drop_ready or 0) then return end
    self.last_roll = now
    if math.random() >= Rules.drop.chance then return end
    local drop = SpawnPrefab("lumine_hydro_drop")
    if not drop then return end
    local pt = self.inst:GetPosition()
    local offset = FindWalkableOffset(pt, math.random() * TWOPI, 1.35, 8, true, false, nil, false, true, true)
    drop.Transform:SetPosition(pt.x + (offset and offset.x or .9), .22, pt.z + (offset and offset.z or 0))
    self.drop_ready = now + Rules.drop.cooldown
    StartDrop(drop, self)
end

return Hydro
