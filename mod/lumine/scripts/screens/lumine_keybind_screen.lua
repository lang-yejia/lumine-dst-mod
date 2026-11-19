local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local Templates = require("widgets/redux/templates")

local KeybindScreen = Class(Screen, function(self, keys, cycle)
    Screen._ctor(self, "LumineKeybindScreen")
    self.root = self:AddChild(Widget("root"))
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    local bg = self.root:AddChild(Image("images/global.xml", "square.tex"))
    bg:SetSize(530, 245)
    bg:SetTint(.10, .13, .16, .97)
    bg:SetClickable(false)
    local title = self.root:AddChild(Text(TITLEFONT, 28, "莹 · 元素技能按键"))
    title:SetPosition(0, 91)
    local hint = self.root:AddChild(Text(BODYTEXTFONT, 18, "点击按键循环选择；设置仅保存在本机"))
    hint:SetPosition(0, 53)
    self.labels = {}
    for slot = 1, 3 do
        local x = (slot - 2) * 155
        local label = self.root:AddChild(Text(BODYTEXTFONT, 20, ""))
        label:SetPosition(x, 13)
        self.labels[slot] = label
        local button = self.root:AddChild(Templates.StandardButton(function()
            cycle(slot)
            self:Refresh(keys)
        end, "", {125, 42}))
        button:SetPosition(x, -35)
        self.labels[slot].button = button
    end
    local close = self.root:AddChild(Templates.StandardButton(function()
        TheFrontEnd:PopScreen(self)
    end, "完成", {120, 36}))
    close:SetPosition(0, -93)
    self:Refresh(keys)
end)

function KeybindScreen:Refresh(keys)
    for slot = 1, 3 do
        self.labels[slot]:SetString(slot == 3 and "风之翼" or "技能 " .. slot)
        self.labels[slot].button:SetText(keys[slot])
    end
end

function KeybindScreen:OnControl(control, down)
    if KeybindScreen._base.OnControl(self, control, down) then return true end
    if not down and control == CONTROL_CANCEL then
        TheFrontEnd:PopScreen(self)
        return true
    end
end

return KeybindScreen
