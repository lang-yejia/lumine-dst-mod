local L = require("languages/lumine").For("paimon/prefab")
local C = require("paimon/config")
local Eligibility = require("paimon/eligibility")
local Food = require("paimon/food")
local Dialogue = require("paimon/dialogue")
local Observe = require("paimon/observe")
local Behaviour = require("paimon/behaviour")
local Details = require("paimon/details")
local Memory = require("paimon/memory")
local Guide = require("paimon/guide")
local assets = {
    Asset("ANIM", "anim/lumine_paimon.zip"),
    Asset("ANIM", "anim/ui_icepack_2x3.zip"),
}

local function Animate(inst, name, loop)
    if name == inst._animation and loop then return end
    inst._animation = name
    inst.AnimState:PlayAnimation(name, loop)
end

local function ClearSanity(inst)
    local owner = inst.owner
    if owner and owner:IsValid() and owner.components.sanity then
        owner.components.sanity.externalmodifiers:RemoveModifier(inst)
    end
end

local function RefreshSanity(inst)
    local owner = inst.owner
    if not owner or not owner:IsValid() then return end
    local sanity = owner.components.sanity
    if not sanity then return end
    if not inst._dormant and not inst:HasTag("INLIMBO")
        and not owner:HasTag("INLIMBO") and not owner:HasTag("playerghost")
        and not (owner.components.health and owner.components.health:IsDead())
        and inst:GetDistanceSqToInst(owner) <= C.SANITY_RADIUS^2 then
        sanity.externalmodifiers:SetModifier(inst, inst.satiety > 0 and C.SANITY_PER_SECOND or -C.SANITY_PER_SECOND)
    else
        ClearSanity(inst)
    end
end

local function SetSatiety(inst, value)
    inst.satiety = math.max(0, math.min(C.MAX_HUNGER, value))
    inst._satiety:set(inst.satiety)
    -- Feeding and reaching zero must replace the old sign immediately.
    RefreshSanity(inst)
end

local function RefreshLight(inst)
    local owner = inst.owner
    local lit = TheWorld.state.isnight == true and owner ~= nil and owner:IsValid()
        and not inst._dormant and not inst:HasTag("INLIMBO")
        and not owner:HasTag("playerghost")
        and not (owner.components.health and owner.components.health:IsDead())
    inst.Light:Enable(lit)
    inst.AnimState:SetLightOverride(lit and .2 or 0)
end

local function Tick(inst)
    local owner = inst.owner
    if not owner or not owner:IsValid() then inst.Physics:Stop(); return end
    local ghost = owner:HasTag("playerghost")
        or (owner.components.health and owner.components.health:IsDead())
    if ghost ~= inst._dormant then
        inst._dormant = ghost
        RefreshLight(inst)
        inst.components.container:Close()
        inst.components.container.canbeopened = not ghost
        if ghost then
            Details.Reset(inst)
            inst:AddTag("NOCLICK")
            inst.dialogue.pending = {}
            Animate(inst, "disappear", false)
            local delay = math.max(.5, inst.dialogue.speaking_until - GetTime())
            inst._hide_task = inst:DoTaskInTime(delay, function() inst:Hide() end)
            ClearSanity(inst)
        else
            if inst._hide_task then inst._hide_task:Cancel(); inst._hide_task = nil end
            inst:RemoveTag("NOCLICK")
            inst:Show()
            Animate(inst, "appear", false)
            inst._eating_until = GetTime() + .6
            inst.dialogue:Offer("revive")
        end
    end
    local combat = not ghost and Behaviour.InCombat(inst, owner)
    inst.components.container.canbeopened = not ghost
    if ghost then
        inst:AddTag("NOCLICK")
        inst.components.container:Close()
    else
        inst:RemoveTag("NOCLICK")
    end
    local ox, oy, oz = owner.Transform:GetWorldPosition()
    if ghost then
        Behaviour.Reset(inst)
        inst.Physics:Stop()
        inst.Physics:Teleport(ox, oy, oz)
        return
    end
    local px, py, pz = inst.Transform:GetWorldPosition()
    local dx, dz = ox - px, oz - pz
    local distance = math.sqrt(dx * dx + dz * dz)
    -- 保留地面支撑之外再检查高度，修复旧实体落入地下却水平距离正常的情况。
    -- 服务端按主人周边小范围约束，不依赖某个客户端的相机或缩放比例。
    local recovery_distance = Behaviour.GuideRecoveryDistance(inst,owner,distance,combat)
    if distance > recovery_distance or math.abs(py - oy) > C.HEIGHT_RECOVERY_DISTANCE then
        Details.Reset(inst)
        inst.components.container:Close()
        distance = Behaviour.Recover(inst, owner, combat)
        Animate(inst, "appear", false)
        inst._eating_until = GetTime() + .6
    else
        if distance > C.BAG_CLOSE_DISTANCE and inst.components.container:IsOpen() then
            inst.components.container:Close()
        end
        local moving = Behaviour.Step(inst, owner, distance, combat)
        if GetTime() >= (inst._eating_until or 0) then
            local base = moving and "follow" or (combat or GetTime() < (inst._worried_until or 0)) and "worried"
                or inst.satiety <= 0 and "hungry" or "idle"
            Animate(inst, Details.Select(inst, base, combat), true)
        else Details.Reset(inst) end
    end
    RefreshSanity(inst)
