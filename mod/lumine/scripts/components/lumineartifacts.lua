local Data = require("lumine_artifact_data")

local Artifacts = Class(function(self, inst)
    self.inst = inst
    self.owned = {}
    self.active = nil
    self.focus = nil
    self.pending = {}
    self.next_drop_token = 0
    self.last_hits = setmetatable({}, {__mode="k"})
    self.reader_added = false
    inst:DoTaskInTime(0, function() if inst:IsValid() then self:Sync() end end)
    inst:ListenForEvent("onattackother", function(_, event)
        local target = event ~= nil and event.target or nil
        if target ~= nil and target:IsValid()
            and (target:HasTag("monster") or target:HasTag("epic")) then
            self.last_hits[target] = GetTime()
        end
    end)
    inst:ListenForEvent("ms_becameghost", function() self:Apply() end)
    inst:ListenForEvent("ms_respawnedfromghost", function() self:Apply() end)
end)

function Artifacts:Sync()
    local bits = {}
    for _, piece in ipairs(Data.ALL) do
        bits[#bits+1] = self.owned[piece.id] and "1" or "0"
    end
    local active = self.active == "wilson" and "1"
        or self.active == "wickerbottom" and "2"
        or self.active == "warly" and "3" or "0"
    local focus = self.focus == "wilson" and "1" or self.focus == "wickerbottom" and "2"
        or self.focus == "warly" and "3" or "0"
    self.inst._lumine_artifacts:set(table.concat(bits)..":"..active..":"..focus)
end

function Artifacts:Count(set_id)
    local count = 0
    for _, piece in ipairs(Data.ALL) do
        if piece.set == set_id and self.owned[piece.id] then count=count+1 end
    end
    return count
end

function Artifacts:IsComplete(set_id)
    return self:Count(set_id) >= 4
end

function Artifacts:HasAll()
    for _, piece in ipairs(Data.ALL) do
        if not self.owned[piece.id] then return false end
    end
    return true
end

function Artifacts:HasActivePiece(slot_index)
    local inventory = self.inst.components.inventory
    local codex = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.LUMINE_RELIC_CODEX) or nil
    return codex ~= nil and codex.prefab == "lumine_relic_codex"
        and self.active ~= nil and self.owned[self.active.."_"..slot_index] == true
        and not self.inst:HasTag("playerghost")
end

function Artifacts:Participated(target)
    return target ~= nil and self.last_hits[target] ~= nil
        and GetTime() - self.last_hits[target] <= 30
end

function Artifacts:ReleasePending(id, token)
    local reservation = self.pending[id]
    if reservation ~= nil and (token == nil or reservation.token == token) then
        self.pending[id] = nil
    end
end

function Artifacts:SetFocus(set_id)
    if set_id ~= "none" and Data.BY_SET[set_id] == nil then return false end
    self.focus = set_id == "none" and nil or set_id
    self:Sync()
    return true
end

