local Image = require("widgets/image")
local Style = require("journey/book_style")
local ExchangePanel = require("widgets/lumine_insight_exchange")
local Popup = require("screens/redux/popupdialog")
local Nodes = require("skilltree/lumine_nodes")
local Layout = require("skilltree/lumine_layout")
local M = {}

local ICON_SIZE = 20
local PLACEHOLDER_ICON = "wilson_alchemy_gem_1"

function M.FitIcon(width, height, size)
    local scale = size / math.max(width, height)
    return width * scale, height * scale
end

local function AddIcon(parent, name, size)
    local tex = (name or PLACEHOLDER_ICON) .. ".tex"
    local icon = parent:AddChild(Image(GetSkilltreeIconAtlas(tex), tex))
    local width, height = icon:GetSize()
    if width <= 0 or height <= 0 then
        tex = PLACEHOLDER_ICON .. ".tex"
        icon:SetTexture(GetSkilltreeIconAtlas(tex), tex)
        width, height = icon:GetSize()
    end
    if width <= 0 or height <= 0 then icon:Hide() return icon end
    icon:SetSize(M.FitIcon(width, height, size))
    icon:SetClickable(false)
    icon:MoveToFront()
    return icon
end

local function Connection(tree, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local line = tree:AddChild(Image("images/global.xml", "square.tex"))
    line:SetPosition((x1 + x2) / 2, (y1 + y2) / 2)
    line:SetSize(math.sqrt(dx * dx + dy * dy), 1.6)
    line:SetRotation(math.atan2(-dy, dx) / DEGREES)
    line:SetClickable(false)
    line:MoveToBack()
    return line
end

local function DrawConnections(tree)
    for _, node in ipairs(Nodes.nodes) do
        if node.requires then
            local start = tree.skillgraphics[node.requires].button:GetPosition()
            local finish = tree.skillgraphics[node.id].button:GetPosition()
            tree.skillgraphics[node.id].lumine_connection = Connection(tree, start.x, start.y, finish.x, finish.y)
        end
    end
end

local function ConfirmReset(request)
    local dialog
    dialog = Popup("重置洞察分配", "退回已分配的洞察，当前元素会回到无元素。已制作的圣匣与已建造的小屋仍可使用。", {
        {text = "重置", cb = function()
            TheFrontEnd:PopScreen(dialog)
            request("reset")
        end},
        {text = "取消", cb = function() TheFrontEnd:PopScreen(dialog) end, control = CONTROL_CANCEL},
    }, nil, "medium")
    TheFrontEnd:PushScreen(dialog)
end

function M.Attach(widget, owner, request)
    local tree = widget.root.tree
    local info = widget.root.infopanel
    widget.bg_tree:SetTexture("images/scrapbook.xml", "scrap_square.tex")
    widget.bg_tree:SetTint(.83, .73, .56, 1)
    widget.bg_tree:SetScale(1)
    widget.bg_tree:SetSize(546, 444)
    widget.bg_tree:SetPosition(0, -18)
    widget.bg_tree:SetClickable(false)
    if widget.root.scroll_left then
        widget.root.scroll_left:Hide()
        widget.root.scroll_right:Hide()
    end
    tree:SetPosition(0, Layout.builder_y)
    for _, node in ipairs(Nodes.nodes) do
        local graphics = tree.skillgraphics[node.id]
        graphics.button.scale_on_focus = false
        AddIcon(graphics.button, node.icon, ICON_SIZE)
    end
    for _, branch in ipairs(Nodes.branches) do
        local title = tree.root.panels[branch.id].title
        title:SetFont(CHATFONT)
        title:SetSize(16)
        title:SetColour(.23, .15, .10, 1)
    end
    DrawConnections(tree)
    info:SetPosition(0, -121)
    info.bg:ScaleToSize(466, 106)
    info.bg:SetPosition(0, 0)
    info.title:SetFont(CHATFONT)
    info.title:SetPosition(0, 37)
    info.intro:SetString("选择节点查看效果，或用见闻兑换洞察。")
    info.intro:SetPosition(0, 0)
    info.desc:SetPosition(0, 4)
    info.desc:SetSize(15)
    info.desc:UpdateOriginalSize()
    info.activatebutton:SetScale(1)
    info.activatebutton:ForceImageSize(124, 24)
    info.activatebutton:SetTextSize(15)
    info.activatebutton:SetPosition(0, -33)
    info.activatedbg:ScaleToSize(132, 26)
    info.activatedbg:SetPosition(0, -33)
    info.activatedtext:SetFont(CHATFONT)
    info.activatedtext:SetSize(15)
    info.activatedtext:SetPosition(0, -33)
    tree.root.xp:SetPosition(-194, 231)
    tree.root.xpicon:ScaleToSize(38, 38)
    tree.root.xpicon:SetTint(.28, .19, .12, 1)
    tree.root.xptotal:SetColour(.99, .94, .79, 1)
    tree.root.xp_tospend:SetFont(CHATFONT)
    tree.root.xp_tospend:SetColour(.23, .15, .10, 1)

    Style.Fill(widget.root, 0, -182, 466, 1, Style.rule)
    local exchange = widget.root:AddChild(ExchangePanel(owner, request))
    exchange:SetPosition(0, -207)
    local reset = info.respec_button
    reset:ForceImageSize(116, 26)
    reset:SetTextSize(14)
    reset:SetText(TheInput:ControllerAttached()
        and (TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_MENU_MISC_2) .. " 重置分配")
        or "重置分配")
    reset:SetPosition(183, 302)
    function widget:RespecSkills() ConfirmReset(request) end
    info.activatebutton:SetFocusChangeDir(MOVE_DOWN, exchange.button)
    info.activatebutton:SetFocusChangeDir(MOVE_RIGHT, exchange.button)
    local function SelectedButton()
        return tree.skillgraphics[tree.selectedskill or Nodes.foundation].button
    end
    exchange.button:SetFocusChangeDir(MOVE_UP, function()
        return info.activatebutton:IsVisible() and info.activatebutton or SelectedButton()
    end)
    for _, entry in ipairs(tree.buttongrid) do
        if not entry.button.focus_flow[MOVE_UP] then
            entry.button:SetFocusChangeDir(MOVE_UP, reset)
        end
        if not entry.button.focus_flow[MOVE_DOWN] then
            entry.button:SetFocusChangeDir(MOVE_DOWN, function()
                if info.activatebutton:IsVisible() then return info.activatebutton end
                return exchange.button
            end)
        end
    end
    reset:SetFocusChangeDir(MOVE_DOWN, SelectedButton)
    info.activatebutton:SetFocusChangeDir(MOVE_UP, SelectedButton)
    local refresh = tree.RefreshTree
    function tree:RefreshTree(changed)
        refresh(self, changed)
        local selected = Nodes.by_id[self.selectedskill]
        if selected then
            info.title:SetString(selected.title)
            if self.skillgraphics[selected.id].status.activated then
                info.activatedtext:SetString("已学习")
            end
        end
        for _, node in ipairs(Nodes.nodes) do
            local line = self.skillgraphics[node.id].lumine_connection
            if line then
                local parent_active = self.skillgraphics[node.requires].status.activated
                if node.status == "implemented" and parent_active then
                    line:SetTint(.45, .29, .13, .94)
                else
                    line:SetTint(.43, .34, .24, node.status == "planned" and .35 or .57)
                end
            end
        end
        self.root.xp_tospend:SetString("可用洞察")
        local width = self.root.xp_tospend:GetRegionSize()
        self.root.xp_tospend:SetPosition(30 + width / 2, -3)
        local ghost = owner:HasTag("playerghost")
        if ghost then info.activatebutton:Hide() end
        if not ghost and owner.components.skilltreeupdater:GetActivatedSkills() then reset:Show() end
    end
    function tree:LearnSkill()
        local id = self.selectedskill
        local graphics = self.skillgraphics[id]
        if graphics and graphics.status.activatable
            and Nodes.by_id[id].status == "implemented" and self.infopanel.activatebutton:IsVisible() then
            self.lumine_pending_learn = id
            request("learn", id)
        end
    end
    widget.inst:ListenForEvent("lumine_skilltree_dirty", function()
        tree:RefreshTree(true)
        local id = tree.lumine_pending_learn
        if id and tree.skillgraphics[id].status.activated then
            tree.lumine_pending_learn = nil
            TheFrontEnd:GetSound():PlaySound("wilson_rework/ui/skill_mastered")
        end
    end, owner)
    if tree.sync_status then tree.sync_status:Hide() end
    tree:RefreshTree()
end

return M
