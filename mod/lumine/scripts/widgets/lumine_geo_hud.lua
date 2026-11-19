local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")

local GeoHud = Class(Widget, function(self, owner, shield_key, field_key)
    Widget._ctor(self, "LumineGeoHud")
    self.owner = owner
    self.shield_key = shield_key
    self.field_key = field_key
    for _, entry in ipairs({{"geo-shield", 16}, {"geo-field", -15}}) do
        local icon = self:AddChild(Image("images/element/" .. entry[1] .. ".xml", entry[1] .. ".tex"))
        icon:SetSize(27, 27)
        icon:SetPosition(-108, entry[2])
        icon:SetClickable(false)
    end
    self.shield = self:AddChild(Text(BODYTEXTFONT, 21, ""))
    self.shield:SetPosition(12, 16)
    self.field = self:AddChild(Text(BODYTEXTFONT, 21, ""))
    self.field:SetPosition(12, -15)
    self:StartUpdating()
end)

local function SkillText(name, key, unlocked, ready)
    if not unlocked then return "[" .. key .. "] " .. name .. " · 未解锁" end
    local remaining = math.ceil(math.max(0, ready - GetTime()))
    return "[" .. key .. "] " .. name .. " · " .. (remaining > 0 and (remaining .. " 秒") or "就绪")
end

function GeoHud:OnUpdate()
    if self.owner == nil or not self.owner:IsValid() or self.owner._lumine_geo_skills == nil then return end
    if self.owner._lumine_element_active == nil or self.owner._lumine_element_active:value() ~= 2 then
        self:Hide()
        return
    end
    self:Show()
    local mask = self.owner._lumine_geo_skills:value()
    self.shield:SetString(SkillText("星岩护佑", self.shield_key, mask % 2 == 1,
        self.owner._lumine_geo_shield_ready:value()))
    self.field:SetString(SkillText("岩域共鸣", self.field_key, math.floor(mask / 2) % 2 == 1,
        self.owner._lumine_geo_field_ready:value()))
    local colour = self.owner:HasTag("playerghost") and {0.6, 0.6, 0.6, 1} or {0.94, 0.78, 0.48, 1}
    self.shield:SetColour(unpack(colour))
    self.field:SetColour(unpack(colour))
end

return GeoHud