function Artifacts:RollDrop(victim, boss)
    local missing = {}
    local preferred = {}
    local cycle = TheWorld.state.cycles
    for _, piece in ipairs(Data.ALL) do
        local reservation = self.pending[piece.id]
        if reservation ~= nil and reservation.expires <= cycle then
            self.pending[piece.id] = nil
            reservation = nil
        end
        if not self.owned[piece.id] and reservation == nil then
            missing[#missing+1]=piece
            if piece.set == self.focus then preferred[#preferred+1]=piece end
        end
    end
    if #missing == 0 and boss then
        for _, piece in ipairs(Data.ALL) do
            if not self.owned[piece.id] then missing[#missing+1]=piece end
        end
    end
    if #missing == 0 or victim == nil or not victim:IsValid() then return nil end
    local pool = #preferred > 0 and math.random() < .7 and preferred or missing
    local piece = pool[math.random(#pool)]
    local item = SpawnPrefab(piece.prefab)
    if item == nil then return nil end
    self.next_drop_token = self.next_drop_token + 1
    item._lumine_relic_owneruserid = self.inst.userid
    item._lumine_relic_drop_token = self.next_drop_token
    self.pending[piece.id] = {token=self.next_drop_token, expires=cycle+3}
    local x,y,z = victim.Transform:GetWorldPosition()
    local angle = math.random()*2*PI
    item.Transform:SetPosition(x+math.cos(angle)*.5,y,z+math.sin(angle)*.5)
    return piece
end

function Artifacts:Collect(id)
    local piece = Data.BY_ID[id]
    if piece == nil or self.owned[id] then return false end
    self.owned[id] = true
    self:ReleasePending(id)
    if self.active == piece.set then self:Apply() end
    self:Sync()
    return true
end

function Artifacts:Activate(set_id)
    if set_id ~= "none" and Data.BY_SET[set_id] == nil then return false end
    if set_id ~= "none" and self:Count(set_id) < 1 then return false end
    local next_active = set_id == "none" and nil or set_id
    if self.active == next_active then return true end
    self.active = next_active
    self:Apply()
    self:Sync()
    if self.inst.components.talker ~= nil then
        self.inst.components.talker:Say(next_active and ("已激活"..Data.BY_SET[next_active].short.."的圣遗物")
            or "已收起圣遗物能力")
    end
    return true
end

function Artifacts:Apply()
    local inst = self.inst
    local inventory = inst.components.inventory
    local codex = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.LUMINE_RELIC_CODEX) or nil
    local enabled = codex ~= nil and codex.prefab == "lumine_relic_codex"
    local health = inst.components.health
    if health ~= nil then
        local mods = health.externalabsorbmodifiers
        if enabled and self:HasActivePiece(1) then mods:SetModifier(inst,.02,"lumine_relic_flower")
        else mods:RemoveModifier(inst,"lumine_relic_flower") end
    end
    local combat = inst.components.combat
    if combat ~= nil then
        local mods = combat.externaldamagemultipliers
        if enabled and self:HasActivePiece(2) then mods:SetModifier(inst,1.02,"lumine_relic_plume")
        else mods:RemoveModifier(inst,"lumine_relic_plume") end
    end
    local hunger = inst.components.hunger
    if hunger ~= nil then
        local mods = hunger.burnratemodifiers
        if enabled and self:HasActivePiece(3) then mods:SetModifier(inst,.97,"lumine_relic_sands")
        else mods:RemoveModifier(inst,"lumine_relic_sands") end
    end
    local locomotor = inst.components.locomotor
    if locomotor ~= nil then
        if enabled and self:HasActivePiece(5) then
            locomotor:SetExternalSpeedMultiplier(inst,"lumine_relic_circlet",1.02)
        else
            locomotor:RemoveExternalSpeedMultiplier(inst,"lumine_relic_circlet")
        end
    end

    inst:RemoveTag("bookbuilder")
    inst:RemoveTag("masterchef")
    inst:RemoveTag("professionalchef")
    inst:RemoveTag("expertchef")
    if self.reader_added and inst.components.reader ~= nil then
        inst:RemoveComponent("reader")
        self.reader_added = false
    end
    if not enabled or inst:HasTag("playerghost") or self.active == nil or not self:IsComplete(self.active) then
        inst:PushEvent("unlockrecipe")
        return
    end
    if self.active == "wickerbottom" then
        inst:AddTag("bookbuilder")
        if inst.components.reader == nil then
            inst:AddComponent("reader")
            self.reader_added = true
        end
    elseif self.active == "warly" then
        inst:AddTag("masterchef")
        inst:AddTag("professionalchef")
        inst:AddTag("expertchef")
    end
    inst:PushEvent("unlockrecipe")
end

function Artifacts:OnSave()
    return {schema=4, owned=self.owned, active=self.active or "none",
        focus=self.focus or "none", pending=self.pending, next_drop_token=self.next_drop_token}
end

function Artifacts:OnLoad(data)
    if data == nil then return end
    if data.schema == 2 or data.schema == 3 or data.schema == 4 then
        for id,value in pairs(data.owned or {}) do
            if value and Data.BY_ID[id] ~= nil then self.owned[id]=true end
        end
        if Data.BY_SET[data.active] ~= nil and self:Count(data.active) > 0 then
            self.active=data.active
        end
        if data.schema == 4 then
            if Data.BY_SET[data.focus] ~= nil then self.focus=data.focus end
            self.pending=data.pending or {}
            self.next_drop_token=data.next_drop_token or 0
        end
    end
    self.inst:DoTaskInTime(0, function()
        if self.inst:IsValid() then self:Apply() self:Sync() end
    end)
end

return Artifacts
