local Badge = require("widgets/badge")
local Image = require("widgets/image")
local C = require("paimon/config")

local PaimonHungerHud = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, {.72, .60, .91, 1}, nil, nil, nil, true)
    self.owner = owner
    self.last_amount = nil
    local frame = self.circleframe:GetAnimState()
    frame:HideSymbol("icon")
    frame:SetMultColour(.91, .84, 1, 1)
    local icon = self.underNumber:AddChild(Image("images/inventoryimages/lumine_paimon_cake.xml", "lumine_paimon_cake.tex"))
    icon:SetSize(44, 44)
    icon:SetClickable(false)
    self:SetHoverText("派蒙饱食度")
    self:SetPercent(1, C.MAX_HUNGER)
    self.num:SetPosition(0, -42)
    self.num:SetSize(22)
    self.num:SetClickable(false)
    self.num:Show()
    self:Hide()
    self:StartUpdating()
end)

function PaimonHungerHud:OnLoseFocus()
    Badge._base.OnLoseFocus(self)
end

function PaimonHungerHud:OnUpdate()
    local owner = self.owner
    if owner == nil or not owner:IsValid() then return end
    local pet = owner._paimon
    if pet == nil or not pet:IsValid() then
        local x, y, z = owner.Transform:GetWorldPosition()
        for _, candidate in ipairs(TheSim:FindEntities(x, y, z, 40, {"lumine_paimon"})) do
            if candidate._owner ~= nil and candidate._owner:value() == owner then
                pet = candidate
                break
            end
        end
    end
    if pet == nil or not pet:IsValid() or pet._satiety == nil then
        self.last_amount = nil
        self:Hide()
        return
    end
    self:Show()
    local amount = math.max(0, math.min(C.MAX_HUNGER, pet._satiety:value()))
    if amount ~= self.last_amount then
        self:SetPercent(amount / C.MAX_HUNGER, C.MAX_HUNGER)
        self.num:SetString(tostring(math.floor(amount)))
        self:SetHoverText(string.format("派蒙饱食度：%d / %d", math.floor(amount), C.MAX_HUNGER))
        self.last_amount = amount
    end
end

return PaimonHungerHud
