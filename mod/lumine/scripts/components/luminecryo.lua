local Rules = require("cryo/rules")
local Attacks = require("cryo/attacks")
local Combat = require("cryo/combat")
local Targets = require("lumine_dendro_targets")
local Cast = require("flight/lumine_cryo_cast")
local ResolveDirection = require("flight/lumine_wind_aim")
local Weapons = {}
for _, weapon in ipairs(require("lumine_gear_stats").swords) do Weapons[weapon.name] = true end

local Cryo = Class(function(self, inst)
    self.inst = inst
    self.effects = {}
    self.target_ready = setmetatable({}, {__mode = "k"})
    self.used_projectiles = setmetatable({}, {__mode = "k"})
    self.shield_ready, self.infusion_ready, self.meteor_ready, self.field_until = 0, 0, 0, 0
    self.charges = 0
    self.listeners = {
        lumine_element_resonated = function() self:Refresh() end,
        ms_respawnedfromghost = function() self:Refresh() end,
        onhitother = function(_, data) Combat.OnHit(self, data) end,
        unequip = function(_, data)
            if data and data.item == self.weapon then self:EndInfusion() end
        end,
        death = function() self.shield_ready = GetTime() + Rules.shield.interval self:Clear() end,
        ms_becameghost = function() self:Clear() end,
        onremove = function() self:Clear() end,
    }
    for name, fn in pairs(self.listeners) do inst:ListenForEvent(name, fn) end
    Combat.Install(self)
    self.tick = inst:DoPeriodicTask(1, function() self:Refresh() end)
    inst:DoTaskInTime(0, function() self:Refresh() end)
end)

function Cryo:CanUse()
    local inst = self.inst
    local journey = inst.components.luminejourney
    return inst:IsValid() and journey and journey.active_element == "cryo" and journey:CanResonate("cryo")
        and not inst.components.health:IsDead() and not inst:HasAnyTag("playerghost", "INLIMBO")
end

function Cryo:IsModWeapon(weapon)
    return weapon and weapon:IsValid() and Weapons[weapon.prefab] == true and weapon.components.weapon ~= nil
end

function Cryo:Track(effect)
    self.effects[effect] = true
    return effect
end

function Cryo:TrackFX(fx)
    self:Track(fx)
    fx:ListenForEvent("onremove", function() self.effects[fx] = nil end)
    return fx
end

function Cryo:Publish()
    local inst = self.inst
    inst._lumine_cryo_shield:set(self.shield == true)
    inst._lumine_cryo_shield_ready:set(self.shield_ready)
    inst._lumine_cryo_charges:set(self.charges)
    inst._lumine_cryo_infusion_ready:set(self.infusion_ready)
    inst._lumine_cryo_meteor_ready:set(self.meteor_ready)
end

function Cryo:RemoveShield()
    self.shield = false
    if self.shield_fx and self.shield_fx:IsValid() then self.shield_fx:Remove() end
    self.shield_fx = nil
end

function Cryo:Refresh()
    if not self:CanUse() then
        if self.shield then self.shield_ready = GetTime() + Rules.shield.interval end
        self:Clear()
        return
    end
    if not self.shield and GetTime() >= self.shield_ready then
        local fx = SpawnPrefab("forcefieldfx")
        if fx then
            self.inst:AddChild(fx)
            fx.AnimState:SetMultColour(.42, .76, 1, .72)
            fx.Light:SetColour(.45, .75, 1)
            self.shield_fx, self.shield = fx, true
            for index = 1, 3 do
                local crystal = SpawnPrefab("lumine_cryo_shield_crystal")
                if crystal then
                    fx:AddChild(crystal)
                    local angle = index * TWOPI / 3
                    crystal.Transform:SetPosition(.48 * math.cos(angle), .8, .48 * math.sin(angle))
                end
            end
        end
    end
    if self.weapon and (not self.weapon:IsValid()
        or self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= self.weapon) then
        self:EndInfusion()
    end
    self:Publish()
end

function Cryo:BreakShield()
    self:RemoveShield()
    self.shield_ready = GetTime() + Rules.shield.interval
    self:Publish()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("lumine_cryo_impact")
    if fx then fx.Transform:SetPosition(x, 0, z) self:TrackFX(fx) end
    Attacks.Area(self, x, z, Rules.shield.radius, 0, Rules.shield.freeze)
end

function Cryo:EndInfusion()
    if self.weapon then self.inst:RemoveEventCallback("onremove", self.weapon_removed, self.weapon) end
    self.weapon, self.charges = nil, 0
    if self.weapon_fx and self.weapon_fx:IsValid() then self.weapon_fx:Remove() end
    self.weapon_fx = nil
    self.inst._lumine_cryo_charges:set(0)
end

function Cryo:InField()
    return self.field and self.field:IsValid() and GetTime() < self.field_until
        and self.inst:GetDistanceSqToInst(self.field) <= Rules.field.radius ^ 2
end

function Cryo:EnhanceHit(attack, data)
    local target = data.target
    if attack.enhanced or not self:CanUse() or not Targets.IsHitTarget(self.inst, target)
        or not self:IsModWeapon(data.weapon) then return end
    local projectile = attack.projectile
    if projectile and self.used_projectiles[projectile] then return end
    local field = self:InField()
    if field then
        if GetTime() < (self.target_ready[target] or 0) then return end
        self.target_ready[target] = GetTime() + Rules.field.target_interval
    elseif self.weapon ~= data.weapon or self.charges <= 0 then
        return
    else
        self.charges = self.charges - 1
        self.inst._lumine_cryo_charges:set(self.charges)
        if self.charges == 0 then self:EndInfusion() end
    end
    attack.enhanced = true
    if projectile then self.used_projectiles[projectile] = true end
    local x, _, z = target.Transform:GetWorldPosition()
    attack.pillars = {x = x, z = z}
