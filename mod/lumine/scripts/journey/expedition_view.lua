local Style = require("journey/book_style")
local Image = require("widgets/image")
local Art = require("journey/native_art")
local Bosses = require("journey/boss_guides")
local Routes = require("journey/expedition_routes")
local Index = require("journey/expedition_index")
local Templates = require("widgets/redux/templates")

local M = {}
local Label, Paragraph, Button, Fill = Style.Label, Style.Paragraph, Style.Button, Style.Fill
local INK, MUTED, ACCENT = Style.ink, Style.muted, Style.accent
local LEFT, RIGHT, UP, DOWN = MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN
local all_bosses = {}
for _, group in ipairs(Bosses.groups) do
    for _, boss in ipairs(group.entries) do all_bosses[#all_bosses + 1] = boss end
end

local function Connect(a, direction, b, reverse)
    if a and b then
        a:SetFocusChangeDir(direction, b)
        b:SetFocusChangeDir(reverse, a)
    end
end

local function Line(parent, size, text, x, top, width, colour)
    return Paragraph(parent, size, text, x, top, width, size + 8, colour)
end

local function Icon(parent, id, x, y, size, tint)
    local art = Art.Get(id)
    if art then
        local image = parent:AddChild(Image(art.atlas, art.tex))
        local width, height = image:GetSize()
        local scale = size / math.max(1, width, height)
        image:SetSize(width * scale, height * scale)
        image:SetPosition(x, y)
        image:SetClickable(false)
        if tint then image:SetTint(unpack(tint)) end
        return image
    end
end
M.Icon = Icon

local function Frame(parent, x, y, width, height)
    Style.Image(parent, Style.paper, "scrap2_wide.tex", x, y, width, height)
end

local function Materials(parent, items, left, y, width)
    if not items then return end
    local gap = width / #items
    for i, item in ipairs(items) do
        local x = left + gap * (i - .5)
        local name = item[3] or STRINGS.NAMES[string.upper(item[1])] or item[1]
        if item[2] then name = name .. " ×" .. item[2] end
        Icon(parent, item[1], x, y, 42)
        Paragraph(parent, 14, name, x - gap / 2 + 4, y - 26, gap - 8, 41, MUTED):SetHAlign(ANCHOR_MIDDLE)
    end
end

local function Header(parent, path, title)
    Line(parent, 16, path, -486, 176, 970, MUTED)
    Line(parent, 31, title, -486, 146, 970, INK)
    Fill(parent, 0, 101, 968, 1, Style.rule)
end

function M.Search(screen, view, chapter_icon)
    local parent = screen.content
    local query = view.query or ""
    Line(parent, 28, "查找旅行手册", -486, 182, 350)
    local widget = parent:AddChild(Templates.StandardSingleLineTextEntry(query, 485, 44, CHATFONT, 24,
        "首领、路线步骤、材料或章节"))
    widget:SetPosition(81, 158)
    local field = widget.textbox
    field:SetTextLengthLimit(45)
    field:EnableScrollEditWindow(true)
    field:SetPassControlToScreen(CONTROL_PRIMARY, true)
    field:SetPassControlToScreen(CONTROL_SECONDARY, true)
    field.prompt:SetClickable(false)
    field:SetString(query)
    screen.guide_searchbox = field
    local function Submit()
        field:SetEditing(false)
        view.query = field:GetString():match("^%s*(.-)%s*$")
        view.page = 1
        screen:Render()
    end
    field.OnTextEntered = Submit
    local submit = Button(parent, "搜索", 380, 158, 102, Submit, 40, false, "primary")
    local clear = Button(parent, "清空", 467, 158, 64, function()
        view.query, view.page = "", 1
        screen:Render()
    end)
    Connect(field, RIGHT, submit, LEFT)
    Connect(submit, RIGHT, clear, LEFT)
    field:SetFocusChangeDir(UP, screen.backbutton)
    submit:SetFocusChangeDir(UP, screen.backbutton)
    clear:SetFocusChangeDir(UP, screen.backbutton)
    if query == "" then
        Line(parent, 17, "可输入名称或材料，例如「帝王蟹」「基底扩展器」「枯萎喉头」。", -486, 106, 970, MUTED)
        local previous
        for i, item in ipairs({{"首领目录", "directory"}, {"月亮路线", "lunar"}, {"暗影路线", "shadow"}}) do
            local button = Button(parent, item[1] .. " ›", -378+(i-1)*194, 47, 176,
                function() screen:OpenGuide(item[2]) end, 42)
            Connect(previous, RIGHT, button, LEFT)
            if i == 1 then Connect(field, DOWN, button, UP) end
            previous = button
        end
        return field
    end
    local results = Index.Search(query)
    local page_size = 8
    local first = (view.page - 1) * page_size + 1
    Line(parent, 17, #results > 0 and ("找到 " .. #results .. " 条结果") or "没有匹配结果，试试更短的名称。",
        -486, 110, 970, MUTED)
    local cards = {}
    for i=first, math.min(first+page_size-1, #results) do
        local entry, n = results[i], i-first
        local card = Style.Card(parent, (n%2-.5)*490, 49-math.floor(n/2)*82, 474, 72, function()
            if entry.chapter then screen:NavigateToChapter(entry.id)
            else screen:OpenGuide(entry.kind, entry.id, entry.page and entry) end
        end)
        if entry.chapter then chapter_icon(card, entry.chapter, -187, 0, 54)
        else Icon(card, entry.image, -187, 0, 54) end
        Line(card, 19, entry.title, -146, 26, 350)
        Line(card, 15, entry.path, -146, -5, 350, ACCENT)
        Label(card, 22, "›", 211, 0, ACCENT)
        cards[n+1] = card
        if n%2 == 1 then Connect(cards[n], RIGHT, card, LEFT) end
        Connect(cards[n-1], DOWN, card, UP)
    end
    Connect(field, DOWN, cards[1], UP)
    if cards[1] then submit:SetFocusChangeDir(DOWN, cards[1]) end
    local prev, next_page = screen:GuidePager(view, math.ceil(#results/page_size), 0)
    Connect(cards[#cards], DOWN, next_page, UP)
    Connect(prev, RIGHT, next_page, LEFT)
    return cards[1] or field
end

function M.Directory(screen, view)
    local parent = screen.content
    Line(parent, 24, "首领与特殊遭遇", -487, 184, 310)
    local find = Button(parent, "搜索首领或材料", 169, 164, 166, function() screen:OpenGuide("search") end, 33)
    local lunar = Button(parent, "月亮路线 ›", 322, 164, 114, function() screen:OpenGuide("lunar") end, 33, false, "link")
    local shadow = Button(parent, "暗影路线 ›", 441, 164, 114, function() screen:OpenGuide("shadow") end, 33, false, "link")
    Connect(lunar, RIGHT, shadow, LEFT)
    Connect(find, RIGHT, lunar, LEFT)
    local tabs, cards = {}, {}
    local groups = {{title="全部", entries=all_bosses}}
    for _, group in ipairs(Bosses.groups) do groups[#groups+1] = group end
    for i, group in ipairs(groups) do
        tabs[i] = Button(parent, group.title, (i-(#groups+1)/2)*121, 121, 115, function()
            view.group, view.page = i, 1
            screen:Render()
        end, 32, view.group == i)
        Connect(tabs[i-1], RIGHT, tabs[i], LEFT)
    end
    local group = groups[view.group]
    local page_size = 8
    local start = (view.page-1)*page_size + 1
    local pages = math.ceil(#group.entries / page_size)
    Label(parent, 16, #group.entries .. " 条遭遇", -377, 164, MUTED)
    for i=start, math.min(start+page_size-1, #group.entries) do
        local entry = group.entries[i]
        local n = i-start
        local card = Style.Card(parent, (n%2-.5)*490, 53-math.floor(n/2)*82, 474, 72,
            function() screen:OpenGuide("boss", entry.id) end)
        cards[n+1] = card
        if n%2 == 1 then Connect(cards[n], RIGHT, card, LEFT) end
        Connect(cards[n-1], DOWN, card, UP)
        Icon(card, entry.image, -186, 0, 57)
        Line(card, 21, entry.title, -140, 26, 342)
        Line(card, 15, entry.group .. "  ·  " .. entry.kind, -139, -7, 335, ACCENT)
        Label(card, 22, "›", 211, -1, ACCENT)
    end
    local prev, next_page = screen:GuidePager(view, pages, 0)
    for _, tab in ipairs(tabs) do tab:SetFocusChangeDir(DOWN, cards[1]) end
    for i = 1, #tabs-3 do tabs[i]:SetFocusChangeDir(UP, screen.backbutton) end
    Connect(find, DOWN, tabs[#tabs-2], UP)
    Connect(lunar, DOWN, tabs[#tabs-1], UP)
    Connect(shadow, DOWN, tabs[#tabs], UP)
    lunar:SetFocusChangeDir(UP, screen.backbutton)
    shadow:SetFocusChangeDir(UP, screen.backbutton)
    find:SetFocusChangeDir(UP, screen.backbutton)
    cards[1]:SetFocusChangeDir(UP, tabs[view.group])
    if cards[2] then cards[2]:SetFocusChangeDir(UP, tabs[view.group]) end
    local bottom = cards[#cards]
    Connect(bottom, DOWN, next_page, UP)
    if prev then Connect(prev, RIGHT, next_page, LEFT) end
    return tabs[view.group]
end

function M.Boss(screen, view)
    local entry = Bosses.by_id[view.id]
    local parent = screen.content
    Header(parent, "饥荒世界  /  首领指南  /  " .. entry.group, entry.title)
    Line(parent, 17, entry.kind, 244, 146, 146, ACCENT)
    Icon(parent, entry.image, 434, 151, 82)
    Fill(parent, 0, -41, 1, 267, Style.rule)
    local function Section(x, title, fields)
        Line(parent, 21, title, x, 87, 453, ACCENT)
        for i, field in ipairs(fields) do
            local top = 53-(i-1)*76
            Line(parent, 16, field[1], x, top, 450, ACCENT)
            Paragraph(parent, 18, field[2], x, top-23, 454, 55, INK)
        end
    end
    Section(-486, "寻找与召唤", {{"地点",entry.where},{"前置与触发",entry.trigger},{"行前准备",entry.prep}})
    Section(24, "战斗与奖励", {{"关键机制",entry.fight},{"战利品及用途",entry.loot},{"后续探索",entry.next_step}})
    if entry.items then
        Fill(parent, 0, -184, 968, 1, Style.rule)
        Line(parent, 16, "相关道具", -486, -196, 133, ACCENT)
        Materials(parent, entry.items, -354, -211, 826)
    end
    local shortcuts = {}
    local function Shortcut(title, click)
        local i = #shortcuts + 1
        shortcuts[i] = Button(screen.footer, title .. " ›", -150+(i-1)*151, -317, 145, click, 36)
        shortcuts[i]:SetTextSize(16)
        Connect(shortcuts[i-1], RIGHT, shortcuts[i], LEFT)
    end
    Shortcut("首领目录", function() screen:OpenGuide("directory") end)
    if entry.route then
        local route = Routes[entry.route]
        Shortcut(route.title, function() screen:OpenBossRoute(entry.route, entry.id) end)
    end
    for _, id in ipairs(entry.related or {}) do
        local target = Bosses.by_id[id]
        Shortcut(target.title, function() screen:OpenGuide("boss", id) end)
    end
    return shortcuts[1]
end

function M.Route(screen, view)
    local route = Routes[view.kind]
    local parent = screen.content
    local stage = route.stages[view.page]
    Header(parent, "饥荒世界  /  探索路线", route.title)
    Line(parent, 16, route.intro, -486, 119, 720, MUTED)
    local tabs = {}
    for i, phase in ipairs(route.stages) do
        local button = Button(parent, tostring(i) .. " · " .. phase.title, (i-3)*197, 75, 191, function()
            view.page, view.lane, view.step = i, 1, 1
            screen:Render()
        end, 32, view.page==i)
        button:SetTextSize(15)
        tabs[i] = button
        button:SetFocusChangeDir(UP, screen.backbutton)
        Connect(tabs[i-1], RIGHT, button, LEFT)
    end
    local lane_count = #stage.lanes
    local lane_width = math.floor(472/lane_count)
    Fill(parent, 0, -98, 1, 302, Style.rule)
    local nodes = {}
    for i, lane in ipairs(stage.lanes) do
        nodes[i] = {}
        local x = -488 + lane_width * (i-.5)
        Line(parent, 16, lane.title, x-lane_width/2+5, 43, lane_width-10, ACCENT)
        for j, step in ipairs(lane.steps) do
            local y = 6-(j-1)*43
            local node = Style.Card(parent, x, y, lane_width-9, 35, function()
                view.lane, view.step = i, j
                screen:Render()
            end, view.lane==i and view.step==j)
            nodes[i][j] = node
            Connect(nodes[i][j-1], DOWN, node, UP)
            if i > 1 then Connect(nodes[i-1][j], RIGHT, node, LEFT) end
            if j == 1 then node:SetFocusChangeDir(UP, tabs[view.page]) end
            Icon(node, step.image, -(lane_width-9)/2+19, 0, 25)
            Line(node, lane_count == 3 and 14 or 16, step.title, -(lane_width-9)/2+34, 12, lane_width-41, INK)
            if j < #lane.steps then Label(parent, 15, "↓", x, y-22, ACCENT) end
        end
    end
    if lane_count > 1 then
        Line(parent, 15, view.page < #route.stages and "各支可并行，完成后查阅下一阶段。" or "各支可并行。",
            -482, -226, 478, MUTED)
    end
    local selected = stage.lanes[view.lane].steps[view.step]
    Frame(parent, 439, 9, 85, 76)
    Icon(parent, selected.image, 439, 9, 69)
    Paragraph(parent, 24, selected.title, 26, 40, 357, 65, ACCENT)
    Paragraph(parent, 20, selected.text, 26, -36, 453, 103, INK)
    if selected.items then
        Fill(parent, 252, -139, 451, 1, Style.rule)
        Line(parent, 15, "相关道具", 26, -149, 450, ACCENT)
        Materials(parent, selected.items, 22, -193, 463)
    end
    local boss_button
    if selected.boss then
        boss_button = Button(screen.footer, Bosses.by_id[selected.boss].title .. " ›", 274, -317, 190, function()
            screen:OpenGuide("boss", selected.boss)
        end, 36)
    end
    local prev, next_page = screen:GuidePager(view, #route.stages, 0,
        function() view.lane,view.step=1,1 end)
    local focus = nodes[view.lane][view.step]
    local last_node = nodes[view.lane][#nodes[view.lane]]
    for _, tab in ipairs(tabs) do tab:SetFocusChangeDir(DOWN, focus) end
    Connect(last_node, DOWN, next_page, UP)
    Connect(prev, RIGHT, next_page, LEFT)
    if boss_button then Connect(nodes[#nodes][1], RIGHT, boss_button, LEFT) end
    return focus
end

return M
