local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")

local WindHud = Class(Widget, function(self, owner, dash_key, tornado_key)
    Widget._ctor(self, "LumineWindHud")
    self.owner = owner
    self.dash_key = dash_key
    self.tornado_key = tornado_key
    self.dash_icon = self:AddChild(Image("images/element/wind-dash.xml", "wind-dash.tex"))
    self.dash_icon:SetSize(27, 27)
    self.dash_icon:SetPosition(-108, 16)
    self.dash_icon:SetClickable(false)
    self.tornado_icon = self:AddChild(Image("images/element/wind-tornado.xml", "wind-tornado.tex"))
    self.tornado_icon:SetSize(27, 27)
    self.tornado_icon:SetPosition(-108, -15)
    self.tornado_icon:SetClickable(false)
    self.dash = self:AddChild(Text(BODYTEXTFONT, 21, ""))
    self.dash:SetPosition(12, 16)
    self.tornado = self:AddChild(Text(BODYTEXTFONT, 21, ""))
    self.tornado:SetPosition(12, -15)
    self:StartUpdating()
end)

local function SkillText(name, key, unlocked, ready)
    if not unlocked then return "[" .. key .. "] " .. name .. " · 未解锁" end
    local remaining = math.ceil(math.max(0, ready - GetTime()))
    return "[" .. key .. "] " .. name .. " · " .. (remaining > 0 and (remaining .. " 秒") or "就绪")
end

function WindHud:OnUpdate()
    if self.owner == nil or not self.owner:IsValid()
        or self.owner._lumine_wind_skills == nil then return end
    if self.owner._lumine_element_active == nil or self.owner._lumine_element_active:value() ~= 1 then
        self:Hide()
        return
    end
    self:Show()
    local mask = self.owner._lumine_wind_skills:value()
    self.dash:SetString(SkillText("风行", self.dash_key, mask % 2 == 1,
        self.owner._lumine_wind_dash_ready:value()))
    self.tornado:SetString(SkillText("风涡剑", self.tornado_key, math.floor(mask / 2) % 2 == 1,
        self.owner._lumine_wind_tornado_ready:value()))
    local colour = self.owner:HasTag("playerghost") and {0.6, 0.6, 0.6, 1} or {0.9, 0.86, 0.68, 1}
    self.dash:SetColour(unpack(colour))
    self.tornado:SetColour(unpack(colour))
end

return WindHud
