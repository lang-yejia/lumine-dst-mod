local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local UIAnim = require("widgets/uianim")
local Data = require("lumine_progression")
local Catalog = require("journey/catalog")
local Artifacts = require("lumine_artifact_data")
local Forge = require("lumine_forging_data")
local Gear = require("lumine_gear_stats")
local Style = require("journey/book_style")
local NativeArt = require("journey/native_art")
local Expedition = require("journey/expedition_view")
local Bosses = require("journey/boss_guides")
local GuideIndex = require("journey/expedition_index")

local Fill, Label, Button, Paragraph = Style.Fill, Style.Label, Style.Button, Style.Paragraph
local WHITE, MUTED = Style.ink, Style.muted
local ATLAS = "images/inventoryimages.xml"
local forge_indices = {}
for i, prefab in ipairs(Forge.ORDER) do forge_indices[prefab] = i end
local FILTERS = {
    {id = "explore", name = "探索记录"},
    {id = "evidence", name = "证物记录"},
    {id = "collection", name = "百科收藏"},
}
local VOLUME_NUMERALS = {"一", "二", "三", "四"}
local ROMAN_NUMERALS = {"I", "II", "III", "IV"}
local UNLOCK_NAME = {}
for _, filter in ipairs(FILTERS) do UNLOCK_NAME[filter.id] = filter.name end

