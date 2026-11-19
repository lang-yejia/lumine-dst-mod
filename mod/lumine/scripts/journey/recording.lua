local Data = require("lumine_progression")

local Recording = {}
Recording.__index = Recording
local DURATION = 20
local CAPACITY = 2

local function IsFinite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function CopySaveValue(value, visiting)
    local kind = type(value)
    if kind == "boolean" or kind == "string" or IsFinite(value) then return value end
    if kind ~= "table" or getmetatable(value) ~= nil or visiting[value] then
        error("unsupported save value: " .. kind)
    end
    visiting[value] = true
    local copy = {}
    for key, entry in pairs(value) do
        if type(key) ~= "string" and not IsFinite(key) then error("unsupported save key") end
        copy[key] = CopySaveValue(entry, visiting)
    end
    visiting[value] = nil
    return copy
end

local function ValidateSnapshot(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.prefab) ~= "string" or snapshot.prefab == ""
        or (snapshot.data ~= nil and type(snapshot.data) ~= "table") then return nil end
    local ok, copy = pcall(CopySaveValue, snapshot, {})
    if not ok then return nil end
    for _, field in ipairs({"x", "y", "z", "rx", "ry", "rz", "age"}) do
        if copy[field] ~= nil and not IsFinite(copy[field]) then return nil end
    end
    if copy.skinname ~= nil and type(copy.skinname) ~= "string" then return nil end
    local data = copy.data or {}
    local container = data.container
    if container ~= nil and (type(container) ~= "table" or
        (container.items ~= nil and (type(container.items) ~= "table" or next(container.items) ~= nil))) then
        return nil
    end
    local stack = data.stackable
    if stack ~= nil and (type(stack) ~= "table" or (stack.stack ~= nil and stack.stack ~= 1)) then return nil end
    return copy
end

local function Capture(item)
    local ok, snapshot, refs = pcall(item.GetSaveRecord, item)
    if not ok or type(snapshot) ~= "table" or snapshot.prefab ~= item.prefab
        or (refs ~= nil and (type(refs) ~= "table" or next(refs) ~= nil)) then return nil end
    -- DST saves stack quantity in stackable.stack and defaults to one when absent.
    -- Keep the original item's other persisted fields, including custom data.
    local data = snapshot.data
    local stackable = item.components.stackable
    if stackable and stackable:StackSize() > 1
        and (type(data) ~= "table" or type(data.stackable) ~= "table") then return nil end
    if type(data) == "table" and type(data.stackable) == "table" then
        local stack, single = data.stackable, {}
        if not IsFinite(stack.stack) or stack.stack < 1 or stack.stack % 1 ~= 0
            or stackable == nil or stack.stack ~= stackable:StackSize() then return nil end
        for key, value in pairs(stack) do if key ~= "stack" then single[key] = value end end
        local fields = {}
        for key, value in pairs(data) do fields[key] = value end
        fields.stackable = next(single) and single or nil
        local record = {}
        for key, value in pairs(snapshot) do record[key] = value end
        record.data = fields
        snapshot = record
    end
    return ValidateSnapshot(snapshot)
end

local function AvailablePet(owner)
    local pet = owner._paimon
    if owner:IsValid() and not owner._paimon_departing and not owner:HasTag("playerghost")
        and not owner:HasTag("INLIMBO") and not (owner.components.health and owner.components.health:IsDead())
        and pet ~= nil and pet:IsValid() and pet.owner == owner and pet.prefab == "lumine_paimon"
        and not pet._dormant and not pet:HasTag("INLIMBO") and pet.components.container ~= nil then
        return pet
    end
end

local function Spawn(snapshot)
    local entities = {}
    -- OnLoad handlers may modify the data table they receive. Keep the queue's
    -- copy available for another return attempt.
    local ok, item = pcall(SpawnSaveRecord, CopySaveValue(snapshot, {}), entities)
    if ok and item and item:IsValid() and item.components.inventoryitem ~= nil then return item end
    if item and ok and item:IsValid() then item:Remove() end
    for _, entry in pairs(entities) do
        if entry.entity:IsValid() then entry.entity:Remove() end
    end
    return nil, ok and "cannot_restore_item" or tostring(item)
end

local function StillHeld(submission)
    local item = submission.item
    return submission.inventory:GetActiveItem() == item
        and (not submission.count or item.components.stackable:StackSize() == submission.count)
end

function Recording.New(journey)
    return setmetatable({journey = journey, pending = {}, issues = {}, next_id = 1}, Recording)
end

