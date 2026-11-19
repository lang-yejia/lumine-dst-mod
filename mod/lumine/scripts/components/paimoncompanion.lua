local L = require("languages/lumine").For("components/paimoncompanion")
local C = require("paimon/config")
local Data = require("paimon/companion_data")
local Behaviour = require("paimon/behaviour")

local Companion = Class(function(self, inst)
    self.inst, self.record, self.lasttime = inst, nil, GetTime()
    self.task = inst:DoPeriodicTask(1,function() self:Tick() end)
end)

function Companion:Record()
    if self.record then return self.record end
    local world = TheWorld.components.paimonworld
    local userid = self.inst.userid
    if world and type(userid)=="string" and userid~="" then
        self.record = world:GetCompanionRecord(userid,self.loaded)
    else self.record = Data.Clean(self.loaded) end
    self.loaded = nil
    return self.record
end
function Companion:Changed()
    local r=self:Record()
    r.revision=r.revision+1
    local world=TheWorld.components.paimonworld
    if world and type(self.inst.userid)=="string" and self.inst.userid~="" then
        world.companion_records[self.inst.userid]=r
    end
end
function Companion:RefreshOrder()
    local r=self:Record()
    local cycle=math.floor((r.days+1e-8)/C.ORDER_DAYS)
    if not r.recipe or cycle>r.cycle then
        r.recipe=Data.Pick(r.days,r.recipe)
        r.cycle,r.done,r.rerolled=cycle,false,false
        self:Changed()
        self.announce_order=true
    end
    return r
end
function Companion:IsOrder(item)
    local r=self:RefreshOrder()
    return not r.done and item and item.prefab==r.recipe
end
function Companion:CompleteOrder(item)
    if not self:IsOrder(item) then return false end
    local r=self:Record()
    local recipe=Data.recipes[r.recipe]
    r.done,r.gold=true,r.gold+recipe.gold
    self:Changed() -- Commit before granting anything; repeated RPCs cannot pay twice.
    if self.inst.components.sanity then self.inst.components.sanity:DoDelta(recipe.sanity) end
    self.announce_order=nil
    local pet=self.inst._paimon
    if pet then pet.dialogue:Offer("order_thanks") end
    self:DeliverGold()
    self:Sync()
    return true
end
function Companion:Reroll()
    local r=self:RefreshOrder()
    if r.done or r.rerolled then return false end
    r.recipe,r.rerolled=Data.Pick(r.days,r.recipe),true
    self:Changed()
    self.announce_order=true
    self:Sync()
    return true
end

local function Give(owner,prefab,count)
    local inventory=owner.components.inventory
    if not inventory then return false end
    local item=SpawnPrefab(prefab)
    if not item then return false end
    if count>1 then item.components.stackable:SetStackSize(count) end
    -- Fill real slots/stacks first. Drop overflow at the owner, never grab the cursor.
    local accepted=inventory:CanAcceptCount(item)
    if accepted>=count then
        inventory:GiveItem(item,nil,owner:GetPosition())
        return true,false
    end
    if accepted>0 and item.components.stackable then
        inventory:GiveItem(item.components.stackable:Get(accepted),nil,owner:GetPosition())
    end
    inventory:DropItem(item,true,true)
    return true,true
end
function Companion:DeliverGold()
    local r=self:Record()
    if r.gold<=0 then return false end
    local count=math.min(r.gold,4)
    local given,dropped=Give(self.inst,"goldnugget",count)
    if not given then return false end
    r.gold=r.gold-count
    self:Changed()
    if dropped and self.inst._paimon then self.inst._paimon.dialogue:Offer("gift_drop") end
    return true
end
function Companion:PendingCakes()
    local r=self:Record()
    return math.max(0,math.floor((r.days+1e-8)/C.ANNIVERSARY_DAYS)-r.claimed)
end
function Companion:DeliverCake()
    if self:PendingCakes()<=0 then return false end
    local pet=self.inst._paimon
    if not pet or pet._dormant or self.inst:HasTag("playerghost")
        or self.inst._paimon_departing or self.inst:HasTag("INLIMBO")
        or (self.inst.components.health and self.inst.components.health:IsDead()) then return false end
    if not Give(self.inst,"lumine_paimon_cake",1) then return false end
    local r=self:Record()
    r.claimed=r.claimed+1
    r.cake_speech=true
    self:Changed()
    self:Sync()
    return true
end
function Companion:Sync()
    local pet=self.inst._paimon
    if not pet or not pet:IsValid() or not pet._companion_status then return end
    local journey=self.inst.components.luminejourney
    local text="带回旅途证物，请派蒙记录。记录后证物会返还。"
    if journey then
        local records=journey.records
        if records.active then
            local id=records.active.id
            local name=id
            for _,m in ipairs(require("lumine_progression").MILESTONES) do
                if m.id==id then name=m.name break end
            end
            text="正在记录："..name.."\n约 "..math.ceil(records.active.remaining).." 秒后完成。"
        end
        if #records.pending>0 then
            text=text.."\n待返还物品："..#records.pending.." 件（腾出背包空位）。"
        end
        if #records.issues>0 then
            text=text.."\n有 "..#records.issues.." 件证物的存档需要修复。"
        end
    end
    pet._companion_status:set(text)
    pet._order_can_reroll:set(false)
end
function Companion:Tick()
    local now=GetTime()
    local dt=math.max(0,now-self.lasttime)
    self.lasttime=now
    local pet=self.inst._paimon
    if not pet or not pet:IsValid() or pet._dormant or self.inst:HasTag("playerghost")
        or self.inst:HasTag("INLIMBO") or self.inst._paimon_departing
        or (self.inst.components.health and self.inst.components.health:IsDead()) then return end
    local r=self:Record()
    -- A newly bound/restored pet starts timing now; no offline or pre-bind catch-up.
    if self.active then r.days=r.days+dt/TUNING.TOTAL_DAY_TIME;self:Changed() end
    self.active=true
    -- Old pending gold is still delivered for migrated saves.
    self:DeliverGold()
    self:DeliverCake()
    self:Sync()
end
function Companion:TrySpeak()
    local pet=self.inst._paimon
    if not pet or pet._dormant
        or Behaviour.InCombat(pet,self.inst) or pet.dialogue:HasUrgentPending()
        or GetTime()<(pet._eating_until or 0) then return false end
    local r=self:RefreshOrder()
    if r.cake_speech then
        local line=require("paimon/dialogue_database").events.cake_gift.lines[1]
        if pet.dialogue:Speak(line.text,3,line.id) then
            r.cake_speech=false
            self:Changed()
            return true
        end
    end
    if pet.components.container:IsOpen() then return false end
    return false
end
function Companion:OnSave()
    return Data.Clean(self:Record())
end
function Companion:OnLoad(data)
    self.loaded=Data.Newer(self.record,data)
    self.record=nil
    -- The ledger also remembers progress when an ineligible character has no pet.
    self:Record()
    self.active=false
    self.lasttime=GetTime()
    self:Sync()
end
function Companion:OnRemoveFromEntity()
    if self.task then self.task:Cancel() end
end
return Companion