local function ChapterReward(chapter)
    local sum = 0
    for _, id in ipairs(chapter.milestones or {}) do
        sum = sum + Data.MILESTONES[Catalog.milestone_index[id]].reward
    end
    if sum == 0 then return UNLOCK_NAME[chapter.unlock] end
    return (#chapter.milestones > 1 and "共 " or "+") .. sum .. " 见闻"
end

local function HasBit(mask, index)
    return math.floor(mask / 2 ^ (index - 1)) % 2 == 1
end

local function Name(prefab)
    return STRINGS.NAMES[string.upper(prefab)] or prefab
end

local function ItemImage(prefab)
    return {atlas = "images/inventoryimages/" .. prefab .. ".xml", tex = prefab .. ".tex"}
end

local function ForgeImage(prefab)
    return {atlas = Catalog.forge_icons[prefab] or ATLAS, tex = prefab .. ".tex"}
end

local function Icon(parent, image, x, y, size)
    if not image.anim then return Style.Image(parent, image.atlas, image.tex, x, y, size, size) end
    local icon = parent:AddChild(UIAnim())
    local anim = icon:GetAnimState()
    anim:SetBank(image.anim)
    anim:SetBuild(image.anim)
    anim:PlayAnimation(image.clip, true)
    icon:SetScale(size / 100 * image.scale)
    icon:SetPosition(x, y)
    icon:SetClickable(false)
    return icon
end

local function ChapterIcon(parent, chapter, x, y, size, tint)
    local key = NativeArt.chapters[chapter.id]
    if key and Expedition.Icon(parent, key, x, y, size, tint) then return end
    local icon = Icon(parent, chapter.image, x, y, size)
    if tint and not chapter.image.anim then icon:SetTint(unpack(tint)) end
end

local function Left(parent, size, value, x, top, width, colour)
    return Paragraph(parent, size, value, x, top, width, size + 9, colour)
end

local function NetValue(owner, field)
    local net = owner[field]
    return net and net:value() or ""
end

local function SetSelection(button, selected)
    if selected and not button:IsSelected() then button:Select()
    elseif not selected and button:IsSelected() then button:Unselect() end
end

local function SplitBody(text)
    local _, boundary = text:find("。", 1, true)
    if boundary and boundary < #text then
        return text:sub(1, boundary), text:sub(boundary + 1)
    end
    return text
end

local Journal = Class(Screen, function(self, owner, mask, insight, available, test_enabled, ontest, experienced, recording)
    Screen._ctor(self, "LumineTravelJournal")
    self.owner, self.ontest = owner, ontest
    self.is_popup = true
    self.category, self.page, self.history = "home", 1, {}

    local shade = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    shade.scale_on_focus, shade.move_on_click = false, false
    shade.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade.image:SetHAnchor(ANCHOR_MIDDLE)
    shade.image:SetVAnchor(ANCHOR_MIDDLE)
    shade.image:SetTint(0, 0, 0, .69)
    shade:SetOnClick(function() self:Close() end)
    shade:SetHelpTextMessage("")

    self.root = self:AddChild(Widget("travel_journal_root"))
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root:SetScale(.92)
    local backing = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    backing:ForceImageSize(1104, 720)
    backing.image:SetTint(.22,.14,.09,1)
    backing.scale_on_focus, backing.move_on_click = false, false
    backing:SetOnClick(function() end)
    backing:SetHelpTextMessage("")
    Style.Image(self.root, Style.paper, "scrap_square.tex", 0, 0, 1090, 710)
    Fill(self.root, 0, 264, 1020, 1, Style.rule)
    Fill(self.root, 0, 198, 1020, 1, Style.rule)
    Fill(self.root, 0, -282, 1020, 1, Style.rule)

    self.content = self.root:AddChild(Widget("journal_page"))
    self.footer = self.root:AddChild(Widget("journal_page_controls"))
    Icon(self.root, ItemImage("lumine_journal"), -471, 302, 60)
    self.title = Left(self.root, 33, "旅行手册", -423, 324, 510)
    self.total = Label(self.root, 18, "", 115, 303, MUTED)
    self.tabs = {}
    self.tabs.home = Button(self.root, "封面", -448, 230, 103, function() self:OpenVolume("home") end, 38, false, "tab")
    for i, volume in ipairs(Catalog.volumes) do
        local id = volume.id
        self.tabs[id] = Button(self.root, "第" .. VOLUME_NUMERALS[i] .. "卷 · " .. volume.title,
            -302 + (i - 1) * 174, 230, 163, function() self:OpenVolume(id) end, 38, false, "tab")
        self.tabs[id].AllowOnControlWhenSelected = true
    end
    if test_enabled then
        self.testbutton = Button(self.root, "测试 · 完成见闻", 257, 303, 122,
            function() if self.ontest then self.ontest() end end)
        self.testbutton:SetTextSize(14)
    end
    self.searchbutton = Button(self.root, "查找手册", 425, 230, 150,
        function() self:OpenGuide("search") end, 38, false, "tab")
    self.backbutton = Button(self.root, "‹ 返回", 421, 303, 161,
        function() self:Back() end, 42, false, "primary")

    self.closebutton = Button(self.root, "合上手册", 446, -317, 120, function() self:Close() end, 38, false, "primary")
    self.equipmentbutton = Button(self.root, "装备见闻", -434, -317, 124,
        function() self:OpenVolume("treasures", "武器与护甲") end)
    self.default_focus = self.closebutton
    owner._lumine_journal_screen = self
    self:StartUpdating()
    self:Refresh(mask, insight, available, experienced, recording)
end)

function Journal:OpenVolume(id, group)
    self.category, self.page, self.group, self.unlock_filter = id, 1, group, nil
    self.open_chapter = nil
    self.guide, self.history = nil, {}
    self:Render()
end

function Journal:RememberPage()
    self.history[#self.history + 1] = {
        guide=self.guide, chapter=self.open_chapter, season=self.season,
        gear_row=self.gear_row, gear_step=self.gear_step,
    }
end

function Journal:OpenGuide(kind, id, target)
    if self.guide and self.guide.kind == kind and self.guide.id == id and not target then return end
    self:RememberPage()
    self.open_chapter = nil
    self.guide = {kind=kind, id=id, group=1, page=1, lane=1, step=1}
    if target then
        self.guide.page, self.guide.lane, self.guide.step = target.page or 1, target.lane or 1, target.step or 1
    end
    self:Render()
    if kind == "search" and not TheInput:ControllerAttached() then
        self.guide_searchbox:SetEditing(true)
    end
end

function Journal:OpenBossRoute(kind, id)
    self:OpenGuide(kind, nil, GuideIndex.BossStep(kind, id))
end

function Journal:Back()
    local previous = table.remove(self.history)
    if previous then
        self.guide, self.open_chapter, self.season = previous.guide, previous.chapter, previous.season
        self.gear_row, self.gear_step = previous.gear_row, previous.gear_step
        self:Render()
    elseif self.category ~= "home" then self:OpenVolume("home")
    else self:Close() end
end

function Journal:BackLabel()
    local previous = self.history[#self.history]
    if previous then
        if previous.chapter then return "返回上一章" end
        if previous.guide then
            local kind = previous.guide.kind
            if kind == "search" then return "返回搜索" end
            if kind == "directory" then return "返回首领目录" end
            if kind == "boss" then return "返回首领详情" end
            return "返回路线"
        end
        return self.category == "home" and "返回封面" or "返回目录"
    end
    if self.category ~= "home" then return "返回封面" end
end

function Journal:GuidePager(view, pages, x, on_turn)
    if pages <= 1 then return end
    local function Turn(change)
        view.page = math.max(1, math.min(pages, view.page + change))
        if on_turn then on_turn() end
        self:Render()
    end
    local prev = Button(self.footer, "上一页", x-102, -317, 90, function() Turn(-1) end)
    local next_page = Button(self.footer, "下一页", x+102, -317, 90, function() Turn(1) end)
    Label(self.footer, 16, view.page .. " / " .. pages, x, -317, MUTED)
    if view.page == 1 then prev:Disable() end
    if view.page == pages then next_page:Disable() end
    return prev, next_page
end

function Journal:NavigateToChapter(id)
    local chapter = Catalog.Find(id)
    if not chapter then return end
    if self.open_chapter == chapter.id then return end
    if not self.open_chapter and not self.guide then self.last_chapter = chapter.id end
    self:RememberPage()
    self.guide = nil
    self.open_chapter, self.season, self.gear_row, self.gear_step = chapter.id, 1, 1, 2
    for i, season in ipairs(chapter.seasons or {}) do
        if season.id == id then self.season = i break end
    end
    self:Render()
end

function Journal:MilestoneStatus(id)
    local index = Catalog.milestone_index[id]
    local evidence = Data.EVIDENCE[id]
    if HasBit(self.mask, index) then return evidence and "已记录" or "已体验", Style.green end
    if self.active_index == index or self.recording == index then return "记录中", Style.accent end
    if evidence and HasBit(self.experienced, index) then return "待交证物", Style.accent end
    return "待探索", MUTED
end

function Journal:CollectionStatus(chapter)
    local owned = self.artifacts:match("^([01]+):[0123]:[0123]$") or ""
    local count = 0
    for index, piece in ipairs(Artifacts.ALL) do
        if (not chapter or piece.set == chapter.relic_set) and owned:sub(index, index) == "1" then
            count = count + 1
        end
    end
    return owned, count
end

function Journal:ChapterStatus(chapter)
    if chapter.relic_set then
        local _, count = self:CollectionStatus(chapter)
        return "已收录 " .. count .. "/5", count > 0 and Style.green or MUTED, count > 0
    elseif chapter.seasons then
        local count = 0
        for _, id in ipairs(chapter.milestones) do
            if HasBit(self.mask, Catalog.milestone_index[id]) then count = count + 1 end
        end
        local complete = count == #chapter.milestones
        return "已体验 " .. count .. "/" .. #chapter.milestones, complete and Style.green or MUTED, true, complete
    elseif chapter.milestones then
        local id = chapter.milestones[1]
        local status, colour = self:MilestoneStatus(id)
        return status, colour, HasBit(self.mask, Catalog.milestone_index[id])
    end
    return "可阅读", Style.green, true
end

function Journal:ReadLiveStatus()
    local status = NetValue(self.owner, "_lumine_journal_status")
    local artifacts = NetValue(self.owner, "_lumine_artifacts")
    local gear = NetValue(self.owner, "_lumine_gear_progress")
    local changed = status ~= self.live_status
    local collection_changed = artifacts ~= self.artifacts
    local gear_changed = gear ~= self.gear
    local structure_changed = false
    if changed then
        self.live_status = status
        local recent, active, remaining, pending, issues = status:match("^(%d+):(%d+):(%d+):(%d+):(%d+)$")
        structure_changed = self.recent ~= (tonumber(recent) or 0)
            or self.active_index ~= (tonumber(active) or 0)
            or self.pending ~= tonumber(pending) or self.issues ~= (tonumber(issues) or 0)
        self.recent, self.active_index, self.remaining = tonumber(recent) or 0, tonumber(active) or 0, tonumber(remaining)
        self.pending, self.issues = tonumber(pending), tonumber(issues) or 0
    end
    self.artifacts, self.gear = artifacts, gear
    return structure_changed, collection_changed, gear_changed, changed
end

function Journal:OnUpdate(dt)
    self.next_refresh = (self.next_refresh or 0) - (dt or 0)
    if self.next_refresh > 0 or not self.mask then return end
    self.next_refresh = .35
    local live, collection, gear, timer = self:ReadLiveStatus()
    if self.guide then return end
    local chapter = self.open_chapter and Catalog.by_id[self.open_chapter]
    if self.home_activity then
        if collection then self:Render()
        elseif live or timer then self:RefreshHomeActivity() end
    elseif collection or live or (gear and chapter and chapter.routes) then
        self:Render()
    elseif timer then
        local recording_text = self.paimon_recording_text
        if recording_text then recording_text:SetString(self:RecordingDescription()) end
    end
end

function Journal:Refresh(mask, insight, available, experienced, recording)
    self.mask, self.insight = tonumber(mask) or 0, tonumber(insight) or 0
    self.available = tonumber(available) or self.insight
    self.experienced, self.recording = tonumber(experienced) or self.mask, tonumber(recording) or 0
    self:ReadLiveStatus()
    self.total:SetString("可用见闻 " .. self.available .. "  /  累计 " .. self.insight)
    if self.testbutton then
        if self.mask == 2 ^ #Data.MILESTONES - 1 then self.testbutton:Disable()
        else self.testbutton:Enable() end
    end
    if not self.guide then self:Render() end
end

function Journal:Render()
    if self.guide_searchbox then
        self.guide_searchbox:SetEditing(false)
        self.guide_searchbox = nil
    end
    local was_home = self.home_activity ~= nil
    self.home_activity = nil
    self.paimon_recording_text = nil
    self.content:KillAllChildren()
    self.footer:KillAllChildren()
    local chapter = self.open_chapter and Catalog.Find(self.open_chapter)
    local selected = self.guide and self.guide.kind ~= "search" and "world"
        or not self.guide and (chapter and chapter.volume_id or self.category)
    local cover = not self.guide and not chapter and self.category == "home"
    for id, tab in pairs(self.tabs) do
        if cover and id ~= "home" then tab:Hide() else tab:Show() end
        SetSelection(tab, selected == id)
    end
    if cover then self.total:Hide() else self.total:Show() end
    SetSelection(self.searchbutton, self.guide and self.guide.kind == "search")
    local back = self:BackLabel()
    if back then
        self.backbutton:SetText("‹ " .. back)
        self.backbutton:Show()
    else self.backbutton:Hide() end
    self.backbutton:SetFocusChangeDir(MOVE_DOWN, nil)
    self.searchbutton:SetFocusChangeDir(MOVE_UP, back and self.backbutton or nil)
    if was_home and not cover then
        self.tabs.home:SetFocusChangeDir(MOVE_RIGHT, nil)
        self.tabs.home:SetFocusChangeDir(MOVE_DOWN, nil)
        self.searchbutton:SetFocusChangeDir(MOVE_LEFT, nil)
        self.searchbutton:SetFocusChangeDir(MOVE_DOWN, nil)
        self.equipmentbutton:SetFocusChangeDir(MOVE_UP, nil)
        self.equipmentbutton:SetFocusChangeDir(MOVE_RIGHT, nil)
        self.closebutton:SetFocusChangeDir(MOVE_UP, nil)
        self.closebutton:SetFocusChangeDir(MOVE_LEFT, nil)
    end
    SetSelection(self.equipmentbutton, not chapter and self.category == "treasures" and self.group == "武器与护甲")
    if self.guide then
        local view = self.guide
        local focus
        if view.kind == "search" then focus = Expedition.Search(self, view, ChapterIcon)
        elseif view.kind == "directory" then focus = Expedition.Directory(self, view)
        elseif view.kind == "boss" then focus = Expedition.Boss(self, view)
        else focus = Expedition.Route(self, view) end
        self.backbutton:SetFocusChangeDir(MOVE_DOWN, focus)
        if focus then
            if not focus.focus_flow[MOVE_UP] then focus:SetFocusChangeDir(MOVE_UP, self.backbutton) end
            if TheInput:ControllerAttached() then focus:SetFocus() end
        end
    elseif chapter then self:RenderChapter(chapter)
    elseif self.category == "home" then self:RenderHome()
    else self:RenderDirectory() end
end

function Journal:DrawPager(pages)
    if pages <= 1 then return end
    local prev = Button(self.footer, "上一页", -104, -317, 94, function()
        self.page = self.page - 1
        self:Render()
    end)
    local next_page = Button(self.footer, "下一页", 104, -317, 94, function()
        self.page = self.page + 1
        self:Render()
    end)
    if self.page <= 1 then prev:Disable() end
    if self.page >= pages then next_page:Disable() end
    Label(self.footer, 17, self.page .. " / " .. pages, 0, -317, MUTED)
end

local function ChapterAt(index)
    local milestone = Data.MILESTONES[index]
    return milestone and Catalog.by_milestone[milestone.id]
end

function Journal:RecordingDescription()
    local recording = ChapterAt(self.active_index > 0 and self.active_index or self.recording)
    if not recording then return "派蒙正在等下一件证物。" end
    if self.owner:HasTag("playerghost") then return recording.title .. " · 记录暂停" end
    return recording.title .. (self.remaining and self.active_index > 0
        and (" · 余 " .. self.remaining .. " 秒") or "")
end

function Journal:FindLead()
    local active = self.pending ~= nil and self.active_index or self.recording
    for _, list in ipairs({Data.RECORD, Data.EXPERIENCE}) do
        for _, entry in ipairs(list) do
            if not HasBit(self.mask, entry.index) and entry.index ~= active
                and (list == Data.EXPERIENCE or HasBit(self.experienced, entry.index)) then
                return entry.milestone
            end
        end
    end
    for _, entry in ipairs(Data.RECORD) do
        if not HasBit(self.mask, entry.index) and entry.index ~= active then
            return entry.milestone
        end
    end
end

function Journal:GetHomeActivity()
    local active = self.pending ~= nil and self.active_index or self.recording
    local recording = ChapterAt(active)
    if recording then
        local detail = self.owner:HasTag("playerghost") and "记录暂停，复活后继续。"
            or self.remaining and self.active_index == active and ("派蒙还需 %d 秒。"):format(self.remaining)
            or "派蒙正在整理这件证物。"
        return "正在记录 · " .. recording.title, detail, Data.MILESTONES[active].id
    end
    if (self.pending or 0) > 0 then
        return "待返还证物", ("还有 %d 件证物，给派蒙背包腾个空位。"):format(self.pending), "lumine_paimon"
    end
    if (self.issues or 0) > 0 then
        return "证物记录需处理", ("派蒙的记录夹有 %d 项待修复。"):format(self.issues), "lumine_paimon"
    end
    local milestone = self:FindLead()
    local _, collected = self:CollectionStatus()
    local recent = ChapterAt(self.recent)
    if recent and (milestone or collected < #Artifacts.ALL) then
        return "最近发现 · " .. recent.title, recent.intro, Data.MILESTONES[self.recent].id
    end
    if milestone then
        local clue = Data.EVIDENCE[milestone.id] and HasBit(self.experienced, Catalog.milestone_index[milestone.id])
            and "带上对应证物，交给派蒙记录。" or milestone.hint
        return "下一段路 · " .. milestone.name, clue, milestone.id
    end
    if collected < #Artifacts.ALL then
        return "继续收集圣遗物", "探索记录已齐，旅途珍藏还有空位。", "lumine_relic"
    end
    return "本册旅程已完成", "探索记录和圣遗物均已收齐。"
end

function Journal:RefreshHomeActivity()
    local activity = self.home_activity
    local title, detail, id = self:GetHomeActivity()
    activity.title:SetString(title)
    activity.detail:SetString(detail)
    activity.target = id
    if id then activity.button:Show() else activity.button:Hide() end
end

function Journal:RenderHome()
    local indexed, chapters = 0, 0
    local volume_progress = {}
    for _, volume in ipairs(Catalog.volumes) do
        local count = 0
        for _, chapter in ipairs(volume.entries) do
            local _, _, readable, complete = self:ChapterStatus(chapter)
            if readable and complete ~= false then count = count + 1 end
        end
        volume_progress[volume.id] = count
        indexed, chapters = indexed + count, chapters + #volume.entries
    end
    local _, collected = self:CollectionStatus()
    Left(self.content, 24, "旅途进度", -484, 177, 460)
    Label(self.content, 28, indexed .. " / " .. chapters, -411, 117, Style.accent)
    Label(self.content, 28, tostring(self.insight), -255, 117, Style.accent)
    Label(self.content, 28, collected .. " / " .. #Artifacts.ALL, -95, 117, Style.accent)
    Label(self.content, 15, "已收录章节", -411, 86, MUTED)
    Label(self.content, 15, "累计获得见闻", -255, 86, MUTED)
    Label(self.content, 15, "已收集圣遗物", -95, 86, MUTED)
    local width = 456
    Fill(self.content, -484 + width / 2, 58, width, 6, Style.wash)
    local progress = width * indexed / chapters
    if progress > 0 then Fill(self.content, -484 + progress / 2, 58, progress, 6, Style.green) end
    Fill(self.content, 0, 95, 1, 164, Style.rule)
    Left(self.content, 18, "派蒙留言", 27, 176, 445, Style.accent)
    Paragraph(self.content, 16, Catalog.by_id.lumine_paimon.comment, 27, 148, 460, 43, MUTED)
    Left(self.content, 18, "继续旅程", 27, 101, 445, Style.accent)
    local activity = {}
    self.home_activity = activity
    activity.title = Left(self.content, 20, "", 27, 71, 345)
    activity.detail = Paragraph(self.content, 16, "", 27, 41, 461, 44, MUTED)
    activity.button = Button(self.content, "查看 ›", 440, 60, 94, function()
        if activity.target then self:NavigateToChapter(activity.target) end
    end, 30, false, "link")
    self:RefreshHomeActivity()

    Fill(self.content, 0, -12, 976, 1, Style.rule)
    local cards = {}
    for i, volume in ipairs(Catalog.volumes) do
        local id, feature = volume.id, Catalog.by_id[volume.feature]
        local card = Style.Card(self.content, (i - 2.5) * 246, -139, 234, 220, function()
            self:OpenVolume(id)
        end, false, "scrap2_tall.tex")
        local r, g, b = unpack(volume.ink)
        card:SetImageNormalColour(.88 + r * .13, .79 + g * .14, .67 + b * .16, 1)
        card:SetImageFocusColour(1, .97, .86, 1)
        local outline = Fill(card, 0, -103, 174, 2, volume.ink)
        outline:Hide()
        card:SetOnGainFocus(function() outline:Show() end)
        card:SetOnLoseFocus(function() outline:Hide() end)
        cards[i] = card
        Fill(card, 0, 98, 170, 3, volume.ink)
        Label(card, 16, "第" .. VOLUME_NUMERALS[i] .. "卷", 0, 77, volume.ink)
        ChapterIcon(card, feature, 0, 31, 74)
        Label(card, 23, volume.title, 0, -24, volume.ink)
        Label(card, 15, volume.subtitle, 0, -53, MUTED)
        Fill(card, 0, -72, 162, 1, Style.rule)
        Label(card, 15, "收录 " .. volume_progress[id] .. " / " .. #volume.entries .. "  ›", 0, -91, volume.ink)
    end
    for i, card in ipairs(cards) do
        card:SetFocusChangeDir(MOVE_LEFT, cards[i - 1])
        card:SetFocusChangeDir(MOVE_RIGHT, cards[i + 1])
        card:SetFocusChangeDir(MOVE_UP, i < 3 and self.tabs.home or function()
            return activity.target and activity.button or self.searchbutton
        end)
        card:SetFocusChangeDir(MOVE_DOWN, i < 3 and self.equipmentbutton or self.closebutton)
    end
    activity.button:SetFocusChangeDir(MOVE_UP, self.searchbutton)
    activity.button:SetFocusChangeDir(MOVE_DOWN, cards[4])
    self.tabs.home:SetFocusChangeDir(MOVE_RIGHT, self.searchbutton)
    self.tabs.home:SetFocusChangeDir(MOVE_DOWN, cards[1])
    self.searchbutton:SetFocusChangeDir(MOVE_LEFT, self.tabs.home)
    self.searchbutton:SetFocusChangeDir(MOVE_DOWN, function()
        return activity.target and activity.button or cards[4]
    end)
    self.equipmentbutton:SetFocusChangeDir(MOVE_UP, cards[1])
    self.equipmentbutton:SetFocusChangeDir(MOVE_RIGHT, self.closebutton)
    self.closebutton:SetFocusChangeDir(MOVE_UP, cards[4])
    self.closebutton:SetFocusChangeDir(MOVE_LEFT, self.equipmentbutton)
    if TheInput:ControllerAttached() then cards[1]:SetFocus() end
end

function Journal:RenderDirectory()
    local volume = Catalog.by_volume[self.category]
    local entries = {}
    for _, chapter in ipairs(volume.entries) do
        if (not self.group or chapter.group == self.group)
            and (not self.unlock_filter or chapter.unlock == self.unlock_filter) then
            entries[#entries + 1] = chapter
        end
    end
    local function Filter(group, unlock)
        self.group, self.unlock_filter, self.page = group, unlock, 1
        self:Render()
    end
    Left(self.content, 24, volume.title, -486, 183, 152, volume.ink)
    Button(self.content, "全卷", -304, 168, 76, function() Filter(nil, self.unlock_filter) end, 31, not self.group)
    for i, group in ipairs(volume.groups) do
        Button(self.content, group, -203 + (i - 1) * 132, 168, 124,
            function() Filter(group, self.unlock_filter) end, 31, self.group == group)
    end
    Left(self.content, 15, "解锁方式", -486, 132, 88, MUTED)
    Button(self.content, "不限", -368, 121, 62, function() Filter(self.group, nil) end, 27, not self.unlock_filter, "link")
    for i, filter in ipairs(FILTERS) do
        Button(self.content, filter.name, -291 + (i - 1) * 99, 121, 92,
            function() Filter(self.group, filter.id) end, 27, self.unlock_filter == filter.id, "link")
    end
    if volume.id == "world" then
        Button(self.content, "首领指南 ›", 205, 121, 112, function() self:OpenGuide("directory") end, 27, false, "link")
    end
    Label(self.content, 16, #entries .. " / " .. #volume.entries .. " 章", 442, 121, MUTED)

    local page_size = 4
    local pages = math.max(1, math.ceil(#entries / page_size))
    self.page = math.min(self.page, pages)
    local first = (self.page - 1) * page_size + 1
    for i = first, math.min(first + page_size - 1, #entries) do
        local chapter, position = entries[i], i - first
        local card = Style.Card(self.content, (position % 2 - .5) * 496,
            23 - math.floor(position / 2) * 173, 479, 153,
            function() self:NavigateToChapter(chapter.id) end)
        local status, colour, unlocked = self:ChapterStatus(chapter)
        local subdued = not unlocked and {.57,.50,.42,1} or nil
        local mat = Style.Image(card, Style.paper, "scrap2_square.tex", -145, 1, 111, 105)
        mat:SetTint(.79,.69,.53,.62)
        ChapterIcon(card, chapter, -145, 1, 88, subdued)
        local bookmark = self.last_chapter == chapter.id and "  ·  上次翻阅" or ""
        Left(card, 14, string.format("%02d  ·  %s", chapter.number, chapter.group) .. bookmark, -54, 57, 269, volume.ink)
        Left(card, 22, chapter.title, -54, 31, 274)
        local preview = Paragraph(card, 16, chapter.intro, -54, -2, 273, 44, MUTED)
        preview:SetMultilineTruncatedString(chapter.intro, 2, 273, nil, "…")
        Left(card, 15, status .. "  ·  " .. ChapterReward(chapter), -54, -49, 253, colour)
        Label(card, 22, "›", 215, -53, volume.ink)
    end
    if #entries == 0 then
        Label(self.content, 23, "当前筛选下没有章节", 0, 12, MUTED)
        Button(self.content, "显示全卷", 0, -36, 130, function() Filter(nil, nil) end)
    end
    self:DrawPager(pages)
end

local function EvidenceText(evidence)
    if type(evidence) == "string" then return Name(evidence) end
    local names = {}
    for _, prefab in ipairs(evidence) do names[#names + 1] = Name(prefab) end
    return table.concat(names, " / ")
end

function Journal:DrawEntryNote(chapter, x, top, width)
    local status, colour = self:ChapterStatus(chapter)
    local id = chapter.milestones and chapter.milestones[1]
    local milestone = id and Data.MILESTONES[Catalog.milestone_index[id]]
    local evidence = id and Data.EVIDENCE[id]
    Style.Image(self.content, Style.paper, "scrap2_wide.tex", x + width / 2, top - 47, width, 94)
    local inset = 14
    if type(evidence) == "string" and chapter.image.tex == evidence .. ".tex" then
        Icon(self.content, chapter.image, x + 43, top - 44, 50)
        inset = 76
    end
    local left, text_width = x + inset, width - inset - 14
    Left(self.content, 17, status, left, top - 8, text_width, colour)
    if milestone then
        Left(self.content, 16, (evidence and "证物 · " .. EvidenceText(evidence) or "探索记录") ..
            "   ·   +" .. milestone.reward .. " 见闻", left, top - 32, text_width, Style.accent)
        local hint = status == "待交证物" and "已亲历。手持证物交给派蒙，完成后原物返还。" or milestone.hint
        Paragraph(self.content, 15, hint, left, top - 56, text_width, 34, MUTED)
    else
        Paragraph(self.content, 17, "百科收藏 · 随旅行手册开放", left, top - 40, text_width, 42, MUTED)
    end
end

function Journal:DrawComment(chapter, x, top, width)
    Fill(self.content, x + 2, top - 34, 3, 64, Style.rule)
    Left(self.content, 17, "派蒙手记", x + 14, top - 3, width - 26, Style.accent)
    Paragraph(self.content, 16, chapter.comment, x + 14, top - 28, width - 26, 40, MUTED)
end

function Journal:DrawOrdinaryChapter(chapter, unlocked)
    Paragraph(self.content, 22, chapter.intro, -486, 86, 467, 62, Style.accent)
    local first, second = SplitBody(chapter.body)
    if unlocked then
        Paragraph(self.content, 19, first, -486, 9, 467, 57)
        if second then Paragraph(self.content, 19, second, -486, -62, 467, 96) end
    else
        Paragraph(self.content, 19, "完成右页的记录条件后，正文与派蒙手记会展开。", -486, 4, 467, 86, MUTED)
    end
    Fill(self.content, 6, -81, 1, 344, Style.rule)
    Style.Image(self.content, Style.paper, "scrap2_wide.tex", 254, -16, 440, 198)
    ChapterIcon(self.content, chapter, 254, -16, NativeArt.chapters[chapter.id] and 176 or 116)
    self:DrawEntryNote(chapter, 34, -123, 440)
    if Bosses.by_id[chapter.id] then
        Button(self.content, "打开首领攻略 ›", 382, -242, 174, function()
            self:OpenGuide("boss", chapter.id)
        end, 33, false, "link")
    elseif chapter.id == "lunar" or chapter.id == "hermitcrab" or chapter.id == "ancient_altar" then
        local route = chapter.id == "ancient_altar" and "shadow" or "lunar"
        Button(self.content, route == "shadow" and "暗影路线 ›" or "月亮路线 ›", 382, -242, 174,
            function() self:OpenGuide(route) end, 33, false, "link")
    end
    if unlocked then self:DrawComment(chapter, -486, -174, 467) end
end

local function GearText(data)
    if data.damage then
        local damage = "伤害 " .. data.damage
        if data.planar then damage = damage .. " + " .. data.planar .. " 位面" end
        local uses = data.uses .. " 次耐用"
        return damage, data.speed and (uses .. string.format(" · 移速 +%d%%", math.floor((data.speed - 1) * 100 + .5))) or uses
    end
    return string.format("吸收 %d%%", data.absorption * 100 + .5), "耐久 " .. data.durability
end

function Journal:GearItemStatus(prefab)
    local index = forge_indices[prefab]
    local digit = self.gear:sub(index, index)
    if digit == "2" then return "已记录", Style.green, true end
    if digit == "1" then return "可记录", Style.accent end
    return "待体验", MUTED
end

function Journal:GearStageStatus(stage)
    if not stage then return "基础装备", MUTED end
    local count = 0
    for _, prefab in ipairs(stage.items) do
        local _, _, recorded = self:GearItemStatus(prefab)
        if recorded then count = count + 1 end
    end
    return count .. "/" .. #stage.items .. " 项已记录", count == #stage.items and Style.green or MUTED
end

local function ForgeCost(stage)
    local materials = {}
    for _, material in ipairs(stage.materials) do
        materials[#materials + 1] = Name(material[1]) .. "×" .. material[2]
    end
    return stage.energy .. " 元素力 + " .. table.concat(materials, "、")
end

function Journal:DrawForgeStage(chapter, prefab, stage)
    local parent = self.content
    local stats = Gear.by_name[prefab]
    local primary, extra = GearText(stats)
    Fill(parent, 0, -154, 966, 1, Style.rule)
    Left(parent, 19, Name(prefab), -486, -166, 260)
    Left(parent, 15, primary .. "  ·  " .. extra, -486, -195, 375, Style.accent)
    if stats.faction_bonus then
        Left(parent, 15, string.format("对暗影与月亮阵营伤害 +%d%%",
            math.floor((stats.faction_bonus - 1) * 100 + .5)), -486, -220, 350, MUTED)
    elseif stage then
        Left(parent, 15, "重铸继承耐用或耐久比例", -486, -220, 350, MUTED)
    end
    if not stage then
        Paragraph(parent, 17, "基础装备可从制作栏获得。点击后续阶段，可查看合成台记录条件与重铸材料。",
            -82, -174, 561, 58, MUTED)
    else
        Left(parent, 16, "原版装备须全部记录", -101, -163, 210, Style.accent)
        Left(parent, 16, "重铸消耗 · " .. ForgeCost(stage), 112, -163, 372, Style.accent)
        for i, item in ipairs(stage.items) do
            local x = -101 + (i - 1) * 183
            local status, colour = self:GearItemStatus(item)
            Icon(parent, ForgeImage(item), x + 19, -220, 39)
            Left(parent, 16, Name(item), x + 42, -198, 136)
            Left(parent, 14, status, x + 42, -224, 136, colour)
        end
    end
    Left(parent, 15, "派蒙 · " .. chapter.comment, -486, -251, 972, MUTED)
end

function Journal:DrawGearChapter(chapter)
    Paragraph(self.content, 17, chapter.body, -487, 86, 970, 47, MUTED)
    for row, route in ipairs(chapter.routes) do
        local large = #chapter.routes == 1
        local y = large and -47 or (-3 - (row - 1) * 103)
        local first = Gear.by_name[route[1]]
        local kind = first.slot == "HEAD" and "头甲" or first.slot == "BODY" and "身甲" or "武器"
        Left(self.content, 16, kind, -486, y + (large and 77 or 42), 98, Style.accent)
        Fill(self.content, 0, y, 760, 2, Style.rule)
        for step, prefab in ipairs(route) do
            local selected_row, selected_step = row, step
            local x = -343 + (step - 1) * 228
            local stage = step > 1 and Forge.BY_OLD[route[step - 1]] or nil
            local status, colour = self:GearStageStatus(stage)
            local card = Style.Card(self.content, x, y, 192, large and 145 or 73, function()
                self.gear_row, self.gear_step = selected_row, selected_step
                self:Render()
            end, row == self.gear_row and step == self.gear_step)
            local tier = ROMAN_NUMERALS[step]
            if large then
                Left(card, 15, tier, -80, 57, 45, Style.accent)
                Icon(card, ItemImage(prefab), 0, 21, 68)
                Label(card, 20, Name(prefab), 0, -26, WHITE)
                Label(card, 15, status, 0, -51, colour)
            else
                Icon(card, ItemImage(prefab), -63, 0, 53)
                Left(card, 16, tier .. " · " .. Name(prefab), -31, 24, 124)
                Left(card, 14, status, -31, -4, 124, colour)
            end
            if step < #route then Label(self.content, 23, "→", x + 114, y, Style.accent) end
        end
    end
    local route = chapter.routes[self.gear_row]
    self:DrawForgeStage(chapter, route[self.gear_step], Forge.BY_OLD[route[self.gear_step - 1]])
end

function Journal:DrawRelicChapter(chapter, unlocked)
    local owned, count = self:CollectionStatus(chapter)
    local set = Artifacts.BY_SET[chapter.relic_set]
    Paragraph(self.content, 20, chapter.intro, -487, 88, 970, 34, Style.accent)
    local active, focus = self.artifacts:match("^[01]+:([0123]):([0123])$")
    local set_index = Artifacts.BY_ID[chapter.relic_set .. "_1"].set_index
    local set_status = count .. "/5 已收录  ·  " .. (count >= 4 and "四件条件已达成" or "收录四件开启专长")
    if tonumber(active) == set_index then set_status = set_status .. "  ·  已选套装" end
    if tonumber(focus) == set_index then set_status = set_status .. "  ·  定向收集" end
    Left(self.content, 17, set_status, -486, 53, 970, count >= 4 and Style.green or MUTED)
    Left(self.content, 17, set.ability, -486, 25, 970, Style.accent)
    for index, piece in ipairs(Artifacts.ALL) do
        if piece.set == chapter.relic_set then
            local x = (piece.slot_index - 3) * 192
            local found = owned:sub(index, index) == "1"
            local card = Style.Image(self.content, Style.paper, "scrap2_tall.tex", x, -92, 180, 166)
            card:SetTint(unpack(found and {.97,.90,.71,1} or {.80,.73,.60,.75}))
            local icon = Icon(self.content, ItemImage(piece.prefab), x, -57, 71)
            if not found then icon:SetTint(.49,.44,.37,1) end
            Label(self.content, 15, Artifacts.SLOTS[piece.slot_index].name, x, -21, Style.accent)
            Label(self.content, 17, piece.name, x, -101, WHITE)
            Label(self.content, 14, piece.stat, x, -126, MUTED)
            Label(self.content, 15, found and "已收录" or "待收录", x, -149, found and Style.green or MUTED)
        end
    end
    if unlocked then
        Paragraph(self.content, 16, chapter.body, -486, -185, 970, 44, MUTED)
        Left(self.content, 16, "派蒙 · " .. chapter.comment, -486, -233, 970, Style.accent)
    else
        Paragraph(self.content, 17, "收录这一套的首件圣遗物后，可阅读派蒙的套装手记。", -486, -203, 970, 38, MUTED)
    end
end

function Journal:DrawRelicOverview(chapter)
    Paragraph(self.content, 21, chapter.intro, -486, 87, 970, 36, Style.accent)
    Paragraph(self.content, 17, chapter.body, -486, 48, 970, 51)
    for i, set in ipairs(Artifacts.SETS) do
        local entry = Catalog.by_id["relic_" .. set.id]
        local _, count = self:CollectionStatus(entry)
        local card = Style.Card(self.content, (i - 2) * 330, -94, 311, 155,
            function() self:NavigateToChapter(entry.id) end)
        Icon(card, entry.image, 0, 30, 61)
        Label(card, 19, entry.title, 0, -17, WHITE)
        Label(card, 16, count .. "/5 已收录  ›", 0, -46, count > 0 and Style.green or MUTED)
    end
    self:DrawComment(chapter, -486, -189, 966)
end

function Journal:DrawPaimon(chapter)
    Paragraph(self.content, 21, chapter.intro, -486, 86, 562, 39, Style.accent)
    Paragraph(self.content, 17, chapter.body, -486, 43, 562, 72)
    local steps = {
        {"亲历", "先完成章节的探索或首领事件。"},
        {"交付", "手持对应证物，请派蒙记录。"},
        {"取回", "完成后查收见闻，原物放回派蒙背包。"},
    }
    for i, step in ipairs(steps) do
        local y = -42 - (i - 1) * 43
        Label(self.content, 17, tostring(i), -471, y, Style.accent)
        Left(self.content, 17, step[1], -443, y + 13, 62, Style.accent)
        Left(self.content, 17, step[2], -376, y + 13, 450, WHITE)
    end
    self:DrawComment(chapter, -486, -178, 560)
    Fill(self.content, 91, -72, 1, 325, Style.rule)
    Style.Image(self.content, Style.paper, "scrap2_square.tex", 288, -4, 211, 182)
    Icon(self.content, chapter.image, 288, -27, 129)
    Left(self.content, 18, "派蒙的记录夹", 122, -111, 342, Style.accent)
    self.paimon_recording_text = Paragraph(self.content, 16, self:RecordingDescription(), 122, -143, 351, 38)
    local pending = self.pending ~= nil and ("待返还证物 " .. self.pending .. " 件") or "等待返还状态同步"
    if self.issues > 0 then pending = pending .. "  ·  " .. self.issues .. " 件待修复" end
    Left(self.content, 16, pending, 122, -189, 353, MUTED)
end

function Journal:DrawSeasons(chapter)
    Paragraph(self.content, 21, chapter.intro, -487, 90, 968, 39, Style.accent)
    local selected = chapter.seasons[self.season]
    for i, season in ipairs(chapter.seasons) do
        local index = i
        local x = (i - 2.5) * 246
        Button(self.content, season.title, x, 18, 223, function()
            self.season = index
            self:Render()
        end, 39, i == self.season)
        if season.id then
            local status, colour = self:MilestoneStatus(season.id)
            local reward = Data.MILESTONES[Catalog.milestone_index[season.id]].reward
            Label(self.content, 17, status .. " · +" .. reward .. " 见闻", x, -16, colour)
        else
            Label(self.content, 17, "季节指南", x, -16, MUTED)
        end
    end
    Fill(self.content, 0, -106, 970, 136, Style.wash)
    Style.Image(self.content, ATLAS, selected.icon .. ".tex", -394, -102, 72, 72)
    Left(self.content, 26, selected.title, -310, -60, 760)
    Paragraph(self.content, 20, selected.text, -310, -99, 757, 63)
    self:DrawComment(chapter, -487, -188, 969)
end

function Journal:RenderChapter(chapter)
    local _, _, unlocked = self:ChapterStatus(chapter)
    Left(self.content, 16, chapter.volume .. "  /  第 " .. string.format("%02d", chapter.number)
        .. " 章  /  " .. chapter.group, -486, 173, 970, MUTED)
    Left(self.content, 33, chapter.title, -487, 142, 970)
    Fill(self.content, 0, 100, 971, 1, Style.rule)
    if chapter.routes then self:DrawGearChapter(chapter)
    elseif chapter.relic_set then self:DrawRelicChapter(chapter, unlocked)
    elseif chapter.seasons then self:DrawSeasons(chapter)
    elseif chapter.id == "lumine_relic" then self:DrawRelicOverview(chapter)
    elseif chapter.id == "lumine_paimon" then self:DrawPaimon(chapter)
    else self:DrawOrdinaryChapter(chapter, unlocked) end

    if #chapter.related > 0 then Label(self.footer, 14, "延伸阅读", -63, -317, MUTED) end
    for i, related_id in ipairs(chapter.related or {}) do
        local target = Catalog.Find(related_id)
        local label = target.relic_set and Artifacts.BY_SET[target.relic_set].short .. "的遗珍" or target.title
        local button = Button(self.footer, label, 40 + (i - 1) * 128, -317, 124,
            function() self:NavigateToChapter(related_id) end, 34, false, "link")
        button:SetTextSize(15)
    end
end

function Journal:Close()
    if self.closed then return end
    self.closed = true
    if self.guide_searchbox then self.guide_searchbox:SetEditing(false) end
    TheFrontEnd:PopScreen(self)
end

function Journal:OnDestroy()
    if self.owner ~= nil and self.owner._lumine_journal_screen == self then
        self.owner._lumine_journal_screen = nil
    end
    Journal._base.OnDestroy(self)
end

function Journal:OnControl(control, down)
    if Journal._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_CANCEL or control == CONTROL_MENU_BACK or control == CONTROL_PAUSE) then
        self:Back()
    end
    return true
end

return Journal
