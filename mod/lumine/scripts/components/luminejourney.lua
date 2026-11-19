local Data = require("lumine_progression")
local Elements = require("lumine_statue_elements")
local Catalog = require("journey/catalog")
local Forge = require("lumine_forging_data")
local Recording = require("journey/recording")

local LumineJourney = Class(function(self, inst)
    self.inst = inst
    self.done = {}
    self.experienced = {}
    self.records = Recording.New(self)
    self.skills = {}
    self.elements = {wind = false, geo = false}
    self.active_element = nil
    self.insight = 0
    self.used_gear = {}
    self.gear_records = {}
    inst:DoTaskInTime(0, function() if inst:IsValid() then self:SyncGear() end end)
    self.days = 0
    self.last_cycle = TheWorld.state.cycles
    self.last_resolve = -1000
    self.last_boss_hits = setmetatable({}, {__mode="k"})

    inst:WatchWorldState("cycles", function() self:OnCycle() end)
    for _, season in ipairs({"iswinter", "isspring", "issummer"}) do
        inst:WatchWorldState(season, function() self:CheckWorld() end)
    end
    inst:ListenForEvent("killed", function(_, event) self:OnKilled(event) end)
    inst:ListenForEvent("onattackother", function(_, event)
        local target = event ~= nil and event.target or nil
        if target ~= nil and target:IsValid() and Data.BOSS_MILESTONES[target.prefab] then
            self.last_boss_hits[target] = GetTime()
        end
    end)
    inst:ListenForEvent("onhitother", function(_, event)
        local weapon = event and event.weapon
        if weapon == nil and inst.components.inventory ~= nil then
            weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        end
        if event ~= nil and weapon ~= nil and (event.damageresolved or event.damage or 0) > 0 then
            self:ExperienceGear(weapon.prefab, "weapon")
        end
    end)
    inst:ListenForEvent("attacked", function(_, event)
        if event == nil or event.redirected or (event.original_damage or event.damage or 0) <= 0 then return end
        local inventory = inst.components.inventory
        if inventory == nil then return end
        for _, slot in ipairs({EQUIPSLOTS.HEAD, EQUIPSLOTS.BODY}) do
            local item = inventory:GetEquippedItem(slot)
            if item ~= nil then self:ExperienceGear(item.prefab, slot == EQUIPSLOTS.HEAD and "head" or "body") end
        end
    end)
    inst:ListenForEvent("equip", function() self:ApplySwordSkill() end)
    inst:ListenForEvent("unequip", function() self:ApplySwordSkill() end)
    inst:ListenForEvent("mounted", function() self:ApplyMovementSkill() end)
    inst:ListenForEvent("dismounted", function() self:ApplyMovementSkill() end)
    inst:ListenForEvent("ms_playerreroll", function() self.records:ReleaseForReroll() end)
    inst:DoPeriodicTask(5, function() self:CheckWorld() end, 2)
    inst:DoPeriodicTask(1, function() self:ApplyMovementSkill() end, 0.5)
    inst:DoPeriodicTask(1, function() self:TickRecording() end, 1)
end)

