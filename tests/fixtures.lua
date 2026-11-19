local M = {}

function M.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = M.copy(entry) end
    return result
end

function M.item(prefab, fields, count)
    local item = {prefab = prefab, fields = M.copy(fields or {}), count = count or 1, components = {}}
    local inventoryitem = {}
    function inventoryitem:GetGrandOwner() return self.owner end
    item.components.inventoryitem = inventoryitem
    item.components.stackable = {StackSize = function() return item.count end}
    if prefab == "royal_jelly" then
        item.components.edible = {foodtype = "GOODIES", GetHealth = function() return 1 end,
            GetSanity = function() return 1 end, GetHunger = function() return 12 end}
    end
    function item:IsValid() return not self.removed end
    function item:Remove() self.removed = true end
    function item:GetSaveRecord()
        local data = M.copy(self.fields)
        if self.count ~= 1 then data.stackable = {stack = self.count} end
        return {prefab = self.prefab, data = data, skinname = self.skinname}, self.refs
    end
    return item
end

local function NewEntity(prefab)
    local inst = {prefab = prefab, components = {}, tags = {}, events = {}, handlers = {}, tasks = {}, delay = {}, distance = 0}
    function inst:IsValid() return not self.removed end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:GetDistanceSqToInst() return self.distance end
    function inst:PushEvent(name, data)
        self.events[#self.events + 1] = {name = name, data = data}
        if self.handlers[name] then self.handlers[name](self, data) end
    end
    function inst:ListenForEvent(name, handler) self.handlers[name] = handler end
    function inst:WatchWorldState() end
    function inst:DoTaskInTime(_, fn) self.delay[#self.delay + 1] = fn end
    function inst:DoPeriodicTask(_, fn) self.tasks[#self.tasks + 1] = fn end
    function inst:PlayPaimonAnimation(name) self.animation = name end
    inst.components.talker = {Say = function(_, line) inst.last_line = line end}
    return inst
end

function M.world()
    TheWorld = {ismastersim = true, state = {cycles = 0}}
    FOODTYPE = {MEAT = "MEAT", VEGGIE = "VEGGIE", GOODIES = "GOODIES", GENERIC = "GENERIC", SEEDS = "SEEDS"}
    Class = function(constructor)
        local class = {}
        class.__index = class
        return setmetatable(class, {__call = function(_, ...)
            local object = setmetatable({}, class)
            constructor(object, ...)
            return object
        end})
    end
    local env = {spawns = 0, spawned = {}}
    SpawnSaveRecord = function(saved, entities)
        if env.fail_prefab == saved.prefab then return nil end
        if env.on_spawn then env.on_spawn(saved) end
        local item = M.item(saved.prefab, saved.data, saved.data and saved.data.stackable and saved.data.stackable.stack)
        item.skinname = saved.skinname
        item.Transform = {SetPosition = function(_, x, y, z) item.position = {x, y, z} end}
        env.spawns = env.spawns + 1
        env.spawned[#env.spawned + 1] = item
        if entities then entities[item] = {entity = item} end
        if env.error_prefab == saved.prefab then error("simulated OnLoad error") end
        return item
    end
    return env
end

function M.player(save)
    local owner = NewEntity("lumine")
    local function netvar()
        return {set = function(self, value) self.value = value end}
    end
    owner._lumine_gear_progress = netvar()
    owner._lumine_element_active = netvar()
    owner.Transform = {GetWorldPosition = function() return 12, 0, 34 end}
    local inventory = {removals = 0}
    function inventory:GetActiveItem() return self.active end
    function inventory:RemoveItem(item, whole)
        assert(self.active == item and whole == false)
        if self.reject then return nil end
        self.removals = self.removals + 1
        if item.count > 1 then
            item.count = item.count - 1
            if self.on_remove then self.on_remove() end
            -- The engine can reconstruct a split instance without custom component state.
            return M.item(item.prefab)
        end
        self.active = nil
        if self.on_remove then self.on_remove() end
        item.components.inventoryitem.owner = nil
        return item
    end
    function owner:Hold(item)
        inventory.active = item
        item.components.inventoryitem.owner = self
        return item
    end
    owner.components.inventory = inventory

    local pet = NewEntity("lumine_paimon")
    local container = {numslots = 6, slots = {}}
    function container:GetItemInSlot(slot) return self.slots[slot] end
    function container:CanTakeItemInSlot(_, slot) return self.slots[slot] == nil and not self.reject end
    function container:GiveItem(item, slot, _, drop_on_fail)
        assert(drop_on_fail == false)
        if not self:CanTakeItemInSlot(item, slot) then return false end
        self.slots[slot] = item
        item.components.inventoryitem.owner = pet
        if self.on_give then self.on_give(item) end
        return true
    end
    function container:Fill()
        for slot = 1, self.numslots do self.slots[slot] = M.item("twigs") end
    end
    owner._paimon, pet.owner = pet, owner
    pet.components.container = container
    local journey = require("components/luminejourney")(owner)
    owner.components.luminejourney = journey
    if save then journey:OnLoad(M.copy(save)) end
    for _, fn in ipairs(owner.delay) do fn() end
    return owner, journey, pet, container, inventory
end

function M.tick(journey, count)
    for _ = 1, count or 20 do journey:TickRecording() end
end

function M.action()
    local actions, select_action = {}, nil
    local hooks = {
        AddAction = function(id, _, fn) actions[id] = {fn = fn}; return actions[id] end,
        AddComponentAction = function(_, _, fn) select_action = fn end,
        AddStategraphActionHandler = function() end,
    }
    local G = {TheWorld = TheWorld, ActionHandler = function() end, FOODTYPE = {}}
    for _, name in ipairs({"MEAT", "VEGGIE", "GOODIES", "GENERIC", "SEEDS"}) do G.FOODTYPE[name] = name end
    require("paimon/feeding").Install(G, hooks)
    return actions.PAIMON_RECORD.fn, select_action, actions.PAIMON_RECORD
end

return M
