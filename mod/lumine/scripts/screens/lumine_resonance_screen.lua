local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local HydroMotion = require("widgets/lumine_hydro_icon_motion")
local Style = require("journey/book_style")
local Elements = require("lumine_statue_elements")
local Skills = require("lumine_progression").ELEMENT_SKILLS
local MAX_ENERGY = require("lumine_energy_rules").MAX_ENERGY

local Label, Paragraph, Fill = Style.Label, Style.Paragraph, Style.Fill
local RING = "images/element/lumine_skill_ring.xml"
local STATUE = "lumine_seven_statue-icon"
local SKILL_CAPTIONS = {
    wind_swift = "被动 · 移速",
    wind_dash = "主动 · 闪避位移",
    wind_tornado = "主动 · 牵引",
    geo_resolve = "被动 · 减伤",
    geo_shield = "主动 · 护盾",
    geo_field = "主动 · 增益领域",
    electro_regen = "被动 · 战斗回能",
    electro_infusion = "主动 · 附魔",
    electro_burst = "主动 · 雷电球",
    dendro_guard = "被动 · 召唤",
    dendro_root = "主动 · 缠根",
    dendro_field = "主动 · 中毒",
    hydro_drop = "被动 · 生命恢复",
    hydro_stream = "主动 · 穿透",
    hydro_bubble = "爆发 · 嘲讽",
    pyro_heart = "被动 · 增伤",
    pyro_ring = "主动 · 火焰环",
    pyro_burst = "切换 · 火焰球",
    cryo_guard = "被动 · 冰盾与破冰",
    cryo_infusion = "主动 · 四次附魔",
    cryo_meteor = "爆发 · 冰冻领域",
}
local STATS = {
    {key = "health", label = "生命上限"},
    {key = "sanity", label = "理智上限"},
    {key = "hunger", label = "饱食上限"},
}

local function Art(parent, atlas, tex, x, y, size)
    local image = parent:AddChild(Image(atlas, tex))
    local w, h = image:GetSize()
    local scale = size / math.max(w, h, 1)
    image:SetSize(w * scale, h * scale)
    image:SetPosition(x, y)
    image:SetClickable(false)
    return image
end

local function EssenceArt(parent, id, x, y, size)
    local atlas, icon = Elements.EssenceIcon(id)
    return Art(parent, atlas, icon .. ".tex", x, y, size)
end

local function ElementArt(parent, id, x, y, size)
    local name = Elements[id].emblem
    if name then return Art(parent, "images/element/" .. name .. ".xml", name .. ".tex", x, y, size) end
    return EssenceArt(parent, id, x, y, size)
end

local function Hover(image, text, root)
    image:SetClickable(true)
    image:SetHoverText(text, {attach_to_parent = root, font = CHATFONT, font_size = 16,
        offset_y = 49, region_w = 250, region_h = 46, wordwrap = true})
end

local function RenderSkills(root, element)
    local index = 0
    for _, skill in ipairs(Skills) do
        if skill.element == element.name then
            local x = -72 + index * 125
            Style.Image(root, Style.paper, "scrap2_square.tex", x, 57, 64, 60):SetTint(.89, .80, .64, 1)
            local icon = Art(root, skill.atlas, skill.icon, x, 57, 54)
            HydroMotion.Attach(icon, skill.id, 54)
            Hover(icon, skill.hint, root)
            Label(root, 17, skill.name, x, 17)
            Label(root, 13, SKILL_CAPTIONS[skill.id], x, -4, Style.muted)
            index = index + 1
        end
    end
end

