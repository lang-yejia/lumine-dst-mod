local L = require("languages/lumine").For("paimon/guide")
local C = require("paimon/config")
local Data = require("paimon/guide_data")
local Behaviour = require("paimon/behaviour")
local M = {}
local TAG = "paimon_guide_landmark"

function M.Install(add)
    for prefab in pairs(Data.prefabs) do
        add(prefab,function(inst)
            inst:AddTag(TAG)
            local group = Data.prefabs[inst.prefab]
            local teleporter = inst.components.teleporter
            if TheWorld.ismastersim and group and group.id=="wormhole" and teleporter then
                local previous = teleporter.onActivateByOther
                teleporter.onActivateByOther = function(exit,source,doer,...)
                    -- 只记录实际接收到的旅客；入口处预览、路过或投掷物品不算穿越。
                    M.TraversedWormhole(doer,source,exit)
                    if previous then return previous(exit,source,doer,...) end
                end
            end
        end)
    end
end

local function Record(pet)
    local owner = pet.owner
    local world = TheWorld.components.paimonworld
    if not owner or not world or type(owner.userid)~="string" or owner.userid=="" then return end
    if not pet._guide_record then
        pet._guide_record = world:GetGuideRecord(owner.userid,pet.guide_seen)
        pet.guide_seen = nil
    end
    return pet._guide_record
end

local function Key(target, group)
    -- 可移动随从信物按种类只提示一次；固定地点按分片和位置去重，不使用会变化的 GUID。
    if group.mobile then return "mobile/"..group.id end
    local x,_,z = target.Transform:GetWorldPosition()
    local shard = TheShard and TheShard:GetShardId() or (TheWorld:HasTag("cave") and "cave" or "surface")
    return tostring(shard).."/"..group.id.."/"..math.floor(x*2+.5)..","..math.floor(z*2+.5)
end

local function Visible(pet,target)
    local owner = pet.owner
    if not target or not target:IsValid() or not Data.prefabs[target.prefab]
        or target:HasTag("INLIMBO") or target:HasTag("NOCLICK")
        or not target.entity:IsVisible() or owner:GetDistanceSqToInst(target)>C.GUIDE_RADIUS^2 then return false end
    local item = target.components.inventoryitem
    if item and item.owner then return false end
    -- 向导能力可感知附近未揭雾/屏幕外的地点，不依赖玩家地图或镜头。
    -- entity 可见性用于排除被隐藏的实体；不会调用地图揭雾接口。
    return true
end

function M.TraversedWormhole(owner,source,exit)
    local pet = owner and owner._paimon
    if not pet or not pet:IsValid() then return end
    local record = Record(pet)
    if not record then return end
    for _,target in pairs({source,exit}) do
        local group = target and target:IsValid() and Data.prefabs[target.prefab]
        if group and group.id=="wormhole" then
            local key = Key(target,group)
            if not record.seen[key] and record.count<C.GUIDE_MAX_SITES then
                record.seen[key],record.count = true,record.count+1
            end
        end
    end
    -- 不让旧位置的候选或镜头切换时的屏幕判定触发提示。
    pet._guide_pending,pet._guide_look = nil,nil
    local teleporter = exit.components.teleporter
    pet._guide_arrival_until = GetTime()+math.max(0,teleporter and teleporter.travelarrivetime or 0)+1
    pet._guide_scan_at = pet._guide_arrival_until
end

local function Available(pet)
    local owner = pet.owner
    return owner and owner:IsValid() and not pet._dormant and not owner:HasTag("playerghost")
        and GetTime()>=(pet._guide_arrival_until or 0)
        and not (owner.components.health and owner.components.health:IsDead())
        and pet:GetDistanceSqToInst(owner)<=C.TELEPORT_DISTANCE^2
end

function M.Scan(pet)
    local previous = pet._guide_pending
    pet._guide_pending = nil
    if not Available(pet) then return end
    local record = Record(pet)
    if not record or record.count>=C.GUIDE_MAX_SITES or GetTime()<record.nexttime then return end
    local owner = pet.owner
    local x,y,z = owner.Transform:GetWorldPosition()
    local nearest, best, bestkey
    for _,target in ipairs(TheSim:FindEntities(x,y,z,C.GUIDE_RADIUS,{TAG},{"INLIMBO","FX","NOCLICK"})) do
        local group = Data.prefabs[target.prefab]
        if group then
            local key = Key(target,group)
            if not record.seen[key] and Visible(pet,target) then
                local distance = owner:GetDistanceSqToInst(target)
                if not best or distance<best or (distance==best and key<bestkey) then
                    nearest,best,bestkey = target,distance,key
                end
            end
        end
    end
    if nearest then
        pet._guide_pending = previous and previous.key==bestkey and previous or {key=bestkey}
        pet._guide_pending.target = nearest
        pet._guide_pending.expires = GetTime()+C.GUIDE_SCAN_INTERVAL+1
    end