function LumineJourney:SyncGear()
    local digits = {}
    for _, item in ipairs(Forge.ORDER) do
        digits[#digits+1] = self.gear_records[item] and "2" or self.used_gear[item] and "1" or "0"
    end
    self.inst._lumine_gear_progress:set(table.concat(digits))
end

function LumineJourney:ExperienceGear(prefab, kind)
    local stage = Forge.BY_ITEM[prefab]
    if stage == nil or stage.kind ~= kind or self.used_gear[prefab] then return end
    self.used_gear[prefab] = true
    self:SyncGear()
    if self.inst.components.talker ~= nil then
        self.inst.components.talker:Say("已体验" .. (STRINGS.NAMES[string.upper(prefab)] or prefab) .. "，可到合成台记录。")
    end
end

function LumineJourney:RecordGear(prefab)
    if Forge.BY_ITEM[prefab] == nil or not self.used_gear[prefab] or self.gear_records[prefab] then return false end
    self.gear_records[prefab] = true
    self:SyncGear()
    return true
end

function LumineJourney:RedeemInsight(prefab)
    local stage = Forge.BY_INSIGHT[prefab]
    if stage == nil then return false end
    local changed = false
    for _, item in ipairs(stage.items) do
        if not self.gear_records[item] then
            self.used_gear[item], self.gear_records[item] = true, true
            changed = true
        end
    end
    if changed then self:SyncGear() end
    return changed
end

function LumineJourney:HasStageRecords(stage)
    for _, item in ipairs(stage.items) do
        if not self.gear_records[item] then return false end
    end
    return true
end

function LumineJourney:Complete(id)
    if self.done[id] or self.experienced[id] then return end
    for _, milestone in ipairs(Data.MILESTONES) do
        if milestone.id == id then
            self.experienced[id] = true
            self.recent_discovery = Catalog.milestone_index[id]
            self:SyncJournalStatus()
            if Data.EVIDENCE[id] == nil then
                self:RecordMilestone(id)
            else
                if self.inst.components.talker ~= nil then
                    self.inst.components.talker:Say("发现旅途线索：" .. milestone.name .. "。带证物给派蒙记录。")
                end
                self.inst:PushEvent("lumine_milestone", {id = id, insight = self.insight})
            end
            return
        end
    end
end

function LumineJourney:RecordMilestone(id)
    if self.done[id] or not self.experienced[id] then return false end
    for _, milestone in ipairs(Data.MILESTONES) do
        if milestone.id == id then
            self.done[id] = true
            self.insight = self.insight + milestone.reward
            self.inst:PushEvent("lumine_milestone", {id=id, insight=self.insight})
            local pet = self.inst._paimon
            if Data.EVIDENCE[id] ~= nil and pet and pet:IsValid() and pet.components.talker then
                pet:PlayPaimonAnimation("cheer", false)
                local chapter = Catalog.by_milestone[id]
                pet.components.talker:Say(chapter and chapter.comment
                    or ("这段旅程写好了！" .. milestone.name))
            elseif self.inst.components.talker ~= nil then
                self.inst.components.talker:Say("旅行体验：" .. milestone.name .. "，见闻 +" .. milestone.reward)
            end
            return true
        end
    end
    return false
end

function LumineJourney:BeginRecording(item, pet)
    return self.records:Begin(item, pet)
end

function LumineJourney:TickRecording()
    self.records:Tick()
    self:SyncJournalStatus()
end

function LumineJourney:SyncJournalStatus()
    local net = self.inst._lumine_journal_status
    if not net then return end
    local active = self.records.active
    local value = string.format("%d:%d:%d:%d:%d", self.recent_discovery or 0,
        active and Catalog.milestone_index[active.id] or 0,
        active and math.ceil(active.remaining) or 0, #self.records.pending, #self.records.issues)
    if net:value() ~= value then net:set(value) end
end

function LumineJourney:CompleteAllForTest()
    local count = 0
    local reward = 0
    for _, milestone in ipairs(Data.MILESTONES) do
        if not self.done[milestone.id] then
            self.done[milestone.id] = true
            reward = reward + milestone.reward
            count = count + 1
        end
    end
    if count > 0 then
        self.insight = self.insight + reward
        if self.inst.components.talker ~= nil then
            self.inst.components.talker:Say("测试通道：完成 " .. count .. " 项见闻，获得 " .. reward .. " 点")
        end
        self.inst:PushEvent("lumine_milestone", {id = "test_all", insight = self.insight})
    end
    return count, reward
end

function LumineJourney:OnCycle()
    local cycle = TheWorld.state.cycles
    if cycle > self.last_cycle then
        self.days = self.days + 1
        self.last_cycle = cycle
        if self.days >= 1 then self:Complete("night") end
    end
end

function LumineJourney:CheckWorld()
    if self.inst:HasTag("playerghost") then return end
    self:ApplyMovementSkill()
    if TheWorld.state.iswinter then self:Complete("winter") end
    if TheWorld.state.isspring then self:Complete("spring") end
    if TheWorld.state.issummer then self:Complete("summer") end
    if TheWorld:HasTag("cave") then self:Complete("cave") end
    local platform = self.inst:GetCurrentPlatform()
    if platform ~= nil and platform:HasTag("boat") then self:Complete("sail") end
    if not self.done.lunar and WORLD_TILES.METEOR ~= nil then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        if TheWorld.Map:GetTileAtPoint(x, 0, z) == WORLD_TILES.METEOR then
            self:Complete("lunar")
        end
    end
    if not (self.done.pigking and self.done.ancient_altar and self.done.hermitcrab) then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        for _, entity in ipairs(TheSim:FindEntities(x, 0, z, 10, nil, {"INLIMBO"})) do
            local id = Data.LANDMARK_MILESTONES[entity.prefab]
            if id ~= nil and not self.done[id] then self:Complete(id) end
        end
    end
end

function LumineJourney:ApplyMovementSkill()
    local inst = self.inst
    local locomotor = inst.components.locomotor
    if locomotor == nil then return end
    local riding = inst.components.rider ~= nil and inst.components.rider:IsRiding()
    if not inst:HasTag("playerghost") and not riding and inst:GetCurrentPlatform() == nil
        and (self.skills.swift or self.active_element == "wind") then
        local bonus = (self.skills.swift and 0.07 or 0) + (self.active_element == "wind" and 0.05 or 0)
        locomotor:SetExternalSpeedMultiplier(inst, "lumine_speed_mod", 1 + bonus)
    else
        locomotor:RemoveExternalSpeedMultiplier(inst, "lumine_speed_mod")
    end
end

function LumineJourney:OnKilled(event)
    local victim = event ~= nil and event.victim or nil
    if victim == nil then return end
    -- Keep the last-hit path for one-shot kills; other participants are credited
    -- by the world death event even when another player or companion finishes.
    if Data.BOSS_MILESTONES[victim.prefab] then self:Complete(victim.prefab) end
    if self.skills.resolve and GetTime() - self.last_resolve >= 20
        and victim.components.health ~= nil and victim.components.health.maxhealth >= 100
        and victim.components.combat ~= nil then
        self.last_resolve = GetTime()
        self.inst.components.sanity:DoDelta(4)
    end
end

function LumineJourney:ParticipatedInBoss(victim)
    local hit_time = victim ~= nil and self.last_boss_hits[victim] or nil
    return hit_time ~= nil and GetTime() - hit_time <= 30
end

function LumineJourney:GetSpentInsight()
    local tree = self.inst.components.lumineskilltree
    local spent = tree and tree:GetExchangeSpent() or 0
    for _, skill in ipairs(Data.SKILLS) do
        if self.skills[skill.id] then spent = spent + skill.cost end
    end
    return spent
end

function LumineJourney:GetAvailableInsight()
    return math.max(0, self.insight - self:GetSpentInsight())
end

function LumineJourney:ApplySwordSkill()
    local combat = self.inst.components.combat
    local inventory = self.inst.components.inventory
    if combat == nil or inventory == nil then return end
    local item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local mods = combat.externaldamagemultipliers
    if self.skills.swordmaster and item ~= nil and item:HasTag("lumine_sword") then
        mods:SetModifier(self.inst, 1.08, "lumine_swordmaster")
    else
        mods:RemoveModifier(self.inst, "lumine_swordmaster")
    end
end

function LumineJourney:ApplySkills()
    local inst = self.inst
    if inst.components.hunger ~= nil then
        local mods = inst.components.hunger.burnratemodifiers
        if self.skills.rations then
            mods:SetModifier(inst, 0.9, "lumine_rations")
        else
            mods:RemoveModifier(inst, "lumine_rations")
        end
    end
    if inst.components.health ~= nil then
        local mods = inst.components.health.externalabsorbmodifiers
        if self.skills.ward then
            mods:SetModifier(inst, 0.06, "lumine_ward")
        else
            mods:RemoveModifier(inst, "lumine_ward")
        end
        if self.active_element == "geo" then
            mods:SetModifier(inst, 0.08, "lumine_geo_resolve")
        else
            mods:RemoveModifier(inst, "lumine_geo_resolve")
        end
    end
    if inst.components.moisture ~= nil then
        local mods = inst.components.moisture.waterproofnessmodifiers
        if self.skills.rainproof then
            mods:SetModifier(inst, 0.2, "lumine_rainproof")
        else
            mods:RemoveModifier(inst, "lumine_rainproof")
        end
    end
    self:ApplyMovementSkill()
    self:ApplySwordSkill()
end

function LumineJourney:CanResonate(element)
    if element == "none" then return true end
    local tree = self.inst.components.lumineskilltree
    return tree ~= nil and tree.elements[element] == true
end

function LumineJourney:SetActiveElement(next_element)
    if self.active_element == next_element then return false end
    if self.active_element == "geo" and self.inst.components.luminegeo ~= nil then
        self.inst.components.luminegeo:EndShield()
    end
    self.active_element = next_element
    self:SyncElement()
    self:ApplySkills()
    if self.inst.components.luminewind ~= nil then self.inst.components.luminewind:Sync() end
    if self.inst.components.luminegeo ~= nil then self.inst.components.luminegeo:Sync() end
    self.inst:PushEvent("lumine_element_resonated", {element = next_element or "none"})
    return true
end

function LumineJourney:Resonate(element)
    if self.inst:HasTag("playerghost") or not self:CanResonate(element) then return false end
    if element == "none" then return self:SetActiveElement(nil) end
    self.elements[element] = true
    return self:SetActiveElement(element)
end

function LumineJourney:RefreshElementPermission()
    if self.active_element ~= nil and not self:CanResonate(self.active_element) then
        self:SetActiveElement(nil)
    else
        self:SyncElement()
    end
end

function LumineJourney:SyncElement()
    local element = Elements[self.active_element]
    self.inst._lumine_element_active:set(element and element.wire or 0)
end

function LumineJourney:GetElementMask()
    local mask = 0
    for _, id in ipairs(Elements.order) do
        if Elements[id].playable and self:CanResonate(id) then mask = mask + Elements[id].bit end
    end
    return mask
end

function LumineJourney:GetSnapshot()
    local milestone_mask = 0
    local experienced_mask = 0
    for index, milestone in ipairs(Data.MILESTONES) do
        if self.done[milestone.id] then milestone_mask = milestone_mask + 2 ^ (index - 1) end
        if self.experienced[milestone.id] or self.done[milestone.id] then
            experienced_mask = experienced_mask + 2 ^ (index - 1)
        end
    end
    local skill_mask = 0
    for index, skill in ipairs(Data.SKILLS) do
        if self.skills[skill.id] then skill_mask = skill_mask + 2 ^ (index - 1) end
    end
    local element = Elements[self.active_element]
    local active = element and element.wire or 0
    local recording_index = 0
    if self.records.active then
        for index, milestone in ipairs(Data.MILESTONES) do
            if milestone.id == self.records.active.id then recording_index = index break end
        end
    end
    return milestone_mask, self.insight, skill_mask, self:GetElementMask(), self:GetAvailableInsight(),
        active, experienced_mask, recording_index
end

function LumineJourney:GetSummary()
    local count = 0
    for _, milestone in ipairs(Data.MILESTONES) do
        if self.done[milestone.id] then count = count + 1 end
    end
    local gear_count = 0
    for _, prefab in ipairs(Forge.ORDER) do if self.gear_records[prefab] then gear_count = gear_count + 1 end end
    return "旅行见闻 " .. self.insight .. "（可用 " .. self:GetAvailableInsight() .. "）\n"
        .. "探索 " .. count .. "/" .. #Data.MILESTONES .. "，装备记录 " .. gear_count .. "/" .. #Forge.ORDER
        .. "。右键查看旅行手册。"
end

function LumineJourney:OnSave()
    return {done = self.done, skills = self.skills, insight = self.insight,
        experienced = self.experienced, evidence_records = self.records:OnSave(),
        used_gear = self.used_gear, gear_records = self.gear_records,
        days = self.days, element_schema_version = 3,
        elements = self.elements, active_element = self.active_element or "none"}
end

function LumineJourney:OnLoad(data)
    if type(data) ~= "table" then return end
    self.done = data.done or {}
    self.experienced = data.experienced or {}
    self.skills = data.skills or {}
    self.insight = data.insight or 0
    -- Worlds saved in 0.37.0 may have witnessed experience chapters awaiting
    -- an item. Convert those to direct experience rewards exactly once.
    for _, entry in ipairs(Data.EXPERIENCE) do
        local id = entry.milestone.id
        if self.experienced[id] and not self.done[id] then
            self.done[id] = true
            self.insight = self.insight + entry.milestone.reward
        end
    end
    self.records:OnLoad(data.evidence_records, data.recording, data.record_returns)
    self.used_gear = data.used_gear or {}
    self.gear_records = data.gear_records or {}
    self:SyncGear()
    self.elements = data.elements or {wind = false, geo = false}
    self.elements.wind = self.elements.wind == true
    self.elements.geo = self.elements.geo == true
    self.elements.electro = self.elements.electro == true
    self.elements.dendro = self.elements.dendro == true
    self.elements.hydro = self.elements.hydro == true
    self.elements.pyro = self.elements.pyro == true
    self.elements.cryo = self.elements.cryo == true
    if (tonumber(data.element_schema_version) or 0) < 2 then
        for _, skill in ipairs(Data.ELEMENT_SKILLS) do
            if (skill.element == "风" or skill.element == "岩") and self.skills[skill.id] then
                self.elements[skill.element == "风" and "wind" or "geo"] = true
            end
        end
    end
    local active = data.active_element
    if active == "wind" or active == "geo" then self.elements[active] = true end
    if active == "none" then
        self.active_element = nil
    elseif active == "electro" or active == "dendro" or active == "hydro" or active == "pyro" or active == "cryo" then
        self.active_element = active
    else
        self.active_element = (active == "wind" and self.elements.wind and "wind")
            or (active == "geo" and self.elements.geo and "geo")
            or (self.elements.wind and "wind") or (self.elements.geo and "geo") or nil
    end
    self.days = data.days or 0
    self.last_cycle = TheWorld.state.cycles
    self.inst:DoTaskInTime(0, function() self:ApplySkills() end)
    self.inst:DoTaskInTime(0, function()
        self:SyncElement()
        if self.inst.components.luminewind ~= nil then self.inst.components.luminewind:Sync() end
        if self.inst.components.luminegeo ~= nil then self.inst.components.luminegeo:Sync() end
        if self.inst.components.luminepyro ~= nil then self.inst.components.luminepyro:RefreshResonance() end
        if self.inst.components.luminecryo ~= nil then self.inst.components.luminecryo:Refresh() end
    end)
end

return LumineJourney
