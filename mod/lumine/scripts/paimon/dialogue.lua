local C = require("paimon/config")
local Database = require("paimon/dialogue_database")
local Memory = require("paimon/memory")
local Guide = require("paimon/guide")
local Flight = require("paimon/flight")
local Tracking = require("paimon/tracking")
local function ValidEvent(pet, event)
    -- Observation and speech use separate schedules. A shower can end while
    -- its reaction waits behind another line; wet ground alone is not rain.
    if event == "rain" and not (TheWorld.state and TheWorld.state.israining) then return false end
    return Flight.Valid(pet, event)
end
local Dialogue = Class(function(self, pet)
    self.pet = pet
    self.recent, self.cooldowns, self.pending = {}, {}, {}
    self.nextspeech, self.priority, self.speaking_until = 0, 0, 0
    self.quiet_until = 0
end)

function Dialogue:Offer(event, lifetime)
    local group = Database.events[event]
    if group == nil or (self.cooldowns[event] or 0) > GetTime() then return end
    if event == "rain" and not ValidEvent(self.pet, event) then return end
    if group.priority <= 2 and GetTime() < self.quiet_until then return end
    self.pending[event] = GetTime() + (lifetime or 8)
end

function Dialogue:Remember(id)
    self.recent[#self.recent + 1] = id
    if #self.recent > C.RECENT_LINES then table.remove(self.recent, 1) end
end

function Dialogue:CanSpeak(priority, kind)
    local t = GetTime()
    if self.pet._dormant or TheWorld.speechdisabled then return false end
    if priority == 4 and self.priority < 4 then return true end
    -- 画面外新发现有时效性，可以接过普通闲聊；紧急提醒仍优先。
    if kind == "guide" then
        return self.priority < 3 or (t >= self.nextspeech and t >= self.speaking_until)
    end
    if priority <= 2 and t < self.quiet_until then return false end
    return t >= self.nextspeech and t >= self.speaking_until
end

function Dialogue:HasUrgentPending()
    for event, expiry in pairs(self.pending) do
        if expiry >= GetTime() and Database.events[event].priority >= 3 and ValidEvent(self.pet, event) then return true end
    end
    return false
end

function Dialogue:Speak(text, priority, id, kind)
    if not self:CanSpeak(priority, kind) then return false end
    local _, characters = text:gsub("[^\128-\193]", "")
    local duration = math.max(C.SPEECH_TIME, math.min(9, characters * .14))
    self.pet.components.talker:Say(text, duration, true)
    self.priority, self.speaking_until = priority, GetTime() + duration
    self.nextspeech = GetTime() + C.SPEECH_GAP
    self.quiet_until = self.speaking_until + math.random(C.QUIET_MIN,C.QUIET_MAX)
    -- 同一批事件只保留更重要的后续，低优先级不排队接着念。
    for event in pairs(self.pending) do
        if Database.events[event].priority <= priority then self.pending[event] = nil end
    end
    self:Remember(id)
    Memory.Spoken(self.pet,id)
    local owner = self.pet.owner
    if owner and owner.components and owner.components.luminedialogue then
        owner.components.luminedialogue:OnPaimonSpeech(self.pet, id, duration, priority)
    end
    return true
end

function Dialogue:Update()
    Flight.Poll(self.pet)
    Guide.Poll(self.pet)
    Tracking.Poll(self.pet)
    if Tracking.TrySpeak(self.pet) then return end
    local companion=self.pet.owner and self.pet.owner.components.paimoncompanion
    if companion and companion:TrySpeak() then return end
    if Guide.TrySpeak(self.pet) then return end
    local candidates, pools, best = {}, {}, 0
    for event, expiry in pairs(self.pending) do
        local group = Database.events[event]
        if expiry < GetTime() or (self.cooldowns[event] or 0) > GetTime() or not ValidEvent(self.pet, event) then
            self.pending[event] = nil
        elseif self:CanSpeak(group.priority) then
            local eligible = Memory.Lines(self.pet,group.lines)
            if #eligible == 0 then self.pending[event] = nil
            else
                pools[event] = eligible
                if group.priority > best then candidates, best = {}, group.priority end
                if group.priority == best then candidates[#candidates + 1] = event end
            end
        end
    end
    if #candidates == 0 then return end
    table.sort(candidates)
    local event = candidates[math.random(#candidates)]
    local group, choices = Database.events[event], {}
    local recent = {}; for _, id in ipairs(self.recent) do recent[id] = true end
    for _, line in ipairs(pools[event]) do
        if not recent[line.id] then choices[#choices + 1] = line end
    end
    -- 小类别不足 15 句时按最久未说优先回退，不让该类别永久沉默。
    if #choices == 0 then
        for _, id in ipairs(self.recent) do
            for _, line in ipairs(pools[event]) do
                if line.id == id then choices[1] = line; break end
            end
            if #choices > 0 then break end
        end
    end
    local line = choices[math.random(#choices)]
    if self:Speak(line.text, group.priority, line.id) then
        self.cooldowns[event] = GetTime() + math.random(group.cooldown[1], group.cooldown[2])
        self.pending[event] = nil
    end
end

function Dialogue:OnSave()
    local remaining = {}
    for key, deadline in pairs(self.cooldowns) do remaining[key] = math.max(0, deadline - GetTime()) end
    return { recent = self.recent, cooldowns = remaining, gap = math.max(0, self.nextspeech - GetTime()),
        quiet = math.max(0,self.quiet_until-GetTime()) }
end
function Dialogue:OnLoad(data)
    if type(data) ~= "table" then return end
    self.recent = data.recent or {}
    while #self.recent > C.RECENT_LINES do table.remove(self.recent, 1) end
    for key, seconds in pairs(data.cooldowns or {}) do
        if type(seconds) == "number" then self.cooldowns[key] = GetTime() + math.max(0, seconds) end
    end
    self.nextspeech = GetTime() + (data.gap or 0)
    self.quiet_until = GetTime() + (data.quiet or 0)
end
return Dialogue
