local Text = require("widgets/text")
local M = {}

local function FormatTime(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds % 3600 / 60)
    local rest = seconds % 60
    if hours > 0 then return string.format("%d小时%02d分%02d秒", hours, minutes, rest) end
    return string.format("%d分%02d秒", minutes, rest)
end

function M.Attach(widget)
    local old_open, old_close = widget.Open, widget.Close
    local function Stop(self)
        if self._aranara_ui_task ~= nil then
            self._aranara_ui_task:Cancel()
            self._aranara_ui_task = nil
        end
        if self._aranara_title ~= nil then self._aranara_title:Hide() end
        if self._aranara_note ~= nil then self._aranara_note:Hide() end
    end
    widget.Open = function(self, container, ...)
        old_open(self, container, ...)
        Stop(self)
        if container == nil or container.prefab ~= "lumine_aranara_hut" then return end
        if self._aranara_title == nil then
            self._aranara_title = self:AddChild(Text(UIFONT, 31))
            self._aranara_title:SetPosition(0, 98)
            self._aranara_title:SetColour(.95, .91, .70, 1)
            self._aranara_note = self:AddChild(Text(UIFONT, 23))
            self._aranara_note:SetPosition(0, -94)
            self._aranara_note:SetColour(.75, .87, .68, 1)
        end
        self._aranara_title:Show()
        self._aranara_note:Show()
        local function Refresh()
            if not container:IsValid() then return end
            local seconds = container._aranara_time:value()
            local total = container._aranara_total_time:value()
            local count = container._aranara_workers:value()
            local status = container._aranara_status:value()
            local state = status == 1 and "冬季休息 · 计时暂停"
                or status == 2 and "附近有危险 · 暂停计时"
                or status == 3 and "确认安全 · 暂停计时"
                or status == 4 and "等待燃料" or "正在照料"
            self._aranara_title:SetString("兰纳罗小屋 · 可持续 " .. FormatTime(total))
            self._aranara_note:SetString(state .. " · 兰纳罗 " .. count .. "/3\n已转化 " .. FormatTime(seconds)
                .. "\n燃烧 1 秒 = 活动 2 秒 · 仅照料周围约 3×3 地皮")
        end
        Refresh()
        self._aranara_ui_task = self.inst:DoPeriodicTask(1, Refresh)
    end
    widget.Close = function(self, ...)
        Stop(self)
        return old_close(self, ...)
    end
end

return M
