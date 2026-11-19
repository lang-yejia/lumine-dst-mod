local Widget = require("widgets/widget")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")
local Image = require("widgets/image")
local Templates = require("widgets/redux/templates")
local HydroMotion = require("widgets/lumine_hydro_icon_motion")
local RelicCollection = require("lumine_relic_collection")
local Elements = require("lumine_statue_elements")
local Rules = require("lumine_energy_rules")
local PyroInput = require("pyro/input")
local PyroRules = require("pyro/rules")
local CryoRules = require("cryo/rules")
local COST, ELECTRO = Rules.SKILL_COST, Rules.ELECTRO
local POSITION_KEY = "lumine_skillbar_position_v1"
local SLOT_SPACING = 110
local HANDLE_X = -220
local WING_X = SLOT_SPACING
local RELIC_BUTTON_X = WING_X + SLOT_SPACING
local SETTINGS_GAP = 85
local RING_SIZE = 64
local ICON_SIZE = 62
local KEY_LABEL_Y = -44
local EDGE_MARGIN = 36
local AIM_Y = 54
local AIM_HEIGHT = 26
local DENDRO = Elements.dendro.wire
local HYDRO = Elements.hydro.wire
local PYRO = Elements.pyro.wire
local CRYO = Elements.cryo.wire
local HANDLE_HINT = "点击展开／收起技能；右键拖动整组"

local function MakeRingButton(parent, x)
    local button = parent:AddChild(ImageButton("images/element/lumine_skill_ring.xml",
        "lumine_skill_ring.tex", "lumine_skill_ring.tex", "lumine_skill_ring.tex"))
    button:ForceImageSize(RING_SIZE, RING_SIZE)
    button.scale_on_focus = false
    button:SetImageFocusColour(1, .94, .78, 1)
    button:SetPosition(x, 0)
    return button
end

local SKILLS = {
    [1] = {
        {name="风行", id="wind_dash", icon="wind-dash", ready="_lumine_wind_dash_ready"},
        {name="风涡剑", id="wind_tornado", icon="wind-tornado", ready="_lumine_wind_tornado_ready"},
    },
    [2] = {
        {name="星岩护佑", id="geo_shield", icon="geo-shield", ready="_lumine_geo_shield_ready"},
        {name="岩域共鸣", id="geo_field", icon="geo-field", ready="_lumine_geo_field_ready"},
    },
    [3] = {
        {icon="electro-infusion"},
        {icon="electro-burst"},
    },
    [DENDRO] = {
        {name="藤蔓缠绕", id="dendro_root", icon="dendro-root", ready="_lumine_dendro_root_ready"},
        {name="孢子领域", id="dendro_field", icon="dendro-field", ready="_lumine_dendro_field_ready"},
    },
    [HYDRO] = {
        {name="水纹剑", id="hydro_stream", icon="hydro-stream", ready="_lumine_hydro_stream_ready"},
        {name="涨潮之水", id="hydro_bubble", icon="hydro-bubble", ready="_lumine_hydro_bubble_ready"},
    },
    [PYRO] = {
        {name="火焰球", icon="pyro-ring"},
        {name="爆炎状态", icon="pyro-burst"},
    },
    [CRYO] = {
        {name="霜刃附魔", icon="cryo-infusion"},
        {name="极寒冰陨", icon="cryo-meteor"},
    },
}