local function RenderFixed(root, id, active, allowed, choose)
    local element = Elements[id]
    local current = id == active
    local learned = element.playable and Elements.Has(allowed, element.bit)
    local r, g, b = Elements.Tint(id)
    Style.Image(root, Style.paper, "scrap2_wide.tex", 0, 76, 712, 198):SetTint(.96, .90, .78, 1)
    Style.Image(root, RING, "lumine_skill_ring.tex", -252, 89, 130, 130):SetTint(r, g, b, 1)
    ElementArt(root, id, -252, 89, element.emblem and 109 or 72)
    Label(root, 15, "元素已永久固定", -252, 8, Style.muted)
    Fill(root, -166, 75, 2, 152, Style.rule)

    Paragraph(root, 32, element.name .. "元素神像", -135, 152, 294, 42)
    if current then
        Label(root, 17, "当前已共鸣", 256, 127, Style.green)
    elseif learned then
        local button = Style.Button(root, "与此神像共鸣", 252, 125, 153,
            function() choose(id) end, 39, false, "primary")
        button:SetFocusChangeDir(MOVE_DOWN, root.closebutton)
        root.resonatebutton = button
    else
        Label(root, 16, element.playable and "需学习对应洞察节点" or "共鸣能力尚未开放", 252, 128, Style.muted)
    end

    if element.playable then
        RenderSkills(root, element)
    else
        Paragraph(root, 18, "这座神像可计入建造者的个人收藏。", -135, 82, 448, 31)
    end
end

local function RenderUnfixed(root)
    Style.Image(root, Style.paper, "scrap2_wide.tex", 0, 76, 712, 198):SetTint(.96, .90, .78, 1)
    Art(root, "images/inventoryimages/" .. STATUE .. ".xml", STATUE .. ".tex", -252, 79, 142)
    Fill(root, -166, 75, 2, 152, Style.rule)

    Paragraph(root, 30, "尚未供奉的神像", -135, 152, 465, 42)
    Paragraph(root, 17, "建造者可从物品栏拿起一种元素力，再右键神像供奉。", -135, 105, 466, 38)
    Paragraph(root, 16, "供奉后永久固定，并计入建造者的个人收藏。", -135, 72, 466, 33, Style.muted)
    for index, id in ipairs(Elements.order) do
        local x = -111 + (index - 1) * 65
        local icon = EssenceArt(root, id, x, 26, 38)
        Hover(icon, Elements[id].name .. "元素力", root)
        Label(root, 14, Elements[id].name, x, -3, Style.muted)
    end
end