end

function Cryo:Pillars(x, z)
    Attacks.Pillars(self, x, z)
end

function Cryo:CanCast(kind)
    if not self:CanUse() or self.inst:HasTag("lumine_gliding") or not self.inst.sg
        or self.inst.sg:HasAnyStateTag("busy", "sleeping", "frozen", "dead", "flight", "drowning", "devoured", "suspended")
        or (self.inst.components.rider and self.inst.components.rider:IsRiding()) then
        return false, "现在无法使用冰元素技能"
    end
    if self[kind .. "_ready"] > GetTime() then return false, "技能冷却中" end
    if not self.inst.components.lumineenergy:CanSpendAmount(Rules[kind].cost) then return false, "元素力不足" end
    return true
end

function Cryo:Cast(kind, aim_x, aim_z)
    local ok, reason = self:CanCast(kind)
    if not ok then return false, reason end
    local inst = self.inst
    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if kind == "infusion" and not self:IsModWeapon(weapon) then return false, "请先装备旅行者的剑" end
    local x, _, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, inst.Transform:GetRotation(), aim_x, aim_z)
    local distance = Rules.meteor.range
    if type(aim_x) == "number" and type(aim_z) == "number"
        and math.abs(aim_x) < math.huge and math.abs(aim_z) < math.huge then
        distance = math.min(distance, math.sqrt((aim_x - x)^2 + (aim_z - z)^2))
    end
    local point = {kind = kind, weapon = weapon, x = x + dx * distance, z = z + dz * distance}
    if kind == "meteor" and (not TheWorld.Map:IsValidTileAtPoint(point.x, 0, point.z)
        or TheWorld.Map:IsGroundTargetBlocked(Vector3(point.x, 0, point.z), .15)) then
        return false, "请选择可落下冰陨的地面"
    end
    inst.sg:GoToState(Cast.STATE, point)
    return true
end

function Cryo:Release(point)
    if not point or point.used or not self:CanUse() or self.inst.sg.currentstate.name ~= Cast.STATE then return false end
    local inst, kind = self.inst, point.kind
    if self[kind .. "_ready"] > GetTime() then return false end
    if kind == "infusion" and (not self:IsModWeapon(point.weapon)
        or inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= point.weapon) then return false end
    if kind == "meteor" and (inst:GetDistanceSqToPoint(point.x, 0, point.z) > (Rules.meteor.range + .1)^2
        or not TheWorld.Map:IsValidTileAtPoint(point.x, 0, point.z)
        or TheWorld.Map:IsGroundTargetBlocked(Vector3(point.x, 0, point.z), .15)) then return false end
    local fx = SpawnPrefab(kind == "infusion" and "lumine_cryo_weapon_fx" or "lumine_cryo_meteor")
    if not fx then return false end
    if not inst.components.lumineenergy:SpendAmount(Rules[kind].cost) then fx:Remove() return false end
    point.used = true
    self[kind .. "_ready"] = GetTime() + Rules[kind].cooldown
    if kind == "infusion" then
        self:EndInfusion()
        self.weapon, self.charges, self.weapon_fx = point.weapon, Rules.infusion.charges, fx
        self.weapon_removed = function() self:EndInfusion() end
        inst:ListenForEvent("onremove", self.weapon_removed, self.weapon)
        fx.Follower:FollowSymbol(inst.GUID, "swap_object", 0, 0, 0)
    else
        self:TrackFX(fx)
        Attacks.Launch(self, fx, point)
    end
    self:Publish()
    return true
end

function Cryo:EndField()
    if self.field and self.field:IsValid() then self.field:Remove() end
    self.field, self.field_until = nil, 0
    self.target_ready = setmetatable({}, {__mode = "k"})
    self.inst._lumine_cryo_field_until:set(0)
end

function Cryo:Clear()
    self:RemoveShield()
    self:EndInfusion()
    self:EndField()
    while next(self.effects) do
        local effect = next(self.effects)
        self.effects[effect] = nil
        effect:Remove()
    end
    self:Publish()
end

function Cryo:ResetCooldowns()
    self.infusion_ready, self.meteor_ready = 0, 0
    self:Publish()
end

function Cryo:OnSave()
    local now = GetTime()
    return {shield = self.shield == true, shield_remaining = math.max(0, self.shield_ready - now),
        infusion_remaining = math.max(0, self.infusion_ready - now), meteor_remaining = math.max(0, self.meteor_ready - now)}
end

function Cryo:OnLoad(data)
    self:Clear()
    if not data then return end
    local now = GetTime()
    for kind, maximum in pairs({shield = Rules.shield.interval, infusion = Rules.infusion.cooldown, meteor = Rules.meteor.cooldown}) do
        local remaining = tonumber(data[kind .. "_remaining"]) or 0
        if remaining ~= remaining then remaining = 0 end
        self[kind .. "_ready"] = now + math.max(0, math.min(maximum, remaining))
    end
    if data.shield then self.shield_ready = now end
    self:Publish()
end

function Cryo:OnRemoveFromEntity()
    self:Clear()
    self.tick:Cancel()
    for name, fn in pairs(self.listeners) do self.inst:RemoveEventCallback(name, fn) end
    Combat.Uninstall(self)
end

return Cryo