local ElementHud = Class(Widget, function(self, owner, keys, cast, glider, open_relics, relic_key,
    get_aim_mode, cycle_aim_mode, pyro_controls)
    Widget._ctor(self, "LumineSkillBar")
    self.owner = owner
    self.keys = keys
    self.get_aim_mode = get_aim_mode
    self.aim_buttons = {}
    self.last_aim_mode = {}
    self.buttons = {}
    self.hydro_motion = {}
    self.cooldowns = {}
    self.keylabels = {}
    self.last_element = -1
    self.expanded = true
    self.root = self:AddChild(ImageButton("images/element/lumine_skill_ring.xml",
        "lumine_skill_ring.tex", "lumine_skill_ring.tex", "lumine_skill_ring.tex"))
    self.root:SetPosition(HANDLE_X, 0)
    self.root:SetNormalScale(.5)
    self.root:SetFocusScale(.52)
    self.rooticon = self.root:AddChild(Image("images/inventoryimages/lumine_element_particle.xml", "lumine_element_particle.tex"))
    self.rooticon:SetSize(96, 96)
    self.rooticon:SetClickable(false)
    self.root:SetHoverText(HANDLE_HINT)
    self.root:SetOnClick(function()
        self.expanded = not self.expanded
        self:RefreshUtilityButtons()
        self.last_element = -1
    end)
    local oldcontrol = self.root.OnControl
    self.root.OnControl = function(button, control, down)
        if control == CONTROL_SECONDARY then
            if down then self:StartDrag()
            else self:FinishDrag() end
            return true
        end
        return oldcontrol ~= nil and oldcontrol(button, control, down) or false
    end
    for slot = 1, 3 do
        local x = (slot - 2) * SLOT_SPACING
        local atlas = slot == 3 and "images/element/lumine_wing_skill.xml" or "images/element/wind-dash.xml"
        local image = slot == 3 and "lumine_wing_skill.tex" or "wind-dash.tex"
        local button = MakeRingButton(self, x)
        button:SetOnClick(slot == 3 and glider or function() cast(slot) end)
        if slot == 1 then
            local pyro_press
            button:SetOnDown(function()
                pyro_press = PyroInput.IsActive(owner)
                if pyro_press then pyro_controls.Press(owner, PyroInput.BUTTON, nil, button) end
            end)
            button:SetOnClick(function()
                if pyro_press then pyro_controls.Release(PyroInput.BUTTON)
                else cast(1) end
                pyro_press = nil
            end)
            local old_lose_focus = button.OnLoseFocus
            button.OnLoseFocus = function(widget)
                if pyro_press then pyro_controls.Release(PyroInput.BUTTON) end
                pyro_press = nil
                old_lose_focus(widget)
            end
        end
        local icon = button:AddChild(Image(atlas, image))
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetClickable(false)
        self.icons = self.icons or {}
        self.icons[slot] = icon
        self.buttons[slot] = button
        if slot <= 2 then
            local motion = HydroMotion.Attach(icon, SKILLS[HYDRO][slot].id, ICON_SIZE)
            motion:Hide()
            self.hydro_motion[slot] = motion
        end
        local cooldown = button:AddChild(Text(BODYTEXTFONT, 38, ""))
        cooldown:SetPosition(0, 0)
        self.cooldowns[slot] = cooldown
        local key = self:AddChild(Text(BODYTEXTFONT, 21, "[" .. self.keys[slot] .. "]"))
        key:SetPosition(x, KEY_LABEL_Y)
        self.keylabels[slot] = key
    end
    for slot = 1, 2 do
        local button = self:AddChild(Templates.StandardButton(function() cycle_aim_mode(self.aim_element, slot) end, "",
            {90, AIM_HEIGHT}))
        button:SetTextSize(17)
        button:SetPosition((slot - 2) * SLOT_SPACING, AIM_Y)
        button:Hide()
        self.aim_buttons[slot] = button
    end
    self.electro_dot = self.buttons[1]:AddChild(Image("images/inventoryimages/lumine_element_particle.xml",
        "lumine_element_particle.tex"))
    self.electro_dot:SetSize(13, 13)
    self.electro_dot:SetTint(.79, .44, 1, 1)
    self.electro_dot:SetClickable(false)
    self.electro_dot:Hide()
    self.relic_button = MakeRingButton(self, RELIC_BUTTON_X)
    local relic_icon = self.relic_button:AddChild(Image("images/inventoryimages/lumine_relic_codex.xml", "lumine_relic_codex.tex"))
    relic_icon:SetSize(ICON_SIZE, ICON_SIZE)
    relic_icon:SetClickable(false)
    self.relic_button:SetHoverText("打开圣遗物界面")
    self.relic_button:SetOnClick(function()
        if self:CanOpenRelics() then open_relics() end
    end)
    self.relic_label = self:AddChild(Text(BODYTEXTFONT, 21, "[" .. relic_key .. "]"))
    self.relic_label:SetPosition(RELIC_BUTTON_X, KEY_LABEL_Y)
    self.relic_button:Hide()
    self.relic_label:Hide()
    self.inst:ListenForEvent("onremove", function() self:FinishDrag() end)
    self:StartUpdating()
end)

function ElementHud:CanOpenRelics()
    local owner = self.owner
    local inventory = owner.replica.inventory
    return self.expanded and RelicCollection.GetCarried(inventory) ~= nil
        and not owner:HasTag("playerghost")
end