function Recording:Begin(item, target)
    if not TheWorld.ismastersim then return false end
    local owner = self.journey.inst
    local pet = AvailablePet(owner)
    local function Reject(message)
        if owner.components.talker then owner.components.talker:Say(message) end
        return false
    end
    if pet == nil or pet ~= target or pet:HasTag("NOCLICK")
        or owner:GetDistanceSqToInst(pet) > 9 then return false end
    if self.busy or self.active then return Reject("派蒙还在记录上一件证物。") end
    if #self.pending >= CAPACITY then return Reject("先给派蒙的背包腾些位置，再继续记录吧。") end
    if item == nil or not item:IsValid() then return Reject("这件物品已经不在手里了。") end
    local inventory = owner.components.inventory
    local inventoryitem = item.components.inventoryitem
    -- USEITEM is performed with the active cursor item. Checking it again on
    -- the server also rejects old requests and items belonging to other players.
    if not inventory or inventory:GetActiveItem() ~= item or not inventoryitem
        or inventoryitem.owner ~= owner or inventoryitem:GetGrandOwner() ~= owner then
        return Reject("请拿着自己的证物交给派蒙。")
    end
    local candidates = Data.BY_EVIDENCE[item.prefab]
    if not candidates then return Reject("派蒙还没有能记录这件物品的章节。") end
    local chapter, unfinished
    for _, id in ipairs(candidates) do
        if not self.journey.done[id] then
            unfinished = true
            if self.journey.experienced[id] then chapter = id break end
        end
    end
    if not chapter then
        return Reject(unfinished and "先亲身经历这一章，再带证物回来吧。" or "这一页已经记录过了。")
    end
    if inventoryitem.islockedinslot or item.persists == false
        or (item.components.container and next(item.components.container:GetAllItems()) ~= nil) then
        return Reject("这件物品暂时无法安全保管，派蒙没有收下。")
    end
    local snapshot = Capture(item)
    if not snapshot then return Reject("这件物品暂时无法安全保管，派蒙没有收下。") end
    self.busy = true
    local stackable = item.components.stackable
    local submission = {inventory = inventory, item = item, count = stackable and stackable:StackSize()}
    self.submission = submission
    self.active = {token = self.next_id, id = chapter, item = snapshot, remaining = DURATION}
    local ok, removed = pcall(inventory.RemoveItem, inventory, item, false)
    self.submission = nil
    if not ok then
        print("[Lumine journey] Evidence removal: " .. tostring(removed))
        -- A single item can be recovered after an inventory event throws.
        -- The split entity of a stack is only accessible on successful return.
        if not StillHeld(submission) and (submission.count or 1) == 1 then
            removed = item
        else
            self.active = nil
            self.busy = nil
            if not StillHeld(submission) then
                return Reject("证物交接被中断，请检查手中的物品和脚边。")
            end
            return Reject("派蒙没能接过这件物品，请再试一次。")
        end
    end
    if not removed then
        self.active = nil
        self.busy = nil
        return Reject("派蒙没能接过这件物品，请再试一次。")
    end
    self.next_id = self.next_id + 1
    if removed:IsValid() then removed:Remove() end
    self.busy = nil
    owner:PushEvent("lumine_milestone", {id = chapter, insight = self.journey.insight})
    pet:PlayPaimonAnimation("lookaround", false)
    if pet.components.talker then pet.components.talker:Say("让我把这段旅程记下来！") end
    return true
end

