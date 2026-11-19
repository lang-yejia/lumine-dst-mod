local Rules = require("lumine_dendro_rules")
local Targets = require("lumine_dendro_targets")
local RootWave = require("lumine_dendro_root")
local Field = require("lumine_dendro_field")
local Cast = require("flight/lumine_dendro_cast")
local ResolveDirection = require("flight/lumine_wind_aim")

local Dendro = Class(function(self, inst)
    self.inst = inst
    self.effects = {}
    self.root_ready, self.field_ready = 0, 0
    self.listeners = {
        onhitother = function(_, data) self:OnHit(data) end,
        death = function() self:ClearEffects() end,
        ms_becameghost = function() self:ClearEffects() end,
        ms_playerdespawnanddelete = function() self:ClearEffects() end,
        onremove = function() self:ClearEffects() end,
        lumine_element_resonated = function()
            if not self:CanUse() then self:ClearEffects() end
        end,
    }
    for event, fn in pairs(self.listeners) do
        inst:ListenForEvent(event, fn)
    end
end)

function Dendro:CanUse()
    local inst = self.inst
    local journey, health = inst.components.luminejourney, inst.components.health
    return inst:IsValid() and journey ~= nil and journey.active_element == "dendro"
        and journey:CanResonate("dendro") and health ~= nil and not health:IsDead()
        and not inst:HasAnyTag("playerghost", "lumine_gliding", "INLIMBO")
end

function Dendro:CanCast(slot)
    local inst = self.inst
    if not self:CanUse() or not inst.sg or inst.sg:HasAnyStateTag(
        "busy", "dead", "sleeping", "frozen", "flight", "drowning", "devoured", "suspended")
        or (inst.components.rider and inst.components.rider:IsRiding()) then
        return false, "现在无法使用草元素技能"
    end
    if self[slot .. "_ready"] > GetTime() then return false, "技能冷却中" end
    local energy = inst.components.lumineenergy
    if not energy or not energy:CanSpend("dendro_" .. slot) then return false, "元素力不足" end
    return true
end

function Dendro:CastRoot(aim_x, aim_z)
    local ok, reason = self:CanCast("root")
    if not ok then return false, reason end
    local inst = self.inst
    if not inst.sg:HasState(Cast.STATE) then return false end
    local x, _, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, inst.Transform:GetRotation(), aim_x, aim_z)
    inst.sg:GoToState(Cast.STATE, {dx = dx, dz = dz})
    return true
end

function Dendro:ReleaseRoot(aim)
    local inst = self.inst
    if not aim or not self:CanUse() or inst.sg.currentstate.name ~= Cast.STATE or self.root_ready > GetTime()
        or not inst.components.lumineenergy:Spend("dendro_root") then
        return false
    end
    self.root_ready = GetTime() + Rules.ROOT.cooldown
    inst._lumine_dendro_root_ready:set(self.root_ready)
    RootWave(self, aim)
    return true
end

function Dendro:CastField()
    local ok, reason = self:CanCast("field")
    if not ok then return false, reason end
    local cloud = Field.Prepare()
    if not cloud then return false, "孢子云暂时无法生成" end
    local inst = self.inst
    if not inst.components.lumineenergy:Spend("dendro_field") then
        cloud:Remove()
        return false, "元素力不足"
    end
    if self.field then self.field:Remove() end
    self.field_ready = GetTime() + Rules.FIELD.cooldown
    inst._lumine_dendro_field_ready:set(self.field_ready)
    inst.SoundEmitter:PlaySound("dontstarve/wilson/use_gemstaff")
    Field.Start(self, cloud)
    return true
end

function Dendro:PublishCooldowns()
    self.inst._lumine_dendro_root_ready:set(self.root_ready)
    self.inst._lumine_dendro_field_ready:set(self.field_ready)
end

function Dendro:ResetCooldowns()
    self.root_ready, self.field_ready, self.vine_ready = 0, 0, 0
    self:PublishCooldowns()
end

function Dendro:OnSave()
    local now = GetTime()
    return {
        root = math.max(0, self.root_ready - now),
        field = math.max(0, self.field_ready - now),
    }
end

function Dendro:OnLoad(data)
    if not data then return end
    self:ClearEffects()
    local now = GetTime()
    self.root_ready = now + math.max(0, math.min(Rules.ROOT.cooldown, tonumber(data.root) or 0))
    self.field_ready = now + math.max(0, math.min(Rules.FIELD.cooldown, tonumber(data.field) or 0))
    self:PublishCooldowns()
end

function Dendro:ClearEffects()
    for effect in pairs(self.effects) do
        effect:Remove()
    end
end

function Dendro:Track(effect)
    self.effects[effect] = true
    return effect
end

function Dendro:OnRemoveFromEntity()
    self:ClearEffects()
    for event, fn in pairs(self.listeners) do
        self.inst:RemoveEventCallback(event, fn)
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

function Dendro:SpawnVine(target)
    local pt = target:GetPosition()
    local offset = FindWalkableOffset(pt, TWOPI * math.random(), 1.6, 6, false, true, NoHoles, false, true, true)
    if not offset then return end
    local vine = SpawnPrefab("lunarplanttentacle")
    if not vine then return end
    vine.owner = self.inst
    vine.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
    local combat = vine.components.combat
    combat:SetDefaultDamage(Rules.VINE_DAMAGE)
    vine.components.planardamage:SetBaseDamage(0)
    local attack = combat.DoAttack
    combat.DoAttack = function(component, ...)
        if self:CanUse() and component.target == target and Targets.IsEnemy(self.inst, target) then
            return attack(component, ...)
        end
    end
    self:Track(vine)
    vine:ListenForEvent("onremove", function() self.effects[vine] = nil end)
    combat:SetTarget(target)
    return vine
end

function Dendro:OnHit(data)
    if not data or not data.from_doattack or (data.damageresolved or 0) <= 0
        or data.redirected or not data.weapon or not data.weapon:HasTag("lumine_sword")
        or not self:CanUse() or not Targets.IsEnemy(self.inst, data.target) then
        return
    end
    local now = GetTime()
    -- Native hit callbacks for the same melee attack share one simulation tick.
    if self.last_roll == now or now < (self.vine_ready or 0) then return end
    self.last_roll = now
    if math.random() < Rules.PROC_CHANCE and self:SpawnVine(data.target) then
        self.vine_ready = now + Rules.PROC_INTERVAL
    end
end

return Dendro
