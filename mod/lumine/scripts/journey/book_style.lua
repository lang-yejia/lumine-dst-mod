local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")

local M = {
    ink = {.23,.17,.12,1},
    muted = {.37,.29,.22,1},
    accent = {.47,.25,.14,1},
    green = {.25,.34,.23,1},
    rule = {.51,.38,.25,.44},
    wash = {.56,.42,.28,.13},
    paper = "images/scrapbook.xml",
    frontend = "images/frontend.xml",
    white = "images/ui.xml",
}

function M.Image(parent, atlas, tex, x, y, width, height)
    local image = parent:AddChild(Image(atlas, tex))
    image:SetSize(width, height)
    image:SetPosition(x, y)
    image:SetClickable(false)
    return image
end

function M.Fill(parent, x, y, width, height, colour)
    local image = M.Image(parent, M.white, "white.tex", x, y, width, height)
    image:SetTint(unpack(colour))
    return image
end

function M.Label(parent, size, value, x, y, colour)
    local text = parent:AddChild(Text(CHATFONT, size, value))
    text:SetPosition(x, y)
    text:SetColour(unpack(colour or M.ink))
    text:SetClickable(false)
    return text
end

function M.Paragraph(parent, size, value, left, top, width, height, colour)
    local text = M.Label(parent, size, value, left + width / 2, top - height / 2, colour)
    text:SetRegionSize(width, height)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_TOP)
    text:EnableWordWrap(true)
    return text
end

local function MakeButton(parent, x, y, width, height, fn, ...)
    local button = parent:AddChild(ImageButton(...))
    button.scale_on_focus = false
    button.move_on_click = false
    button:ForceImageSize(width, height)
    button:SetPosition(x, y)
    button:SetOnClick(fn)
    return button
end

function M.Button(parent, label, x, y, width, fn, height, selected, role)
    local button
    if role == "primary" then
        button = MakeButton(parent, x, y, width, height or 36, fn, M.frontend,
            "button_long.tex", "button_long_highlight.tex", "button_long_disabled.tex", "button_long_down.tex")
    elseif role == "tab" then
        button = MakeButton(parent, x, y, width, height or 38, fn, M.paper,
            "tab.tex", "tab_over.tex", "tab.tex", "tab_over.tex", "tab_selected.tex")
        button:SetImageNormalColour(.88,.80,.67,1)
        button:SetImageFocusColour(1,.93,.79,1)
        button:SetImageSelectedColour(.92,.77,.56,1)
    else
        button = MakeButton(parent, x, y, width, height or 32, fn, M.white, "white.tex")
        button:SetImageNormalColour(.53,.40,.26,role == "link" and 0 or .08)
        button:SetImageFocusColour(.56,.39,.22,.19)
        button:SetImageSelectedColour(.61,.41,.22,.25)
    end
    button:SetFont(CHATFONT)
    button:SetDisabledFont(CHATFONT)
    button:SetTextSize(role == "tab" and 16 or 18)
    button:SetTextColour(M.ink)
    button:SetTextFocusColour(M.accent)
    button:SetTextSelectedColour(M.accent)
    button:SetTextDisabledColour(.45,.39,.32,1)
    button:SetImageDisabledColour(.59,.49,.37,.15)
    button:SetText(label)
    button.text:SetClickable(false)
    if selected then button:Select() end
    return button
end

function M.Card(parent, x, y, width, height, fn, selected, texture)
    texture = texture or "scrap2_wide.tex"
    local card = MakeButton(parent, x, y, width, height, fn, M.paper, texture)
    card:SetImageNormalColour(.95,.88,.75,.88)
    card:SetImageFocusColour(1,.98,.87,1)
    card:SetImageSelectedColour(1,.87,.65,1)
    if selected then card:Select() end
    return card
end

return M