function Recording:FlagIssue(work, reason, detail)
    self.issues[#self.issues + 1] = {work = work, reason = reason}
    print(string.format("[Lumine journey] Evidence %s: %s", tostring(work.token), detail or reason))
end

local function HasEmptySlot(container)
    for index = 1, container.numslots do
        if container:GetItemInSlot(index) == nil then return true end
    end
    return false
end

function Recording:Deliver(container, work, item)
    for slot = 1, container.numslots do
        if container:GetItemInSlot(slot) == nil and container:CanTakeItemInSlot(item, slot) then
            self.delivery = {work = work, container = container, slot = slot, item = item}
            local ok, result = pcall(container.GiveItem, container, item, slot, nil, false)
            local delivered = container:GetItemInSlot(slot) == item
            self.delivery = nil
            if delivered then return true end
            if not ok then print("[Lumine journey] Evidence delivery: " .. tostring(result)) end
            break
        end
    end
    if item:IsValid() then item:Remove() end
    return false
end

local function AnnounceCompletion(journey, id)
    -- RecordMilestone writes done and insight before invoking presentation hooks.
    local ok, err = pcall(journey.RecordMilestone, journey, id)
    if not ok then print("[Lumine journey] Milestone notification: " .. tostring(err)) end
end

function Recording:Tick()
    if self.busy or (not self.active and #self.pending == 0) or not TheWorld.ismastersim then return end
    local pet = AvailablePet(self.journey.inst)
    if not pet then return end
    self.busy = true
    local container = pet.components.container
    local work = self.active
    local restored
    if work then
        work.remaining = math.max(0, work.remaining - 1)
        if work.remaining == 0 then
            local reason
            restored, reason = Spawn(work.item)
            self.active = nil
            if restored then
                self.pending[#self.pending + 1] = work
                -- Queue the verified item before events or dialogue can observe the reward.
                AnnounceCompletion(self.journey, work.id)
            else
                self:FlagIssue(work, "restore_failed", reason)
                self.journey.inst:PushEvent("lumine_milestone", {id = work.id, insight = self.journey.insight})
            end
        end
    end
    local index = 1
    while index <= #self.pending and HasEmptySlot(container) do
        local entry = self.pending[index]
        local item, reason
        if entry == work and restored then
            item, restored = restored, nil
        else
            item, reason = Spawn(entry.item)
        end
        if not item then
            self:FlagIssue(entry, "restore_failed", reason)
            table.remove(self.pending, index)
        elseif self:Deliver(container, entry, item) then
            table.remove(self.pending, index)
        else
            index = index + 1
        end
    end
    if restored and restored:IsValid() then restored:Remove() end
    self.busy = nil
end

function Recording:OnSave()
    local active = self.active
    local submission = self.submission
    if submission and StillHeld(submission) then
        active = nil
    end
    local pending = {}
    for _, work in ipairs(self.pending) do
        local delivery = self.delivery
        if not delivery or delivery.work ~= work or delivery.container:GetItemInSlot(delivery.slot) ~= delivery.item then
            pending[#pending + 1] = work
        end
    end
    if active or #pending > 0 or #self.issues > 0 then
        return {active = active, pending = pending, issues = self.issues, next_id = self.next_id}
    end
end

function Recording:ReleaseForReroll()
    local function Release(work)
        local item = Spawn(work.item)
        if not item then return false end
        item.Transform:SetPosition(self.journey.inst.Transform:GetWorldPosition())
        return true
    end
    -- The moon portal discards this component when it swaps characters.
    -- Follow its inventory behavior for evidence still in the ledger.
    if self.active and Release(self.active) then self.active = nil end
    for index = #self.pending, 1, -1 do
        if Release(self.pending[index]) then table.remove(self.pending, index) end
    end
end

function Recording:OnLoad(state, legacy_active, legacy_pending)
    if type(state) ~= "table" then
        state = {active = legacy_active, pending = {}}
        for _, item in ipairs(type(legacy_pending) == "table" and legacy_pending or {}) do
            state.pending[#state.pending + 1] = {item = item}
        end
    end
    self.active, self.pending, self.issues = nil, {}, {}
    local next_id = state.next_id
    self.next_id = IsFinite(next_id) and next_id >= 1 and next_id % 1 == 0 and next_id or 1
    local seen = {}
    local function Restore(entry, active)
        if entry == nil then return end
        if type(entry) ~= "table" then
            self:FlagIssue({item = entry}, "invalid_work")
            return
        end
        local token = entry.token
        if not IsFinite(token) or token < 1 or token % 1 ~= 0 then token = self.next_id end
        if seen[token] then return end
        seen[token] = true
        self.next_id = math.max(self.next_id, token + 1)
        local snapshot = ValidateSnapshot(entry.item)
        if not snapshot then
            self:FlagIssue(entry, "invalid_snapshot")
            return
        end
        local work = {token = token, id = type(entry.id) == "string" and entry.id or nil, item = snapshot}
        local matching = false
        for _, id in ipairs(Data.BY_EVIDENCE[snapshot.prefab] or {}) do
            if id == entry.id then matching = true break end
        end
        if active and not self.active and matching and not self.journey.done[work.id] and self.journey.experienced[work.id]
            and IsFinite(entry.remaining) and entry.remaining >= 0 then
            work.remaining = math.min(DURATION, entry.remaining)
            self.active = work
        else
            self.pending[#self.pending + 1] = work
        end
    end
    -- If an interrupted save contains both forms, the pending entry owns the item.
    for _, entry in ipairs(type(state.pending) == "table" and state.pending or {}) do Restore(entry, false) end
    Restore(state.active, true)
    for _, issue in ipairs(type(state.issues) == "table" and state.issues or {}) do
        if type(issue) == "table" then
            -- A prefab or its loader may become available again after a mod is repaired.
            if issue.reason == "restore_failed" and type(issue.work) == "table" then
                Restore(issue.work, issue.work.remaining == 0)
            else
                self.issues[#self.issues + 1] = issue
            end
        end
    end
end

return Recording
