local Config = require("aranara_hut/config")
local Threat = require("aranara_hut/threat")

local assets = {
    Asset("ANIM", "anim/lumine_aranara_hut.zip"),
    Asset("ANIM", "anim/lumine_aranara_hut_fuel_fx.zip"),
    Asset("ANIM", "anim/ui_chest_3x1.zip"),
    Asset("ATLAS", "images/inventoryimages/lumine_aranara_hut-icon.xml"),
    Asset("IMAGE", "images/inventoryimages/lumine_aranara_hut-icon.tex"),
}
local prefabs = {"lumine_aranara", "lumine_aranara_hut_fuel_fx", "boards", "cutstone", "rope", "livinglog"}

local function TotalTime(inst)
    local total = math.max(0, inst.remaining)
    local container = inst.components.container
    for slot = 1, Config.SLOTS do
        local item = container:GetItemInSlot(slot)
        if Config.IsFuel(item) and item.components.fuel ~= nil then
            local stack = item.components.stackable
            total = total + item.components.fuel.fuelvalue
                * (stack ~= nil and stack:StackSize() or 1) * Config.FUEL_TIME_MULTIPLIER
        end
    end
    return total
end

local function Sync(inst)
    inst._aranara_time:set(math.max(0, inst.remaining))
    local total = TotalTime(inst)
    inst._aranara_total_time:set(total)
    local fuelled = total > 0
    if inst._fuel_fx == nil or not inst._fuel_fx:IsValid() then
        inst._fuel_fx = SpawnPrefab("lumine_aranara_hut_fuel_fx")
        if inst._fuel_fx ~= nil then
            inst._fuel_fx.entity:SetParent(inst.entity)
            inst._fuelled_fx = nil
        end
    end
    if inst._fuel_fx ~= nil and inst._fuelled_fx ~= fuelled then
        inst._fuelled_fx = fuelled
        inst._fuel_fx.AnimState:PlayAnimation(fuelled and "lit" or "empty", true)
    end
    local count = 0
    for _, worker in pairs(inst.workers) do
        if worker ~= nil and worker:IsValid() then count = count + 1 end
    end
    inst._aranara_workers:set(count)
    inst._aranara_status:set(TheWorld.state.iswinter and 1 or inst.danger and 2
        or GetTime() < inst.safe_after and 3 or total <= 0 and 4 or 0)
    local active = inst.remaining > 0
    if inst._active ~= active then
        inst._active = active
        if not inst._door_open then
            inst.AnimState:PlayAnimation(active and "active" or "idle", true)
        end
        inst.Light:Enable(active)
        inst.AnimState:SetLightOverride(active and .08 or 0)
    end
end

local function RetreatWorkers(inst)
    for _, worker in pairs(inst.workers) do
        if worker ~= nil and worker:IsValid() then worker:Retreat() end
    end
end

local function StopWorkers(inst)
    for slot, worker in pairs(inst.workers) do
        if worker ~= nil and worker:IsValid() then worker:Despawn() end
        inst.workers[slot] = nil
    end
end

local function OnRemoved(inst)
    StopWorkers(inst)
    if inst._fuel_fx ~= nil and inst._fuel_fx:IsValid() then
        inst._fuel_fx:Remove()
    end
end

local function EnsureWorkers(inst)
    for slot = 1, Config.WORKERS do
        local worker = inst.workers[slot]
        if worker == nil or not worker:IsValid() then
            worker = SpawnPrefab("lumine_aranara")
            if worker ~= nil then
                worker:SetHome(inst, slot)
                inst.workers[slot] = worker
            end
        end
    end
end

local function ConsumeFuel(inst)
    local container = inst.components.container
    for slot = 1, Config.SLOTS do
        local item = container:GetItemInSlot(slot)
        if Config.IsFuel(item) and item.components.fuel ~= nil then
            inst._consuming_fuel = true
            local taken = container:RemoveItem(item, false)
            inst._consuming_fuel = false
            if taken ~= nil then
                local seconds = taken.components.fuel.fuelvalue * Config.FUEL_TIME_MULTIPLIER
                taken.components.fuel:Taken(inst)
                taken:Remove()
                inst.remaining = inst.remaining + seconds
                return true
            end
        end
    end
    return false
end

local function Tick(inst)
    if TheWorld.state.iswinter or inst.danger or GetTime() < inst.safe_after then
        Sync(inst)
        return
    end
    if inst.remaining > 0 then inst.remaining = inst.remaining - Config.TICK end
    if inst.remaining <= 0 then
        inst.remaining = 0
        ConsumeFuel(inst)
    end
    if inst.remaining > 0 then EnsureWorkers(inst) else StopWorkers(inst) end
    Sync(inst)
