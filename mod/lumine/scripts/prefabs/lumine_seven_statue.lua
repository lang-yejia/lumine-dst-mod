local Elements = require("lumine_statue_elements")
local assets = {
    Asset("ANIM", "anim/lumine_seven_statue.zip"),
    Asset("ATLAS", "images/inventoryimages/lumine_seven_statue-icon.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_seven_statue-icon.tex"),
}

local function LoopName(inst)
    local element = inst.fixed_element and Elements[inst.fixed_element]
    return element and element.use and (element.use .. "_loop")
        or element and "proximity_loop"
        or inst.near and "proximity_loop" or "idle"
end

local function SetLoop(inst)
    local name = LoopName(inst)
    if not inst.AnimState:IsCurrentAnimation(name) then
        inst.AnimState:PlayAnimation(name, true)
    end
end

local function OnNear(inst)
    inst.near = true
    if inst.fixed_element == nil then SetLoop(inst) end
end

local function OnFar(inst)
    inst.near = false
    if inst.fixed_element == nil then SetLoop(inst) end
end

local function Resonate(inst, element)
    if inst.fixed_element ~= element then return end
    local use = Elements[element].use
    if use then
        inst.AnimState:PlayAnimation("use_" .. use)
        inst.AnimState:PushAnimation(use .. "_loop", true)
    else
        SetLoop(inst)
    end
end

local function HasOffered(inst, element)
    return inst.fixed_element ~= nil and inst.fixed_element == element
end

local function UpdateTint(inst)
    local id = Elements.by_wire[inst._statue_element:value()]
    inst.AnimState:SetMultColour(Elements.Tint(id))
end

local function Register(inst, add)
    local index = TheWorld and TheWorld.components.luminestatueindex
    if index then index:Change(inst, add) end
end

local function Offer(inst, element, owner)
    if inst.fixed_element ~= nil then return false, "这座神像已固定元素，无法再供奉。" end
    if type(element) ~= "string" or not Elements.by_item["lumine_" .. element .. "_essence"] then return false end
    if not owner or not owner.userid or owner.userid == "" then return false end
    if inst.statue_owner and inst.statue_owner ~= owner.userid then
        return false, "只有建造者可以为这座神像供奉元素力。"
    end
    inst.statue_owner = owner.userid
    inst.fixed_element = element
    inst._statue_element:set(Elements[element].wire)
    UpdateTint(inst)
    Resonate(inst, element)
    Register(inst, true)
    return true
end

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()
    inst:Remove()
end

local function OnSave(inst, data)
    -- EntityScript passes the save table in and reads the return value as GUID references.
    data.fixed_version = 1
    data.element = inst.fixed_element
    data.owner = inst.statue_owner
end

local function OnLoad(inst, data)
    inst.fixed_element = Elements.LegacyElement(data)
    inst.statue_owner = data and data.fixed_version and type(data.owner) == "string" and data.owner ~= ""
        and data.owner or nil
    inst._statue_element:set(inst.fixed_element and Elements[inst.fixed_element].wire or 0)
    UpdateTint(inst)
    SetLoop(inst)
    Register(inst, true)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:SetDeploySmartRadius(1.5)
    MakeObstaclePhysics(inst, 0.55)
    inst.AnimState:SetBank("lumine_seven_statue")
    inst.AnimState:SetBuild("lumine_seven_statue")
    inst.AnimState:PlayAnimation("idle", true)
    inst:AddTag("structure")
    inst:AddTag("lumine_seven_statue")
    inst._statue_element = net_tinybyte(inst.GUID, "lumine.statue.element", "lumine_statue_element_dirty")
    inst:ListenForEvent("lumine_statue_element_dirty", UpdateTint)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.near = false
    inst:ListenForEvent("onbuilt", function(_, data)
        local builder = data and data.builder
        if not inst.fixed_element and builder and builder.userid and builder.userid ~= "" then
            inst.statue_owner = builder.userid
        end
    end)
    inst:ListenForEvent("onremove", function() Register(inst, false) end)
    inst.Resonate = Resonate
    inst.HasOffered = HasOffered
    inst.Offer = Offer
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst:AddComponent("inspectable")
    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(3, 4)
    inst.components.playerprox:SetOnPlayerNear(OnNear)
    inst.components.playerprox:SetOnPlayerFar(OnFar)
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(6)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    return inst
end

return Prefab("lumine_seven_statue", fn, assets),
    MakePlacer("lumine_seven_statue_placer", "lumine_seven_statue", "lumine_seven_statue", "idle")