function ElementHud:RefreshUtilityButtons()
    local can_open = self:CanOpenRelics()
    self.relic_button_visible = can_open
    if can_open then
        self.relic_button:Show()
        self.relic_label:Show()
    else
        self.relic_button:Hide()
        self.relic_label:Hide()
    end
    local settings = self.keybind_button
    if settings ~= nil then
        settings:SetPosition((can_open and RELIC_BUTTON_X or WING_X) + SETTINGS_GAP, 0)
        if self.expanded then settings:Show() else settings:Hide() end
    end
    -- Equipping the codex can widen an already parked bar.
    if can_open and self.parent ~= nil then
        local x, y = self:GetPosition():Get()
        self:SetReachablePosition(x, y)
    end
end

function ElementHud:SetReachablePosition(x, y)
    if self.parent == nil then
        self:SetPosition(x, y)
        return
    end
    local width, height = TheSim:GetScreenSize()
    local sx, sy = self.parent:GetScale():Get()
    local wx, wy = self:GetWorldPosition():Get()
    local oldx, oldy = self:GetPosition():Get()
    if sx <= 0 or sy <= 0 or width <= 0 or height <= 0 then return end
    local origin_x, origin_y = wx - oldx * sx, wy - oldy * sy
    -- Include the expanded skills, key labels, and settings button in the bounds.
    local last_x = self.relic_button_visible and RELIC_BUTTON_X or WING_X
    local left, right = (EDGE_MARGIN - HANDLE_X) * sx, width - (last_x + SETTINGS_GAP + EDGE_MARGIN) * sx
    local top_margin = self.aim_visible and AIM_Y + AIM_HEIGHT / 2 + 4 or EDGE_MARGIN
    local bottom, top = 58 * sy, height - top_margin * sy
    if left > right then
        local margin = math.min(EDGE_MARGIN * sx, width / 2)
        left, right = margin - HANDLE_X * sx, width - margin - HANDLE_X * sx
    end
    if bottom > top then bottom, top = height / 2, height / 2 end
    self:SetPosition((math.clamp(origin_x + x * sx, left, right) - origin_x) / sx,
        (math.clamp(origin_y + y * sy, bottom, top) - origin_y) / sy)
end

function ElementHud:RefreshAim(active)
    local show_options = self.expanded and not self.owner:HasTag("playerghost")
        and (active ~= PYRO or self.owner._lumine_pyro_burst:value())
    local changed_element = active ~= self.aim_element
    self.aim_element = active
    local visible = false
    for slot, button in ipairs(self.aim_buttons) do
        local mode = show_options and self.get_aim_mode(active, slot) or nil
        if changed_element or mode ~= self.last_aim_mode[slot] then
            self.last_aim_mode[slot] = mode
            if mode then
                button:SetText(mode == "mouse" and "朝鼠标" or "按朝向")
                button:SetHoverText("切换" .. SKILLS[active][slot].name .. "的快捷键朝向。直接点击技能图标时沿角色朝向。")
                button:Show()
            else
                button:Hide()
            end
        end
        if mode then visible = true end
    end
    local was_visible = self.aim_visible
    self.aim_visible = visible
    if visible and not was_visible then
        local x, y = self:GetPosition():Get()
        self:SetReachablePosition(x, y)
    end
end

function ElementHud:RestorePosition()
    -- The controls constructor runs before the controls are attached to PlayerHud.
    self.inst:DoTaskInTime(0, function()
        TheSim:GetPersistentString(POSITION_KEY, function(ok, value)
            if not self.inst:IsValid() or self.drag or self.position_changed then return end
            if not ok or type(value) ~= "string" then
                local x, y = self:GetPosition():Get()
                self:SetReachablePosition(x, y)
                return
            end
            local x, y = value:match("^([%-%.%d]+),([%-%.%d]+)$")
            x, y = tonumber(x), tonumber(y)
            if x and y and math.abs(x) < math.huge and math.abs(y) < math.huge then
                self:SetReachablePosition(x, y)
            end
        end)
    end)
end

function ElementHud:StartDrag()
    if self.drag then return end
    local mouse = TheInput:GetScreenPosition()
    local x, y = self:GetPosition():Get()
    local drag = {mousex=mouse.x, mousey=mouse.y, x=x, y=y}
    self.drag = drag
    drag.move = TheInput:AddMoveHandler(function(mx, my)
        local sx, sy = self.parent:GetScale():Get()
        if sx > 0 and sy > 0 then
            self:SetReachablePosition(x + (mx - drag.mousex) / sx, y + (my - drag.mousey) / sy)
        end
    end)
    -- The mouse can be released outside the handle after dragging.
    drag.release = TheInput:AddMouseButtonHandler(function(button, down)
        if button == MOUSEBUTTON_RIGHT and not down then self:FinishDrag() end
    end)