end

function M.Poll(pet)
    if GetTime()<(pet._guide_scan_at or 0) then return end
    pet._guide_scan_at = GetTime()+C.GUIDE_SCAN_INTERVAL
    M.Scan(pet)
end

function M.HasPending(pet)
    return pet._guide_pending~=nil and GetTime()<=pet._guide_pending.expires
end

function M.ReceiveVisibility(owner,token,outside)
    local pet = owner and owner._paimon
    local pending = pet and pet._guide_pending
    if type(outside)~="boolean" or not pending or pending.token~=token
        or not Available(pet) or GetTime()>pending.expires or not Visible(pet,pending.target) then return end
    local group = Data.prefabs[pending.target.prefab]
    if Key(pending.target,group)~=pending.key then return end
    if outside then
        pending.checked = GetTime()
    else
        -- 已在镜头里，安静记为见过；以后转开镜头也不补报这一地点。
        local record = Record(pet)
        if record and not record.seen[pending.key] and record.count<C.GUIDE_MAX_SITES then
            record.seen[pending.key],record.count = true,record.count+1
        end
        pet._guide_pending = nil
    end
end

function M.TrySpeak(pet)
    local pending = pet._guide_pending
    if not pending or not Available(pet) then return false end
    local record = Record(pet)
    if not record or GetTime()>pending.expires or record.seen[pending.key]
        or not Visible(pet,pending.target) then pet._guide_pending=nil; return false end
    local owner = pet.owner
    local action = owner:GetBufferedAction()
    if record.count>=C.GUIDE_MAX_SITES or GetTime()<record.nexttime
        or Behaviour.InCombat(pet,owner) or pet.components.container:IsOpen()
        or (action and action.target==pet) or GetTime()<(pet._eating_until or 0)
        or pet.dialogue:HasUrgentPending() then return false end
    local group = Data.prefabs[pending.target.prefab]
    if Key(pending.target,group)~=pending.key then pet._guide_pending=nil; return false end
    if M.RequestVisibility and (not pending.checked or GetTime()-pending.checked>1) then
        if not pending.requested or GetTime()-pending.requested>=1 then
            -- 同一候选重发时复用令牌；否则往返延迟超过一秒的应答会永远落后一次。
            -- 五秒后换新令牌，仍丢弃过旧应答；换地点时 pending 本身会重建。
            if not pending.token or GetTime()-(pending.token_at or 0)>5 then
                pet._guide_seq = (pet._guide_seq or 0)+1
                pending.token,pending.token_at = pet._guide_seq,GetTime()
            end
            pending.requested = GetTime()
            local x,_,z = pending.target.Transform:GetWorldPosition()
            M.RequestVisibility(owner,pending.token,x,z)
        end
        -- RPC 正常异步；本地测试也允许同步应答。
        if pet._guide_pending~=pending or not pending.checked or GetTime()-pending.checked>1 then return false end
    end
    if not pet.dialogue:CanSpeak(2,"guide") then return false end
    local choices,recent = {},{}
    for _,id in ipairs(pet.dialogue.recent) do recent[id]=true end
    for _,line in ipairs(group.lines) do if not recent[line.id] then choices[#choices+1]=line end end
    if #choices==0 then choices=group.lines end
    local line = choices[math.random(#choices)]
    if not pet.dialogue:Speak(line.text,2,line.id,"guide") then return false end
    -- 只有确实说出口才消耗首次提示；危险、开包、离开范围不会写入假发现。
    record.seen[pending.key],record.count,record.nexttime = true,record.count+1,GetTime()+C.GUIDE_GAP
    M.Point(pet,pending.target)
    pet._guide_pending = nil
    return true
end

function M.Point(pet,target)
    pet._guide_look = {target=target,untiltime=GetTime()+C.GUIDE_POINT_TIME}
    pet._guide_catchup_until = GetTime()+C.GUIDE_POINT_TIME+C.GUIDE_CATCHUP_TIME
    pet.Physics:Stop()
    pet:ForceFacePoint(target.Transform:GetWorldPosition())
    if M.Notify and pet.owner and type(pet.owner.userid)=="string" then
        local x,_,z = target.Transform:GetWorldPosition()
        M.Notify(pet.owner,x,z)
    end
end

function M.OnSave(pet)
    local record = Record(pet)
    return record and record.seen or pet.guide_seen
end
function M.OnLoad(pet,seen)
    pet._guide_record,pet._guide_pending,pet._guide_look = nil,nil,nil
    pet._guide_scan_at = nil
    pet._guide_catchup_until = nil
    pet._guide_arrival_until = nil
    pet.guide_seen = type(seen)=="table" and seen or nil
end

-- 控制台主动预览附近最近地点，不清空发现历史、不生成物品，也不写入新发现。
function M.Preview(owner)
    local pet = owner and owner._paimon
    if not pet or not pet:IsValid() or not Available(pet) then return false,L(1, "没有可用的派蒙") end
    local action = owner:GetBufferedAction()
    if Behaviour.InCombat(pet,owner) or pet.components.container:IsOpen()
        or (action and action.target==pet) or GetTime()<(pet._eating_until or 0) then
        return false,L(2, "请等战斗、进食或开包结束再预览")
    end
    local x,y,z = owner.Transform:GetWorldPosition()
    local nearest,best
    for _,target in ipairs(TheSim:FindEntities(x,y,z,C.GUIDE_RADIUS,{TAG},{"INLIMBO","FX","NOCLICK"})) do
        if Visible(pet,target) then
            local d = owner:GetDistanceSqToInst(target)
            if not best or d<best then nearest,best=target,d end
        end
    end
    if not nearest then return false,L(3, "48 单位内没有支持的可见地点实体") end
    local group = Data.prefabs[nearest.prefab]
    pet.components.talker:Say(group.lines[1].text,5,true)
    pet._guide_pending,pet._guide_scan_at = nil,GetTime()+6
    pet.dialogue.speaking_until,pet.dialogue.nextspeech = GetTime()+5,GetTime()+6
    M.Point(pet,nearest)
    return true,L(4, "预览：")..group.name..L(5, "；不更改首次发现记录")
end

function M.InstallDebug(G)
    rawset(G,"c_paimonguide",function()
        if not G.TheWorld or not G.TheWorld.ismastersim then
            print(L(6, "派蒙预览：请使用远程/服务器控制台执行 c_paimonguide()"))
            return
        end
        local owner = G.ConsoleCommandPlayer and G.ConsoleCommandPlayer() or G.ThePlayer
        local _,message = M.Preview(owner)
        print(L(7, "派蒙预览：")..message)
    end)
end

function M.InstallRPC(G,hooks)
    local namespace = "DS_LUMINE_PAIMON"
    M.Notify = function(owner,x,z)
        hooks.SendModRPCToClient(hooks.GetClientModRPC(namespace,"guide"),owner.userid,x,z)
    end
    M.RequestVisibility = function(owner,token,x,z)
        hooks.SendModRPCToClient(hooks.GetClientModRPC(namespace,"guide_check"),owner.userid,token,x,z)
    end
    hooks.AddModRPCHandler(namespace,"guide_visibility",M.ReceiveVisibility)
    hooks.AddClientModRPCHandler(namespace,"guide_check",function(token,x,z)
        if type(token)~="number" or type(x)~="number" or type(z)~="number" or x~=x or z~=z
            or math.abs(x)>100000 or math.abs(z)>100000 then return end
        local owner = G.ThePlayer
        -- Only the server requests visibility for an owned pet; no local scope check.
        if not owner or not owner:IsValid() or owner:HasTag("playerghost") or not owner.HUD then return end
        local geometry = G.require("paimon/guide_indicator_math")
        local _,y = owner.Transform:GetWorldPosition()
        local tx,ty = G.TheSim:GetScreenPos(x,y,z)
        local w,h = G.TheSim:GetScreenSize()
        hooks.SendModRPCToServer(hooks.GetModRPC(namespace,"guide_visibility"),token,geometry.Outside(tx,ty,w,h))
    end)
    hooks.AddClientModRPCHandler(namespace,"guide",function(x,z)
        if type(x)~="number" or type(z)~="number" or x~=x or z~=z
            or math.abs(x)>100000 or math.abs(z)>100000 then return end
        local owner = G.ThePlayer
        if owner and owner:IsValid() and not owner:HasTag("playerghost") and owner.HUD then
            G.require("paimon/guide_ui").Show(owner,x,z)
        end
    end)
end
return M
