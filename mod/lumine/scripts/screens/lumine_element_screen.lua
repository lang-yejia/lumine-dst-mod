local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local Templates = require("widgets/redux/templates")
local HydroMotion = require("widgets/lumine_hydro_icon_motion")
local Data = require("lumine_progression")
local Statues = require("lumine_statue_elements")

local WHITE = {0.96, 0.93, 0.82, 1}
local MUTED = {0.72, 0.78, 0.74, 1}
local WIND = {0.62, 0.82, 0.75, 1}
local GEO = {0.94, 0.75, 0.39, 1}
local ELEMENTS = {
    ["风"] = {id="wind", subtitle="机动与牵引 · 从提瓦特带来的风之力", emblem="wind-emblem", colour=WIND,
        footer="在七天神像切换元素；技能 1 / 技能 2 共用模组设置中的两组按键。"},
    ["岩"] = {id="geo", subtitle="守护与共鸣 · 稳固旅途中的每一步", emblem="geo-emblem", colour=GEO,
        footer="在七天神像切换元素；技能 1 / 技能 2 共用模组设置中的两组按键。"},
    ["雷"] = {id="electro", subtitle="持续附魔与短时爆发", colour={.73,.65,.88,1},
        emblem="electro-emblem", footer="雷霆唤星需先开启附魔，冷却 12 秒。"},
    ["草"] = {id="dendro", subtitle="召唤 · 缠根 · 孢子", colour={.65,.82,.52,1},
        emblem="dendro-emblem", footer="藤蔓缠绕消耗 15 元素力；孢子领域消耗 30 元素力。"},
    ["水"] = {id="hydro", subtitle="潮汐控制与战斗续航", colour={.55,.72,.91,1}, emblem="hydro-emblem",
        footer="水纹剑消耗 12 元素力 · 涨潮之水消耗 35 元素力"},
    ["火"] = {id="pyro", subtitle="随身火环与持续爆发", colour={.91,.58,.45,1},
        emblem="pyro-emblem",
        footer="火焰环消耗 18 元素力 · 爆炎时每颗火焰球消耗 7 元素力"},
    ["冰"] = {id="cryo", subtitle="冰盾反击 · 武器附魔 · 冻结破冰", colour={.69,.85,.89,1},
        emblem="cryo-emblem",
        footer="霜刃附魔消耗 20 元素力 · 极寒冰陨消耗 40 元素力"},
}

local function Fill(parent, x, y, width, height, colour)
    local image = parent:AddChild(Image("images/ui.xml", "white.tex"))
    image:SetSize(width, height)
    image:SetPosition(x, y)
    image:SetTint(unpack(colour))
    image:SetClickable(false)
    return image
end

local function Label(parent, size, value, x, y, colour)
    local label = parent:AddChild(Text(CHATFONT, size, value))
    label:SetPosition(x, y)
    label:SetColour(unpack(colour))
    label:SetClickable(false)
    return label
end

local function Button(parent, value, x, y, width, fn)
    local button = parent:AddChild(Templates.StandardButton(fn, value, {width, 42}))
    button:SetPosition(x, y)
    return button
end

local ElementScreen = Class(Screen, function(self, owner, mask, insight, elementmask, available, active)
    Screen._ctor(self, "LumineElementScreen")
    self.owner = owner
    self.is_popup = true
    local active_id = Statues.by_wire[active]
    self.element = active_id and Statues[active_id].name or "风"

    local shade = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    shade.scale_on_focus = false
    shade.move_on_click = false
    shade.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade.image:SetHAnchor(ANCHOR_MIDDLE)
    shade.image:SetVAnchor(ANCHOR_MIDDLE)
    shade.image:SetTint(0, 0, 0, 0.72)
    shade:SetOnClick(function() self:Close() end)
    shade:SetHelpTextMessage("")

    self.root = self:AddChild(Widget("lumine_element_root"))
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    local panel = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    panel.scale_on_focus = false
    panel.move_on_click = false
    panel:ForceImageSize(940, 650)
    panel.image:SetTint(0.10, 0.14, 0.14, 0.98)
    panel:SetOnClick(function() end)
    panel:SetHelpTextMessage("")
    panel:SetFocusScale(1, 1)

    Fill(self.root, 0, 294, 892, 3, {0.52, 0.68, 0.57, 1})
    Fill(self.root, 0, -271, 892, 2, {0.34, 0.50, 0.44, 1})
    self.emblem = self.root:AddChild(Image("images/element/wind-emblem.xml", "wind-emblem.tex"))
    self.emblem:SetSize(104, 104)
    self.emblem:SetPosition(-392, 232)
    self.emblem:SetClickable(false)
    self.title = Label(self.root, 34, "", -230, 258, WHITE)
    self.subtitle = Label(self.root, 18, "", -203, 222, WIND)
    self.total = Label(self.root, 20, "", 279, 258, {0.91, 0.79, 0.47, 1})
    Label(self.root, 17, "这里查看元素效果；在七天神像共鸣后自动获得该元素的全部能力。", -100, 171, MUTED)
    self.footer = Label(self.root, 16, "", 0, -255, MUTED)
    Fill(self.root, 0, 153, 870, 2, {0.34, 0.50, 0.44, 1})
    -- Put cards behind the navigation so their image layers cannot intercept tab clicks.
    self.content = self.root:AddChild(Widget("element_skill_cards"))
    self.tabs = {}
    for index, element in ipairs({"风", "岩", "雷", "草", "水", "火", "冰"}) do
        local selected = element
        self.tabs[element] = Button(self.root, element, -354 + (index - 1) * 118, 130, 100,
            function() self:SetElement(selected) end)
    end

    self.closebutton = Button(self.root, "关闭", 361, -297, 116, function() self:Close() end)
    self.default_focus = self.closebutton
    owner._lumine_element_screen = self
    self:Refresh(mask, insight, elementmask, available, active)
end)