local function RenderCollection(root, fixed, mask)
    local count = Elements.Count(mask)
    Paragraph(root, 21, "七神像收藏", -338, -36, 204, 31)
    Label(root, 18, ("个人收录  %d / %d"):format(count, #Elements.order), 281, -52, Style.muted)
    Fill(root, 0, -73, 686, 2, Style.rule)

    for index, id in ipairs(Elements.order) do
        local x = (index - 4) * 95
        local element = Elements[id]
        local collected = Elements.Has(mask, element.bit)
        local current = id == fixed
        local r, g, b = Elements.Tint(id)
        local ring = Style.Image(root, RING, "lumine_skill_ring.tex", x, -111, 51, 51)
        if current then
            ring:SetTint(r, g, b, 1)
        else
            ring:SetTint(.64, .58, .47, collected and .88 or .39)
        end
        local icon = ElementArt(root, id, x, -111, element.emblem and 42 or 35)
        if not collected then icon:SetTint(.65, .61, .54, current and .9 or .54) end
        Hover(icon, element.name .. "元素 · " .. (collected and "已收录" or "未收录")
            .. (current and " · 当前神像" or ""), root)
        if collected then
            Label(root, 16, "✓", x + 24, -93, Style.green)
        end
        Label(root, 14, element.name .. (current and " · 本座" or ""), x, -150, current and Style.accent or Style.muted)
    end

    Fill(root, 0, -168, 686, 2, Style.rule)
    for index, stat in ipairs(STATS) do
        local x = (index - 2) * 207 - 50
        Art(root, Style.paper, "icon_" .. stat.key .. ".tex", x, -189, 26)
        Label(root, 16, ("%s +%d"):format(stat.label, count * Elements.bonus[stat.key]), x + 65, -189, Style.ink)
    end
end

local ResonanceScreen = Class(Screen, function(self, owner, fixed, active, allowed, collection, onchoose, onview, onrefill)
    Screen._ctor(self, "LumineResonanceScreen")
    self.owner = owner
    self.is_popup = true

    local shade = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    shade.scale_on_focus = false
    shade.move_on_click = false
    shade.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade.image:SetHAnchor(ANCHOR_MIDDLE)
    shade.image:SetVAnchor(ANCHOR_MIDDLE)
    shade.image:SetTint(0, 0, 0, .65)
    shade:SetOnClick(function() self:Close() end)
    shade:SetHelpTextMessage("")

    local root = self:AddChild(Widget("lumine_resonance_root"))
    root:SetHAnchor(ANCHOR_MIDDLE)
    root:SetVAnchor(ANCHOR_MIDDLE)
    root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root = root
    local panel = root:AddChild(ImageButton(Style.paper, "scrap_square.tex"))
    panel.scale_on_focus = false
    panel.move_on_click = false
    panel:ForceImageSize(788, 520)
    panel:SetFocusScale(1, 1)
    panel:SetOnClick(function() end)
    panel:SetHelpTextMessage("")

    local active_id, fixed_id = Elements.by_wire[active], Elements.by_wire[fixed]
    Paragraph(root, 34, "七天神像", -335, 233, 226, 48)
    Label(root, 20, "自身共鸣 · " .. (active_id and Elements[active_id].name .. "元素" or "无元素"),
        251, 209, Style.accent)
    Fill(root, 0, 182, 686, 2, Style.rule)
    Fill(root, 0, -208, 686, 2, Style.rule)

    local view = Style.Button(root, "元素图鉴", -275, -230, 126, function()
        self:Close()
        onview()
    end, 34)
    local footer = {view}
    if active_id then
        footer[#footer + 1] = Style.Button(root, "回归无元素", -114, -230, 138,
            function() onchoose("none") end, 34)
    end
    if onrefill then
        local refill = Style.Button(root, "测试 · 补能并清冷却", 94, -230, 214, onrefill, 34)
        footer[#footer + 1] = refill
        self.refill = refill
    end
    self.closebutton = Style.Button(root, "关闭", 279, -230, 106, function() self:Close() end, 34)
    footer[#footer + 1] = self.closebutton
    for i = 2, #footer do
        footer[i]:SetFocusChangeDir(MOVE_LEFT, footer[i - 1])
        footer[i - 1]:SetFocusChangeDir(MOVE_RIGHT, footer[i])
    end
    self.default_focus = self.closebutton
    root.closebutton = self.closebutton
    if fixed_id then RenderFixed(root, fixed_id, active_id, allowed or 0, onchoose)
    else RenderUnfixed(root) end
    if root.resonatebutton then
        self.closebutton:SetFocusChangeDir(MOVE_UP, root.resonatebutton)
    end
    RenderCollection(root, fixed_id, collection or 0)
    owner._lumine_resonance_screen = self
end)

function ResonanceScreen:OnUpdate()
    if not self.refill or not self.owner:IsValid() or not self.owner._lumine_energy then return end
    local full = self.owner._lumine_energy:value() >= MAX_ENERGY
    if full ~= self.energy_full then
        self.energy_full = full
        self.refill:SetText(full and "测试 · 已满，可清冷却" or "测试 · 补能并清冷却")
    end
end

function ResonanceScreen:Close()
    if self.closed then return end
    self.closed = true
    TheFrontEnd:PopScreen(self)
end

function ResonanceScreen:OnDestroy()
    if self.owner ~= nil and self.owner._lumine_resonance_screen == self then
        self.owner._lumine_resonance_screen = nil
    end
    ResonanceScreen._base.OnDestroy(self)
end

function ResonanceScreen:OnControl(control, down)
    if ResonanceScreen._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_CANCEL or control == CONTROL_MENU_BACK or control == CONTROL_PAUSE) then
        self:Close()
    end
    return true
end

return ResonanceScreen
