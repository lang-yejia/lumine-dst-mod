local L = require("languages/lumine").For("paimon/companion")
local C = require("paimon/config")
local M = {}
local NS = "DS_LUMINE_PAIMON"

local function CanUse(owner,pet)
    return owner and owner:IsValid() and pet and pet:IsValid() and owner._paimon==pet
        and pet.owner==owner and not pet._dormant and not pet:HasTag("INLIMBO")
        and not owner:HasTag("INLIMBO") and not owner:HasTag("playerghost")
        and not (owner.components.health and owner.components.health:IsDead())
        and owner:GetDistanceSqToInst(pet)<=C.BAG_OPEN_DISTANCE^2
end

function M.Open(owner,pet)
    if not CanUse(owner,pet) or not owner.components.paimoncompanion then return false end
    local state=owner.components.paimoncompanion
    state.wishes_pet=pet
    state:Sync()
    pet.components.container:Close(owner)
    M.NotifyOpen(owner,pet)
    return true
end

function M.InstallAction(G,hooks)
    local open=hooks.AddAction("PAIMON_WISHES","旅途记录",function(act)
        return M.Open(act.doer,act.target)
    end)
    open.priority=10
    open.distance=2
    open.rmb=true
    local function Collect(pet,owner,actions,right)
        if pet.prefab~="lumine_paimon" then return end
        local owned=pet._owner and pet._owner:value()==owner
            and not pet:HasTag("NOCLICK") and not owner:HasTag("playerghost")
        if right or not owned then
            for i=#actions,1,-1 do if actions[i]==G.ACTIONS.RUMMAGE then table.remove(actions,i) end end
        end
        if right and owned then actions[#actions+1]=open end
    end
    hooks.AddComponentAction("SCENE","container",Collect)
    hooks.AddComponentAction("USEITEM","inventoryitem",function(_,owner,pet,actions,right)
        if right then Collect(pet,owner,actions,true) end
    end)
    for _,sg in ipairs({"wilson","wilson_client"}) do
        hooks.AddStategraphActionHandler(sg,G.ActionHandler(open,"doshortaction"))
    end
end

function M.AttachPlayer(inst)
    if not TheWorld.ismastersim then return end
    inst:AddComponent("paimoncompanion")
    local save,load=inst.SaveForReroll,inst.LoadForReroll
    inst.SaveForReroll=function(owner,...)
        local data=save and save(owner,...) or {}
        data=data or {}
        data.paimoncompanion=owner.components.paimoncompanion:OnSave()
        return data
    end
    inst.LoadForReroll=function(owner,data,...)
        if load then load(owner,data,...) end
        owner.components.paimoncompanion:OnLoad(data and data.paimoncompanion)
    end
    inst:ListenForEvent("player_despawn",function() inst._paimon_departing=true end)
end

function M.InstallRPC(G,hooks)
    M.NotifyOpen=function(owner,pet)
        hooks.SendModRPCToClient(hooks.GetClientModRPC(NS,"open_wishes"),owner.userid,pet)
    end
    hooks.AddClientModRPCHandler(NS,"open_wishes",function(pet)
        local owner=G.ThePlayer
        if not owner or not owner:IsValid() or not owner.HUD or owner:HasTag("playerghost")
            or not pet or not pet:IsValid() or not pet._owner or pet._owner:value()~=owner then return end
        if owner._paimon_wishes then return end
        G.TheFrontEnd:PushScreen(G.require("screens/paimon_wishes")(owner,pet))
    end)
    hooks.AddModRPCHandler(NS,"companion_action",function(owner,action,pet)
        if action~="reroll" and action~="close" then return end
        local state=owner and owner.components.paimoncompanion
        if not state then return end
        if state.wishes_pet~=pet then return end
        if action=="close" then state.wishes_pet=nil;return end
        if not CanUse(owner,pet) then state.wishes_pet=nil;return end
        if owner:HasTag("busy") then return end
        -- All actions are rate-limited even if a client floods valid-looking RPCs.
        if GetTime()<(state.nextaction or 0) then return end
        state.nextaction=GetTime()+.5
        state:Reroll()
    end)
    M.Request=function(action,pet)
        hooks.SendModRPCToServer(hooks.GetModRPC(NS,"companion_action"),action,pet)
    end
end
return M