end

function ElementHud:FinishDrag()
    local drag = self.drag
    if not drag then return end
    self.drag = nil
    drag.move:Remove()
    drag.release:Remove()
    if not self.inst:IsValid() then return end
    local x, y = self:GetPosition():Get()
    if math.abs(x - drag.x) >= .05 or math.abs(y - drag.y) >= .05 then
        self.position_changed = true
        TheSim:SetPersistentString(POSITION_KEY, string.format("%.1f,%.1f", x, y), false)
    end
end

function ElementHud:Kill()
    self:FinishDrag()
    ElementHud._base.Kill(self)
end

function ElementHud:RefreshElectro(energy, flying)
    local owner, now = self.owner, GetTime()
    local infused = owner._lumine_electro_infused and owner._lumine_electro_infused:value()
    local ready = owner._lumine_electro_ready and owner._lumine_electro_ready:value() or 0
    local burst = owner._lumine_electro_burst and owner._lumine_electro_burst:value() or 0
    local resting = flying or owner:HasTag("playerghost")
    local remaining = math.ceil(math.max(0, ready - now))
    local can_infuse = not resting and energy > ELECTRO.INFUSION_DRAIN_PER_SECOND * ELECTRO.INFUSION_INTERVAL
    local can_burst = infused and not resting and remaining == 0 and energy >= ELECTRO.ORB_COST
    local enhanced = infused and burst > now

    self.buttons[1]:SetImageNormalColour(infused and .83 or 1, infused and .54 or 1, 1,
        (infused or can_infuse) and 1 or .45)
    self.icons[1]:SetTint(1, infused and .84 or 1, 1, 1)
    self.cooldowns[1]:SetString("")
    self.buttons[1]:SetHoverText(infused and "关闭雷元素附魔" or "雷元素附魔 · 每秒消耗 5.5 元素力")
    if infused and self.expanded and not resting then
        local angle = now * 5
        self.electro_dot:SetPosition(28 * math.cos(angle), 28 * math.sin(angle))
        self.electro_dot:Show()
    else
        self.electro_dot:Hide()
    end

    self.buttons[2]:SetImageNormalColour(enhanced and .85 or 1, enhanced and .53 or 1, 1,
        (can_burst or enhanced) and 1 or .45)
    if infused then self.icons[2]:SetTint(.9, .68, 1, (can_burst or enhanced) and 1 or .7)
    else self.icons[2]:SetTint(.48, .46, .46, .66) end
    self.cooldowns[2]:SetString(remaining > 0 and tostring(remaining) or "")
    local hint = not infused and "先开启雷元素附魔"
        or enhanced and ("强化中 " .. math.ceil(burst - now) .. " 秒")
        or remaining > 0 and ("冷却 " .. remaining .. " 秒") or "弹射雷电球 · 每颗 2 元素力"
    self.buttons[2]:SetHoverText("雷霆唤星 · " .. hint)
end

