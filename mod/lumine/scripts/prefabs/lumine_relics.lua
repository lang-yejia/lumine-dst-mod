local Data = require("lumine_artifact_data")
local prefabs = {}

for _, piece in ipairs(Data.ALL) do
    local name = piece.prefab
    local animation = piece.id
    local atlas = "images/inventoryimages/"..name..".xml"
    local function OnRemoved(inst)
        if inst._lumine_relic_owneruserid == nil then return end
        for _, player in ipairs(AllPlayers) do
            if player.userid == inst._lumine_relic_owneruserid
                and player.components.lumineartifacts ~= nil then
                player.components.lumineartifacts:ReleasePending(piece.id,inst._lumine_relic_drop_token)
                break
            end
        end
    end
    local assets = {
        Asset("ANIM", "anim/lumine_relic_icons.zip"),
        Asset("ATLAS", atlas),
        Asset("IMAGE", "images/inventoryimages/"..name..".tex"),
    }
    local function fn()
        local inst=CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("lumine_relic_icons")
        inst.AnimState:SetBuild("lumine_relic_icons")
        inst.AnimState:PlayAnimation(animation,true)
        inst.AnimState:SetScale(1.25,1.25)
        inst:AddTag("lumine_relic")
        MakeInventoryFloatable(inst,"small",.1,.7)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname=atlas
        inst.components.inventoryitem.imagename=name
        inst.OnSave=function(self,data)
            data.owneruserid=self._lumine_relic_owneruserid
            data.token=self._lumine_relic_drop_token
        end
        inst.OnLoad=function(self,data)
            if data ~= nil then
                self._lumine_relic_owneruserid=data.owneruserid
                self._lumine_relic_drop_token=data.token
            end
        end
        inst:ListenForEvent("onremove",OnRemoved)
        MakeHauntableLaunch(inst)
        return inst
    end
    prefabs[#prefabs+1]=Prefab(name,fn,assets)
end

return unpack(prefabs)
