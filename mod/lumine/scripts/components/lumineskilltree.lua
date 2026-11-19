local Nodes = require("skilltree/lumine_nodes")
local State = require("skilltree/lumine_state")
local Effects = require("skilltree/lumine_effects")
local Exchange = require("skilltree/lumine_exchange")

local function SavedInteger(value)
    return type(value) == "number" and value >= 0 and value < math.huge and math.floor(value) or 0
end

local Tree = Class(function(self, inst)
    self.inst = inst
    self.data = State.New()
    self.elements, self.recipes, self.features = {}, {}, {}
    self.exchange_count, self.exchange_spent = 0, 0
    if inst.xpgeneration_task then
        inst.xpgeneration_task:Cancel()
        inst.xpgeneration_task = nil
    end
    if inst.components.experiencecollector then inst:RemoveComponent("experiencecollector") end
    inst:ListenForEvent("lumine_milestone", function() self:SyncExchange() end)
    inst:DoTaskInTime(0, function() self:Initialize() end)
end)

function Tree:OnLoad(data)
    self.saved = data
end

function Tree:OnSave()
    if not self.ready then return self.saved end
    local saved = State.Save(self.data)
    saved.version = 2
    saved.exchange_count, saved.exchange_spent = self.exchange_count, self.exchange_spent
    return saved
end

function Tree:Initialize()
    if self.ready then return true end
    local owner = self.inst
    if self.saved == nil and (owner.userid == nil or owner.userid == "") then return end
    local journey = owner.components.luminejourney
    local saved = self.saved
    if saved then
        State.Load(self.data, saved)
        self.exchange_count = SavedInteger(saved.exchange_count)
        self.exchange_spent = SavedInteger(saved.exchange_spent)
    else
        self.exchange_count, self.exchange_spent = 0, 0
        State.MigrateElements(self.data, journey.elements, journey.active_element)
    end
    self.saved, self.ready = nil, true
    self:SyncExchange()
    self:Apply()
    return true
end

function Tree:RestoreForReroll(record)
    if record.journey then self.inst.components.luminejourney:OnLoad(record.journey) end
    self.saved, self.ready = record.tree or {}, nil
    self:Initialize()
end

function Tree:Apply()
    local owner = self.inst
    local had_geo = self.elements.geo
    for _, node in ipairs(Nodes.nodes) do
        Effects.Apply(self, node, self.data:IsActivated(node.id, Nodes.character))
    end
    if had_geo and not self.elements.geo then owner.components.luminegeo:EndField() end
    owner.components.luminejourney:RefreshElementPermission()
    self:Sync()
end

function Tree:Sync()
    self.inst._lumine_skilltree:set(self.data:EncodeSkillTreeData(Nodes.character, true))
    self.inst:PushEvent("onsetskillselection_server")
    self.inst:PushEvent("lumine_skilltree_dirty")
end

function Tree:GetExchangeSpent()
    return self.exchange_spent
end

function Tree:SyncExchange()
    if not self.ready then return end
    local available = self.inst.components.luminejourney:GetAvailableInsight()
    local snapshot = Exchange.Encode(available, self.exchange_count, self:GetNextExchangeCost())
    local net = self.inst._lumine_insight_exchange
    if net:value() ~= snapshot then
        net:set(snapshot)
        self.inst:PushEvent("lumine_insight_exchange_dirty")
    end
end

function Tree:Learn(id)
    if not self.ready or self.inst:HasTag("playerghost") or not State.CanLearn(self.data, id) then return false end
    if not self.data:ActivateSkill(id, Nodes.character) then return false end
    self:Apply()
    return true
end

function Tree:Reset()
    if not self.ready or self.inst:HasTag("playerghost") or not self.data:GetActivatedSkills(Nodes.character) then
        return false
    end
    self.data:RespecSkills(Nodes.character)
    self:Apply()
    return true
end

function Tree:GetNextExchangeCost()
    local points = self.data:GetPointsForSkillXP(self.data:GetSkillXP(Nodes.character))
    if TUNING.SKILL_THRESHOLDS[points + 1] == nil then return nil end
    return Exchange.Cost(self.exchange_count + 1), State.XPForPoints(points + 1)
end

function Tree:ExchangeInsight(exchange_number)
    if not self.ready or self.inst:HasTag("playerghost") or exchange_number ~= self.exchange_count + 1 then
        return false
    end
    local cost, target_xp = self:GetNextExchangeCost()
    local journey = self.inst.components.luminejourney
    if not cost or journey:GetAvailableInsight() < cost then return false end
    local xp = self.data:GetSkillXP(Nodes.character)
    if not self.data:AddSkillXP(target_xp - xp, Nodes.character) then return false end
    self.exchange_spent = self.exchange_spent + cost
    self.exchange_count = exchange_number
    self:SyncExchange()
    self:Sync()
    self.inst:PushEvent("lumine_insight_exchanged")
    return true
end

return Tree