end

local function CheckSafety(inst)
    if TheWorld.state.iswinter then
        RetreatWorkers(inst)
    else
        local danger = Threat.NearHutOrWorker(inst)
        if danger then
            inst.safe_after = GetTime() + Threat.CALM_DELAY
            RetreatWorkers(inst)
        end
        inst.danger = danger
    end
    Sync(inst)
end

local function OnHammered(inst)
    StopWorkers(inst)
    inst.components.container:Close()
    inst.components.container:DropEverything()
    for _, prefab in ipairs({"boards", "cutstone", "rope", "livinglog"}) do
        inst.components.lootdropper:SpawnLootPrefab(prefab)
    end
    inst:Remove()
end

local function OnSave(inst, data)
    data.aranara_remaining = inst.remaining
end

local function OnLoad(inst, data)
    local value = data ~= nil and tonumber(data.aranara_remaining) or 0
    inst.remaining = value ~= nil and value == value and math.max(0, value) or 0
    inst:DoTaskInTime(0, function()
        if inst:IsValid() then
            CheckSafety(inst)
            Sync(inst)
        end
    end)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()
    inst:SetDeploySmartRadius(1)
    MakeObstaclePhysics(inst, .65)
    inst.AnimState:SetBank("lumine_aranara_hut")
    inst.AnimState:SetBuild("lumine_aranara_hut")
    inst.AnimState:PlayAnimation("idle", true)
    inst.Light:SetColour(1, .75, .32)
    inst.Light:SetRadius(1.5)
    inst.Light:SetIntensity(.35)
    inst.Light:SetFalloff(.8)
    inst.Light:Enable(false)
    inst:AddTag("structure")
    inst:AddTag("lumine_aranara_hut")
    inst._aranara_time = net_float(inst.GUID, "lumine.aranara.time", "lumine_aranara_time_dirty")
    inst._aranara_total_time = net_float(inst.GUID, "lumine.aranara.total_time", "lumine_aranara_time_dirty")
    inst._aranara_workers = net_tinybyte(inst.GUID, "lumine.aranara.workers", "lumine_aranara_workers_dirty")
    inst._aranara_status = net_tinybyte(inst.GUID, "lumine.aranara.status", "lumine_aranara_status_dirty")
    inst._aranara_time:set(0)
    inst._aranara_total_time:set(0)
    inst._aranara_workers:set(0)
    inst._aranara_status:set(0)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(self)
            self.replica.container:WidgetSetup("lumine_aranara_hut")
        end
        return inst
    end
    inst.remaining = 0
    inst.workers = {}
    inst.reserved_plants = setmetatable({}, {__mode = "k"})
    inst._active = false
    inst._door_open = false
    inst.danger = false
    inst.safe_after = 0
    inst:AddComponent("inspectable")
    inst.components.inspectable.getspecialdescription = function()
        return "活动时间还剩 " .. math.ceil(inst.remaining / 60) .. " 分钟。"
    end
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("lumine_aranara_hut")
    inst.components.container.onopenfn = function()
        inst._door_open = true
        inst.AnimState:PlayAnimation("open")
        inst.AnimState:PushAnimation("open_idle", true)
    end
    inst.components.container.onclosefn = function()
        inst._door_open = false
        inst.AnimState:PlayAnimation("close")
        inst.AnimState:PushAnimation(inst._active and "active" or "idle", true)
    end
    inst:ListenForEvent("itemget", function() Sync(inst) end)
    inst:ListenForEvent("itemlose", function()
        if not inst._consuming_fuel then Sync(inst) end
    end)
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnRemoveEntity = OnRemoved
    inst:DoPeriodicTask(Config.TICK, Tick, Config.TICK)
    inst:DoPeriodicTask(.25, CheckSafety, .25)
    inst:WatchWorldState("iswinter", CheckSafety)
    return inst
end

local function fuel_fx_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("lumine_aranara_hut_fuel_fx")
    inst.AnimState:SetBuild("lumine_aranara_hut_fuel_fx")
    inst.AnimState:PlayAnimation("empty", true)
    inst.AnimState:SetFinalOffset(1)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    return inst
end

return Prefab("lumine_aranara_hut", fn, assets, prefabs),
    Prefab("lumine_aranara_hut_fuel_fx", fuel_fx_fn, assets),
    MakePlacer("lumine_aranara_hut_placer", "lumine_aranara_hut", "lumine_aranara_hut", "idle")