end

local function BindTo(inst, owner)
    if not Eligibility.Allows(owner) or (inst.owner and inst.owner ~= owner) then return false end
    if inst.owner == owner then return true end
    inst.owner = owner
    inst._owner:set(owner)
    RefreshLight(inst)
    owner._paimon = inst
    if owner.components.paimoncompanion then owner.components.paimoncompanion:Sync() end
    Observe.Attach(inst, owner)
    for _, event in ipairs({"death", "ms_becameghost", "enterlimbo", "exitlimbo"}) do
        inst:ListenForEvent(event, function() RefreshSanity(inst) end, owner)
    end
    local function CombatStarted()
        Behaviour.MarkCombat(inst)
    end
    inst:ListenForEvent("attacked", CombatStarted, owner)
    inst:ListenForEvent("onattackother", CombatStarted, owner)
    inst:ListenForEvent("lumine_paimon_element", function(_, data)
        if data and data.slot then CombatStarted() end
    end, owner)
    inst:ListenForEvent("onremove", function() ClearSanity(inst); inst:Remove() end, owner)
    -- 原版容器会继续向袋中物品（包括嵌套容器）转发离线通知。
    inst:ListenForEvent("player_despawn", function() inst:PushEvent("player_despawn") end, owner)
    inst:DoTaskInTime(0, function()
        if owner:IsValid() then
            Behaviour.Recover(inst, owner, false)
            Tick(inst)
        end
    end)
    return true
end

local function OnSave(inst, data)
    data.satiety = inst.satiety
    data.dialogue = inst.dialogue:OnSave()
    data.journey = inst.journey
    data.memory = Memory.OnSave(inst)
    data.guide_seen = Guide.OnSave(inst)
    data.lore_remaining = math.max(0, (inst._next_lore or 0) - GetTime())
end
local function OnLoad(inst, data)
    if not data then return end
    if type(data.satiety) == "number" and data.satiety == data.satiety then inst:SetSatiety(data.satiety) end
    inst.dialogue:OnLoad(data.dialogue)
    inst.journey = data.journey or { distance = 0, bosses = 0 }
    Memory.OnLoad(inst,data.memory)
    Guide.OnLoad(inst,data.guide_seen)
    inst._next_lore = GetTime() + (data.lore_remaining or 0)
end

