local Badge = require("widgets/badge")
local Image = require("widgets/image")
local Elements = require("lumine_statue_elements")

local EnergyHud = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, {.91, .94, .98, 1}, "status_hunger", nil, nil, true)
    self.owner = owner
    self.center = self.underNumber:AddChild(Image("images/element/lumine_energy_center.xml", "lumine_energy_center.tex"))
    self.center:SetSize(43, 43)
    self.center:SetClickable(false)
    self.icon = self.underNumber:AddChild(Image("images/inventoryimages/lumine_element_particle.xml", "lumine_element_particle.tex"))
    self.icon:SetSize(35, 35)
    self.icon:SetClickable(false)
    self.last_active = -1
    self.last_amount = -1
    self:SetPercent(0, 100)
    self:SetHoverText("元素力 · 右键拖动位置")
    local oldcontrol = self.OnControl
    self.OnControl = function(widget, control, down)
        if control == CONTROL_SECONDARY then
            if down and self.drag == nil then
                local mouse = TheInput:GetScreenPosition()
                local x, y = self:GetPosition():Get()
                self.drag = {mousex=mouse.x, mousey=mouse.y, x=x, y=y}
                self.drag.handler = TheInput:AddMoveHandler(function(mx, my)
                    if self.drag == nil then return end
                    local sx, sy = self.parent:GetScale():Get()
                    self:SetPosition(self.drag.x + (mx - self.drag.mousex) / sx,
                        self.drag.y + (my - self.drag.mousey) / sy)
                end)
            elseif not down and self.drag ~= nil then
                self.drag.handler:Remove()
                self.drag = nil
                local x, y = self:GetPosition():Get()
                TheSim:SetPersistentString("lumine_energy_badge_position_v1",
                    string.format("%.1f,%.1f", x, y), false)
            end
            return true
        end
        return oldcontrol ~= nil and oldcontrol(widget, control, down) or false
    end
    self:StartUpdating()
end)

function EnergyHud:OnUpdate()
    local owner = self.owner
    if owner == nil or not owner:IsValid() or owner._lumine_energy == nil then return end
    local amount = math.max(0, math.min(100, owner._lumine_energy:value()))
    local active = owner._lumine_element_active ~= nil and owner._lumine_element_active:value() or 0
    if active ~= self.last_active then
        local color = active == 1 and {.38, .91, .77, 1}
            or active == 2 and {.96, .76, .34, 1}
            or active == 3 and {.73, .48, .96, 1}
            or active == Elements.dendro.wire and {.52, .76, .38, 1}
            or active == Elements.hydro.wire and {.36, .7, .96, 1}
            or active == Elements.pyro.wire and {.95, .44, .28, 1} or {.91, .94, .98, 1}
        if active == Elements.cryo.wire then color = {.61, .85, .94, 1} end
        self.anim:GetAnimState():SetMultColour(unpack(color))
        if self.circleframe ~= nil then self.circleframe:GetAnimState():SetMultColour(unpack(color)) end
        local element = Elements[Elements.by_wire[active]]
        local icon = element and element.emblem
        if icon ~= nil then
            self.icon:SetTexture("images/element/" .. icon .. ".xml", icon .. ".tex")
        else
            self.icon:SetTexture("images/inventoryimages/lumine_element_particle.xml", "lumine_element_particle.tex")
        end
        self.icon:SetSize(35, 35)
        self.last_active = active
    end
    if amount ~= self.last_amount then
        self:SetPercent(amount / 100, 100)
        self.last_amount = amount
    end
end

return EnergyHud
