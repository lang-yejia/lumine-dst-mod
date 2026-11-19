local Dash = require("flight/lumine_wind_dash")
local Tornado = require("flight/lumine_wind_tornado_cast")
local ResolveDirection = require("flight/lumine_wind_aim")
local TORNADO_START = 1.5

local LumineWind = Class(function(self, inst)
    self.inst = inst
    self.dash_ready = 0
    self.tornado_ready = 0
    Dash.AttachDodge(inst)
    inst:DoTaskInTime(0, function() if inst:IsValid() then self:Sync() end end)
end)

local function IsGround(x, z)
    return TheWorld.Map:IsPassableAtPoint(x, 0, z)
        and TheWorld.Map:IsVisualGroundAtPoint(x, 0, z)
end

local function IsTornadoSpawnBlocked(x, z)
    if not IsGround(x, z) then return true end
    return #TheSim:FindEntities(x, 0, z, 0.5, nil, {"INLIMBO"},
        {"wall", "structure"}) > 0
end

local function TornadoSpawnPoint(inst, direction)
    local x, _, z = inst.Transform:GetWorldPosition()
    for distance = .5, TORNADO_START, .5 do
        if IsTornadoSpawnBlocked(x + direction.dx * distance, z + direction.dz * distance) then return end
    end
    return x + direction.dx * TORNADO_START, z + direction.dz * TORNADO_START
end

function LumineWind:Sync()
    local journey = self.inst.components.luminejourney
    local active = journey ~= nil and journey.active_element == "wind"
    self.inst._lumine_wind_skills:set(active and 3 or 0)
    self.inst._lumine_wind_dash_ready:set(self.dash_ready)
    self.inst._lumine_wind_tornado_ready:set(self.tornado_ready)
end

function LumineWind:ResetCooldowns()
    self.dash_ready, self.tornado_ready = 0, 0
    self:Sync()
end

function LumineWind:CanCast(id, releasing)
    local inst = self.inst
    local journey = inst.components.luminejourney
    if journey == nil or journey.active_element ~= "wind" or not journey:CanResonate("wind") then
        return false, "请先在七天神像与风元素共鸣"
    end
    if inst:HasTag("playerghost") or inst.components.health == nil or inst.components.health:IsDead() then
        return false, "现在无法施放技能"
    end
    if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
        return false, "骑乘时无法施放风元素技能"
    end
    if inst.lumine_glider_phase and inst.lumine_glider_phase:value() > 0 then
        return false, "请先收起风之翼"
    end
    if inst:GetCurrentPlatform() ~= nil then return false, "船上无法施放风元素技能" end
    if inst.sg ~= nil and (inst.sg:HasStateTag("sleeping") or (not releasing and inst.sg:HasStateTag("busy"))) then
        return false, "现在无法施放技能"
    end
    local x, _, z = inst.Transform:GetWorldPosition()
    if not IsGround(x, z) then return false, "需要站在陆地上" end
    local ready = id == "wind_dash" and self.dash_ready or self.tornado_ready
    if ready > GetTime() then return false, "技能冷却中：" .. math.ceil(ready - GetTime()) .. " 秒" end
    local energy = inst.components.lumineenergy
    if energy ~= nil and not energy:CanSpend(id) then return false, "元素力不足" end
    return true
end

function LumineWind:CastDash(aim_x, aim_z)
    local ok, reason = self:CanCast("wind_dash")
    if not ok then return false, reason end
    local inst = self.inst
    if not inst.sg or not inst.sg:HasState(Dash.STATE) then return false, "现在无法冲刺" end
    local plan = Dash.Plan(inst, aim_x, aim_z)
    if not plan then return false, "前方无法冲刺" end
    local energy = inst.components.lumineenergy
    if not energy or not energy:Spend("wind_dash") then return false, "元素力不足" end
    self.dash_ready = GetTime() + Dash.COOLDOWN
    self:Sync()
    inst.sg:GoToState(Dash.STATE, plan)
    return true
end

function LumineWind:CastTornado(aim_x, aim_z)
    local ok, reason = self:CanCast("wind_tornado")
    if not ok then return false, reason end
    local inst = self.inst
    if not inst.sg or not inst.sg:HasState(Tornado.STATE) then return false, "现在无法施放风涡剑" end
    local x, _, z = inst.Transform:GetWorldPosition()
    local dx, dz = ResolveDirection(x, z, inst.Transform:GetRotation(), aim_x, aim_z)
    local direction = {dx = dx, dz = dz}
    if not TornadoSpawnPoint(inst, direction) then return false, "前方无法生成龙卷风" end
    inst.sg:GoToState(Tornado.STATE, direction)
    return true
end

function LumineWind:ReleaseTornado(direction)
    local inst = self.inst
    if not inst.sg or not inst.sg:HasStateTag("lumine_wind_tornado_casting") then return false end
    local ok, reason = self:CanCast("wind_tornado", true)
    if not ok then return false, reason end
    local sx, sz = TornadoSpawnPoint(inst, direction)
    if not sx then return false, "前方无法生成龙卷风" end
    local tornado = SpawnPrefab("lumine_wind_tornado")
    if tornado == nil then return false, "龙卷风生成失败" end
    local energy = inst.components.lumineenergy
    if not energy or not energy:Spend("wind_tornado") then
        tornado:Remove()
        return false, "元素力不足"
    end
    tornado.Transform:SetPosition(sx, 0, sz)
    tornado:SetCaster(inst, direction.dx, direction.dz)
    self.tornado_ready = GetTime() + Tornado.COOLDOWN
    self:Sync()
    return true
end

function LumineWind:OnSave()
    return {
        dash_remaining = math.max(0, self.dash_ready - GetTime()),
        tornado_remaining = math.max(0, self.tornado_ready - GetTime()),
    }
end

function LumineWind:OnLoad(data)
    if data ~= nil then
        self.dash_ready = GetTime() + math.min(Dash.COOLDOWN, math.max(0, tonumber(data.dash_remaining) or 0))
        self.tornado_ready = GetTime() + math.max(0, tonumber(data.tornado_remaining) or 0)
    end
    self.inst:DoTaskInTime(0, function() if self.inst:IsValid() then self:Sync() end end)
end

return LumineWind