function ElementScreen:SetElement(element)
    self.element = element
    self:Render()
end

function ElementScreen:Refresh(mask, insight, elementmask, available, active)
    self.mask = math.floor(tonumber(mask) or 0)
    self.insight = math.floor(tonumber(insight) or 0)
    self.elementmask = math.floor(tonumber(elementmask) or 0)
    self.available = math.floor(tonumber(available) or 0)
    self.active = math.floor(tonumber(active) or 0)
    local id = Statues.by_wire[self.active]
    self.total:SetString("当前生效：" .. (id and Statues[id].name or "无"))
    self:Render()
end

function ElementScreen:Render()
    self.content:KillAllChildren()
    local config = ELEMENTS[self.element]
    self.title:SetString("元素共鸣 · " .. self.element)
    self.subtitle:SetString(config.subtitle)
    self.subtitle:SetColour(unpack(config.colour))
    self.footer:SetString(config.footer)
    if config.emblem ~= nil then
        self.emblem:SetTexture(config.atlas or "images/element/" .. config.emblem .. ".xml", config.emblem .. ".tex")
        self.emblem:SetSize(104, 104)
        self.emblem:Show()
    else
        self.emblem:Hide()
    end
    for element, tab in pairs(self.tabs) do
        if element == self.element then tab:Disable() else tab:Enable() end
    end
    if config.emblem == nil then
        Fill(self.content, 0, -40, 870, 300, {.16,.22,.22,1})
        Label(self.content, 31, self.element .. "元素 · 尚未开放", 0, 18, config.colour)
        Label(self.content, 19, "已可供奉并收集对应神像，角色共鸣技能仍待开放。",
            0, -34, MUTED)
        return
    end
    Fill(self.content, -357, -12, 2, 230, {0.40, 0.63, 0.54, 1})
    for index, skill in ipairs(Data.ELEMENT_SKILLS) do
      if skill.element == self.element then
        local localindex = ((index - 1) % 3) + 1
        local y = 60 - (localindex - 1) * 107
        Fill(self.content, 0, y, 870, 94, {0.16, 0.22, 0.22, 1})
        Fill(self.content, -427, y, 4, 82, config.colour)
        local icon = self.content:AddChild(Image(skill.atlas or "images/inventoryimages.xml", skill.icon))
        icon:SetSize(55, 55)
        icon:SetPosition(-352, y)
        icon:SetClickable(false)
        HydroMotion.Attach(icon, skill.id, 55)
        Label(self.content, 24, skill.name, -223, y + 23, WHITE)
        Label(self.content, 17, skill.hint, -85, y - 13, MUTED)
        if localindex == 1 then
            Label(self.content, 15, self.element == "雷" and "被动 · 战斗回能"
                or self.element == "草" and "被动 · 召唤" or self.element == "水" and "被动 · 治疗" or "被动 · 常驻",
                207, y + 24, config.colour)
        else
            local kind = self.element == "风" and (localindex == 2 and "主动 · 位移" or "主动 · 聚怪")
                or self.element == "雷" and (localindex == 2 and "主动 · 附魔" or "主动 · 强化")
                or self.element == "草" and (localindex == 2 and "主动 · 缠根" or "主动 · 中毒")
                or self.element == "水" and (localindex == 2 and "主动 · 水流" or "爆发 · 嘲讽")
                or (localindex == 2 and "主动 · 护盾" or "主动 · 领域")
            Label(self.content, 15, kind, 207, y + 24, config.colour)
        end
        local element = Statues[config.id]
        local active = self.active == element.wire
        local owned = Statues.Has(self.elementmask, element.bit)
        Label(self.content, 17, active and "当前生效" or owned and "已学节点" or "节点未学",
            352, y - 10, active and config.colour or MUTED)
      end
    end
end

function ElementScreen:Close()
    if self.closed then return end
    self.closed = true
    TheFrontEnd:PopScreen(self)
end

function ElementScreen:OnDestroy()
    if self.owner ~= nil and self.owner._lumine_element_screen == self then
        self.owner._lumine_element_screen = nil
    end
    ElementScreen._base.OnDestroy(self)
end

function ElementScreen:OnControl(control, down)
    if ElementScreen._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_CANCEL or control == CONTROL_MENU_BACK or control == CONTROL_PAUSE) then
        self:Close()
    end
    return true
end

return ElementScreen
