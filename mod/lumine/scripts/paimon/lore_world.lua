local C = require("paimon/config")
local Lore = require("paimon/lore")
local WorldLore = Class(function(self, inst)
    self.inst, self.allowed, self.seen = inst, nil, {}
    self.nexttime = 0
    self.guide_records = {}
    self.companion_records = {}
end)

function WorldLore:GetCompanionRecord(userid, imported)
    local data = require("paimon/companion_data")
    self.companion_records[userid] = data.Newer(self.companion_records[userid],imported)
    return self.companion_records[userid]
end

function WorldLore:GetGuideRecord(userid, imported)
    local record = self.guide_records[userid]
    if not record then
        record = {seen={},count=0,nexttime=0}
        self.guide_records[userid] = record
    end
    if type(imported)=="table" then
        for key,value in pairs(imported) do
            if record.count>=C.GUIDE_MAX_SITES then break end
            if value==true and type(key)=="string" and #key<=128 and not record.seen[key] then
                record.seen[key],record.count = true,record.count+1
            end
        end
    end
    return record
end

local function Sample(pool, count, out)
    for i = #pool, 2, -1 do local j = math.random(i); pool[i], pool[j] = pool[j], pool[i] end
    for i = 1, count do out[pool[i]] = true end
end
function WorldLore:EnsurePool()
    if self.allowed then return end
    local pools = { core = {}, branch = {}, secret = {} }
    for _, line in ipairs(Lore.lines) do
        local pool = pools[line.pool]; pool[#pool + 1] = line.id
    end
    self.allowed = {}
    Sample(pools.core, 25, self.allowed)
    Sample(pools.branch, 15, self.allowed)
    Sample(pools.secret, math.random(0, 5), self.allowed)
end
function WorldLore:Claim(context, days, distance, bosses)
    if not self.inst.ismastershard or GetTime() < self.nexttime then return end
    self:EnsurePool()
    local candidates = {}
    for _, line in ipairs(Lore.lines) do
        if self.allowed[line.id] and not self.seen[line.id] and line.contexts[context]
            and days >= line.day and distance >= line.distance and bosses >= line.bosses then
            candidates[#candidates + 1] = line.id
        end
    end
    if #candidates == 0 then return end
    local id = candidates[math.random(#candidates)]
    self.seen[id], self.nexttime = true, GetTime() + C.LORE_COOLDOWN
    return id
end
function WorldLore:OnSave()
    local guides = {}
    for userid,record in pairs(self.guide_records) do
        if record.count>0 then
            guides[userid] = {seen=record.seen,remaining=math.max(0,record.nexttime-GetTime())}
        end
    end
    -- 向导发现由每个分片按玩家保存；隐藏剧情配额仍只由主分片管理。
    if not self.inst.ismastershard then return {guide_records=guides,companion_records=self.companion_records} end
    self:EnsurePool()
    return { allowed = self.allowed, seen = self.seen, remaining = math.max(0, self.nexttime - GetTime()), guide_records=guides,companion_records=self.companion_records }
end
function WorldLore:OnLoad(data)
    if data then
        self.allowed, self.seen = data.allowed, data.seen or {}
        self.nexttime = GetTime() + (data.remaining or 0)
        self.guide_records = {}
        self.companion_records = {}
        for userid,record in pairs(type(data.companion_records)=="table" and data.companion_records or {}) do
            if type(userid)=="string" and #userid>0 and #userid<=128 then self:GetCompanionRecord(userid,record) end
        end
        for userid,saved in pairs(type(data.guide_records)=="table" and data.guide_records or {}) do
            if type(userid)=="string" and #userid>0 and #userid<=128 and type(saved)=="table" then
                local record = self:GetGuideRecord(userid,saved.seen)
                local remaining = tonumber(saved.remaining) or 0
                if remaining~=remaining then remaining=0 end
                record.nexttime = GetTime()+math.max(0,math.min(C.GUIDE_GAP,remaining))
            end
        end
    end
end
return WorldLore