function ElementHud:RefreshPyro(energy, flying)
    local owner = self.owner
    local burst = owner._lumine_pyro_burst:value()
    local streak = owner._lumine_pyro_streak:value()
    local available = not flying and not owner:HasTag("playerghost")
    local enough = energy >= PyroRules.orb.cost
    local remaining = math.ceil(math.max(0, owner._lumine_pyro_ring_ready:value() - GetTime()))
    local can_fire = available and (burst and enough or not burst and remaining == 0 and energy >= PyroRules.ring.cost)
    if burst ~= self.last_pyro_burst then
        local icon = burst and "pyro-orb" or "pyro-ring"
        self.icons[1]:SetTexture("images/element/" .. icon .. ".xml", icon .. ".tex")
        self.icons[1]:SetSize(ICON_SIZE, ICON_SIZE)
        self.buttons[2]:SetImageFocusColour(1, burst and .68 or .94, burst and .42 or .78, 1)
        self.last_pyro_burst = burst
    end
    self.icons[1]:SetTint(1, streak > 0 and .78 or 1, streak > 0 and .53 or 1, can_fire and 1 or .53)
    self.icons[2]:SetTint(1, burst and .85 or 1, burst and .65 or 1, (burst or enough) and 1 or .53)
    self.buttons[1]:SetImageNormalColour(1, streak > 0 and .64 or 1, streak > 0 and .36 or 1, can_fire and 1 or .45)
    self.buttons[2]:SetImageNormalColour(1, burst and .62 or 1, burst and .36 or 1, (burst or available and enough) and 1 or .45)
    self.cooldowns[1]:SetString(not burst and remaining > 0 and tostring(remaining) or "")
    self.cooldowns[2]:SetString("")
    local hint = burst and "火焰球 · 短按单发／按住加速连发 · 每颗 7 元素力"
        or "流火之刃 · 随身火环，命中后灼烧 4 秒 · 18 元素力"
    if streak > 0 then hint = hint .. "\n吟唱中 · " .. streak .. " / 5 阶" end
    if not enough or (not burst and energy < PyroRules.ring.cost) then hint = hint .. "\n元素力不足" end
    self.buttons[1]:SetHoverText(hint)
    self.buttons[2]:SetHoverText(burst and "爆炎状态已开启 · 再按关闭"
        or enough and "爆炎状态 · 饱食与持续理智消耗 ×1.5"
        or "爆炎状态 · 需要至少 7 元素力")
end

function ElementHud:RefreshCryo(energy, flying)
    local owner, now = self.owner, GetTime()
    local charges = owner._lumine_cryo_charges:value()
    local field = math.max(0, math.ceil(owner._lumine_cryo_field_until:value() - now))
    local shield = owner._lumine_cryo_shield:value()
    local shield_wait = math.max(0, math.ceil(owner._lumine_cryo_shield_ready:value() - now))
    self.root:SetHoverText("寒冰护体 · " .. (shield and "冰盾已就绪" or "冰盾恢复 " .. shield_wait .. " 秒")
        .. "\n冻结目标受到下一次攻击时伤害翻倍\n" .. HANDLE_HINT)
    local ready = {owner._lumine_cryo_infusion_ready:value(), owner._lumine_cryo_meteor_ready:value()}
    local config = {CryoRules.infusion, CryoRules.meteor}
    local inventory = owner.replica.inventory
    local weapon = inventory and inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local gear = weapon and require("lumine_gear_stats").by_name[weapon.prefab]
    local has_weapon = gear and gear.damage ~= nil
    for slot = 1, 2 do
        local remaining = math.max(0, math.ceil(ready[slot] - now))
        local usable = not flying and not owner:HasTag("playerghost") and remaining == 0 and energy >= config[slot].cost
            and (slot == 2 or has_weapon)
        local active = slot == 1 and charges > 0 or slot == 2 and field > 0
        self.buttons[slot]:SetImageNormalColour(active and .58 or 1, active and .85 or 1, 1, (active or usable) and 1 or .45)
        self.icons[slot]:SetTint(1, 1, 1, (active or usable) and 1 or .53)
        self.cooldowns[slot]:SetString(remaining > 0 and tostring(remaining) or "")
        local status = slot == 1 and " · 附魔剩余 " .. charges .. " 次" or field > 0 and " · 领域剩余 " .. field .. " 秒" or ""
        if slot == 1 and not has_weapon then status = " · 请先装备旅行者的剑" end
        self.buttons[slot]:SetHoverText(SKILLS[CRYO][slot].name .. " · " .. config[slot].cost .. " 元素力" .. status)
    end
end