local function RemoveContents(container)
    -- 原版 Container.OnRemoveEntity 只关界面，不移除内部实体。
    -- 先清内层再清外层，避免种子袋等随宠物快照保存后留下游离副本。
    for _, item in ipairs(container:GetAllItems()) do
        if item:IsValid() then
            if item.components.container then RemoveContents(item.components.container) end
            item:Remove()
        end
    end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()
    inst.Light:SetColour(.55, .75, 1)
    inst.Light:SetIntensity(.45)
    inst.Light:SetFalloff(.8)
    inst.Light:SetRadius(2)
    inst.Light:Enable(false)
    -- 只与地面平面碰撞：不挡人物，也不受树墙海岸阻碍。
    -- flying 标签不会关闭重力；动态物体清空地面掩码会不断下坠。
    -- 浮空高度由动画提供，物理根节点仍需原版飞行生物使用的 GROUND 支撑。
    local physics = inst.entity:AddPhysics()
    physics:SetMass(1)
    physics:SetFriction(0)
    physics:SetDamping(5)
    physics:SetCollisionGroup(COLLISION.FLYERS)
    physics:SetCollisionMask(COLLISION.GROUND)
    physics:SetCapsule(.25, 1)
    inst.Transform:SetFourFaced()
    inst.Transform:SetScale(C.SCALE, C.SCALE, C.SCALE)
    inst.AnimState:SetBank("lumine_paimon")
    inst.AnimState:SetBuild("lumine_paimon")
    inst.AnimState:PlayAnimation("idle", true)
    for _, tag in ipairs({ "companion", "flying", "notarget", "NOBLOCK", "lumine_paimon" }) do inst:AddTag(tag) end
    inst._owner = net_entity(inst.GUID, "paimon.owner", "paimon_owner_dirty")
    inst._satiety = net_float(inst.GUID, "paimon.satiety", "paimon_satiety_dirty")
    inst._satiety:set(C.MAX_HUNGER)
    inst._companion_status = net_string(inst.GUID,"paimon.companion_status","paimon_companion_dirty")
    inst._order_can_reroll = net_bool(inst.GUID,"paimon.order_can_reroll","paimon_companion_dirty")
    -- talker 必须在主从端都存在，原版 Say RPC 才能在客户端显示。
    inst:AddComponent("talker")
    inst.components.talker.fontsize = 26
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.colour = Vector3(1, .89, .75)
    inst.components.talker.offset = Vector3(0, -300, 0)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(self) self.replica.container:WidgetSetup("lumine_paimon") end
        return inst
    end
    inst.persists = false -- petleash 嵌入角色存档；不再作为世界实体保存第二次。
    inst.satiety = C.MAX_HUNGER
    inst._dormant = false
    inst:WatchWorldState("isnight", RefreshLight)
    inst:ListenForEvent("enterlimbo", RefreshLight)
    inst:ListenForEvent("exitlimbo", RefreshLight)
    inst:ListenForEvent("enterlimbo", RefreshSanity)
    inst:ListenForEvent("exitlimbo", RefreshSanity)
    inst.journey = { distance = 0, bosses = 0 }
    inst.SetSatiety, inst.PlayPaimonAnimation, inst.BindTo = SetSatiety, Animate, BindTo
    inst:AddComponent("inspectable")
    inst.components.inspectable.getspecialdescription = function(self, viewer)
        local value = self._satiety:value()
        local display = value > 0 and value < 1 and L(1, "不足 1") or tostring(math.floor(value))
        return viewer == self.owner and (L(2, "派蒙的应急背包，饱食度 ") .. display .. " / " .. C.MAX_HUNGER .. "。")
            or L(3, "她正陪着自己的旅行者。")
    end
    inst:AddComponent("container")
    local container = inst.components.container
    container:WidgetSetup("lumine_paimon")
    container.thiefproof = true
    -- 不只限制 UI：直接调用服务端 Open 也必须是绑定的荧。
    local open = container.Open
    container.Open = function(self, doer)
        if doer == inst.owner and not inst._dormant
            and not doer:HasTag("playerghost") and inst:GetDistanceSqToInst(doer) <= C.BAG_OPEN_DISTANCE^2 then
            return open(self, doer)
        end
    end
    -- 原版容器固定三单位自动关闭；只替换本容器的距离检查，避免放远后提前关包。
    -- 派蒙不是可携带/骑乘容器，仍保留有效玩家、视线及骑乘限制。
    container.OnUpdate = function(self)
        if self.opencount == 0 then self.inst:StopUpdatingComponent(self); return end
        for opener in pairs(self.openlist) do
            if not opener:IsValid() or opener ~= inst.owner
                or (opener.components.rider and opener.components.rider:GetMount())
                or inst:GetDistanceSqToInst(opener) > C.BAG_CLOSE_DISTANCE^2
                or not CanEntitySeeTarget(opener,inst) then
                self:Close(opener)
            end
        end
    end
    container.onopenfn = function()
        Behaviour.Reset(inst)
        Details.Reset(inst)
        inst.dialogue:Offer("bag")
    end
    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(C.PERISH_RATE)
    -- 刻意不添加 health/combat/hunger/eater/burnable/freezable：只消费食物饱食值，
    -- 不执行食物生命/温度/传送等 on-eaten 副作用，更不会产生战斗目标。
    inst.dialogue = Dialogue(inst)
    Food.Attach(inst)
    inst.OnSave, inst.OnLoad = OnSave, OnLoad
    inst:ListenForEvent("onremove", function()
        ClearSanity(inst)
        if inst.owner and inst.owner._paimon == inst then inst.owner._paimon = nil end
        -- 容器移除本身不会清理库存实体。快照由 petleash 已保存，此处不掉落复制品。
        RemoveContents(container)
    end)
    inst:DoPeriodicTask(C.FOLLOW_TICK, Tick)
    inst:DoPeriodicTask(1, function()
        if inst.owner and not inst._dormant then
            inst:SetSatiety(inst.satiety - C.HUNGER_PER_DAY / TUNING.TOTAL_DAY_TIME)
        end
    end)
    inst:DoPeriodicTask(C.EAT_INTERVAL, function()
        if inst.owner then Food.TryEat(inst) end
    end)
    inst:DoPeriodicTask(.5, function() inst.dialogue:Update() end)
    return inst
end
return Prefab("lumine_paimon", fn, assets,{"goldnugget","lumine_paimon_cake"})
