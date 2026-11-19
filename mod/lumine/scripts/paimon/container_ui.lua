local L = require("languages/lumine").For("paimon/container_ui")
local Text = require("widgets/text")
local C = require("paimon/config")
local M = {}
function M.Attach(widget)
    local oldopen, oldclose = widget.Open, widget.Close
    local function Stop(self)
        if self._paimon_ui_task then self._paimon_ui_task:Cancel(); self._paimon_ui_task = nil end
        if self._paimon_title then self._paimon_title:Hide(); self._paimon_note:Hide() end
    end
    widget.Open = function(self, container, ...)
        oldopen(self, container, ...)
        Stop(self)
        if container.prefab ~= "lumine_paimon" then return end
        if not self._paimon_title then
            self._paimon_title = self:AddChild(Text(UIFONT, require("languages/lumine").language == "en" and 34 or 40))
            self._paimon_title:SetPosition(-125, 185)
            self._paimon_note = self:AddChild(Text(UIFONT, require("languages/lumine").language == "en" and 26 or 30))
            self._paimon_note:SetPosition(-125, -195)
            self._paimon_note:SetColour(1, .94, .82, 1)
        end
        self._paimon_title:Show(); self._paimon_note:Show()
        local function Refresh()
            if not container:IsValid() then return end
            local value = container._satiety:value()
            local display = value > 0 and value < 1 and L(1, "不足 1") or tostring(math.floor(value))
            self._paimon_title:SetString(L(2, "派蒙的应急背包\n饱食度 ") .. display .. " / " .. C.MAX_HUNGER)
            self._paimon_note:SetString(L(3, "进食：从左到右，从上到下\n") .. C.PerishDescription() .. "\n" .. string.format(value > 0 and L(4, "陪伴 +%g 精神/分钟") or L(5, "空腹 -%g 精神/分钟"), C.SANITY_PER_SECOND * 60))
            self._paimon_title:SetColour(value <= 0 and 1 or .95, value <= 0 and .55 or .86, .68, 1)
        end
        Refresh()
        self._paimon_ui_task = self.inst:DoPeriodicTask(.5, Refresh)
    end
    widget.Close = function(self, ...) Stop(self); return oldclose(self, ...) end
end
return M
