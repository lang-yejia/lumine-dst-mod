local L = require("languages/lumine").For("paimon/tracking")
local C=require("paimon/config")
local Guide=require("paimon/guide")
local Behaviour=require("paimon/behaviour")
local M={}
local function Visible(pet,target)
    return target and target:IsValid() and target.prefab=="dirtpile"
        and not target:HasTag("INLIMBO") and target.entity:IsVisible()
        and pet.owner:GetDistanceSqToInst(target)<=C.GUIDE_RADIUS^2
end
local function Available(pet)
    local owner=pet.owner
    return owner and owner:IsValid() and not pet._dormant and not owner:HasTag("playerghost")
        and not (owner.components.health and owner.components.health:IsDead())
        and pet:GetDistanceSqToInst(owner)<=C.TELEPORT_DISTANCE^2
end
local function Nearest(pet,excluded)
    local owner=pet.owner
    local x,y,z=owner.Transform:GetWorldPosition()
    local best,distance
    for _,target in ipairs(TheSim:FindEntities(x,y,z,C.GUIDE_RADIUS,{"dirtpile"},{"INLIMBO","FX","NOCLICK"})) do
        if Visible(pet,target) and not (excluded and excluded[target]) then
            local d=owner:GetDistanceSqToInst(target)
            if d<=C.GUIDE_RADIUS^2 and (not distance or d<distance) then best,distance=target,d end
        end
    end
    return best
end
local function PointNext(pet)
    local target=pet._track_chain_target
    if not target then return false end
    if not Available(pet) or not Visible(pet,target) then pet._track_chain_target=nil;return false end
    if Behaviour.InCombat(pet,pet.owner) then return false end
    pet._track_seen=pet._track_seen or setmetatable({},{__mode="k"})
    pet._track_seen[target]=true
    pet._track_chain_target,pet._track_pending=nil,nil
    pet._track_passive_at=GetTime()+C.GUIDE_GAP
    Guide.Point(pet,target)
    return true
end
function M.Continue(pet,previous)
    if not Available(pet) then return end
    -- Only a newly spawned pile can continue this investigation, not another hunt.
    pet._track_chain_target=Nearest(pet,previous)
    PointNext(pet)
end
function M.Install(add)
    add("dirtpile",function(inst)
        if not TheWorld.ismastersim then return end
        local investigate=inst.OnInvestigated
        if not investigate then return end
        local function Investigated(pile,doer,...)
            local pet=doer and doer._paimon
            local previous
            if pet and pet:IsValid() and Available(pet) then
                local x,y,z=doer.Transform:GetWorldPosition()
                previous={}
                for _,target in ipairs(TheSim:FindEntities(x,y,z,C.GUIDE_RADIUS,{"dirtpile"})) do previous[target]=true end
            end
            local result=investigate(pile,doer,...)
            if previous and pet:IsValid() then
                -- Vanilla hunter creates the next pile while investigating; inspect
                -- after its callback finishes without advancing or replacing the hunt.
                M.Continue(pet,previous)
            end
            return result
        end
        inst.OnInvestigated=Investigated
        inst.components.activatable.OnActivate=Investigated
    end)
end
function M.Poll(pet)
    if GetTime()<(pet._track_scan_at or 0) then return end
    pet._track_scan_at=GetTime()+C.GUIDE_SCAN_INTERVAL
    pet._track_seen=pet._track_seen or setmetatable({},{__mode="k"})
    if PointNext(pet) then return end
    if Available(pet) then pet._track_pending=Nearest(pet,pet._track_seen) else pet._track_pending=nil end
end
function M.TrySpeak(pet)
    local target=pet._track_pending
    if not target or not target:IsValid() or not Available(pet)
        or pet.owner:GetDistanceSqToInst(target)>C.GUIDE_RADIUS^2
        or not target.entity:IsVisible() or target:HasTag("INLIMBO") then return false end
    if GetTime()<(pet._track_passive_at or 0) or Behaviour.InCombat(pet,pet.owner)
        or pet.components.container:IsOpen() or pet.dialogue:HasUrgentPending()
        or GetTime()<(pet._eating_until or 0) then return false end
    if not pet.dialogue:Speak(L(1, "旅行者，那边有可疑的土堆！要不要看看是什么动物留下的？"),2,"tracking:found","guide") then return false end
    pet._track_seen[target]=true
    pet._track_pending=nil
    pet._track_passive_at=GetTime()+C.GUIDE_GAP
    Guide.Point(pet,target)
    return true
end
return M