function ElementHud:OnUpdate()
    local owner = self.owner
    if owner == nil or not owner:IsValid() then return end
    local active = owner._lumine_element_active ~= nil and owner._lumine_element_active:value() or 0
    local skills = SKILLS[active]
    if self:CanOpenRelics() ~= self.relic_button_visible then self:RefreshUtilityButtons() end
    self:RefreshAim(active)
    if active ~= self.last_element then
        local element = Elements[Elements.by_wire[active]]
        local emblem = element and element.emblem
        if emblem ~= nil then
            self.rooticon:SetTexture("images/element/" .. emblem .. ".xml", emblem .. ".tex")
        else
            self.rooticon:SetTexture("images/inventoryimages/lumine_element_particle.xml", "lumine_element_particle.tex")
        end
        self.rooticon:SetSize(96, 96)
        self.root:SetHoverText(active == DENDRO
            and "荆棘援护已生效 · 旅行者武器命中时有几率召唤藤蔓\n" .. HANDLE_HINT
            or active == HYDRO and "清澈之水已生效 · 触碰水滴消耗 5 饱食度并恢复生命\n" .. HANDLE_HINT
            or active == PYRO and "炽热之心 · 攻击伤害 +10%，对灼烧目标改为 +25%\n" .. HANDLE_HINT or HANDLE_HINT)
        for slot = 1, 2 do
            self.buttons[slot]:SetImageFocusColour(1, .94, .78, 1)
            if skills ~= nil and self.expanded then
                local name = skills[slot].icon
                self.icons[slot]:SetTexture(skills[slot].atlas or "images/element/" .. name .. ".xml",
                    name .. ".tex")
                self.icons[slot]:SetSize(ICON_SIZE, ICON_SIZE)
                self.icons[slot]:SetTint(1, 1, 1, 1)
                self.buttons[slot]:Show()
                self.keylabels[slot]:Show()
            else
                self.buttons[slot]:Hide()
                self.keylabels[slot]:Hide()
            end
            if self.expanded and active == HYDRO then
                self.hydro_motion[slot]:Show()
            else
                self.hydro_motion[slot]:Hide()
            end
        end
        if self.expanded then
            self.buttons[3]:Show()
            self.keylabels[3]:Show()
        else
            self.buttons[3]:Hide()
            self.keylabels[3]:Hide()
        end
        self.last_element = active
        self.last_pyro_burst = nil
    end
    local energy = owner._lumine_energy ~= nil and owner._lumine_energy:value() or 0
    local flying = owner.lumine_glider_phase ~= nil and owner.lumine_glider_phase:value() > 0
    if active == 3 then
        self:RefreshElectro(energy, flying)
    elseif active == PYRO then
        self.electro_dot:Hide()
        self:RefreshPyro(energy, flying)
    elseif active == CRYO then
        self.electro_dot:Hide()
        self:RefreshCryo(energy, flying)
    elseif skills ~= nil then
        self.electro_dot:Hide()
        local now = GetTime()
        for slot = 1, 2 do
            local skill = skills[slot]
            local ready = owner[skill.ready] ~= nil and owner[skill.ready]:value() or 0
            local remaining = math.ceil(math.max(0, ready - now))
            local field_time = active == DENDRO and slot == 2 and owner._lumine_dendro_field_until
                and math.ceil(math.max(0, owner._lumine_dendro_field_until:value() - now)) or 0
            local bubble_time = active == HYDRO and slot == 2 and owner._lumine_hydro_bubble_until
                and math.ceil(math.max(0, owner._lumine_hydro_bubble_until:value() - now)) or 0
            local bubble_hp = bubble_time > 0 and owner._lumine_hydro_bubble_hp:value() or 0
            local disabled = owner:HasTag("playerghost") or flying or remaining > 0 or energy < COST[skill.id]
            if active == HYDRO then
                HydroMotion.SetStrength(self.hydro_motion[slot], bubble_hp > 0 and 1 or disabled and .3 or .9)
            end
            if field_time > 0 then
                self.buttons[slot]:SetImageNormalColour(.62, .91, .50, 1)
            elseif bubble_hp > 0 then
                self.buttons[slot]:SetImageNormalColour(.59, .81, 1, 1)
            else
                self.buttons[slot]:SetImageNormalColour(1, 1, 1, disabled and .45 or 1)
            end
            self.cooldowns[slot]:SetString(remaining > 0 and tostring(remaining) or "")
            self.buttons[slot]:SetHoverText(skill.name .. "  ·  " .. COST[skill.id] .. " 元素力"
                .. (field_time > 0 and "  ·  领域剩余 " .. field_time .. " 秒" or "")
                .. (bubble_hp > 0 and ("  ·  水泡 %d HP  ·  剩余 %d 秒"):format(bubble_hp, bubble_time) or "")
                .. (remaining > 0 and "  ·  冷却 " .. remaining .. " 秒" or ""))
        end
    else
        self.electro_dot:Hide()
    end
    self.buttons[3]:SetImageNormalColour(1, 1, 1, owner:HasTag("playerghost") and .45 or 1)
    self.buttons[3]:SetHoverText(flying and "收起风之翼" or "展开风之翼")
    for slot = 1, 3 do
        self.keylabels[slot]:SetString("[" .. self.keys[slot] .. "]")
    end
end

return ElementHud
