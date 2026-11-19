local Widget = require("widgets/widget")
local Templates = require("widgets/redux/templates")
local Style = require("journey/book_style")
local Exchange = require("skilltree/lumine_exchange")

local BAR_WIDTH = 156

local Panel = Class(Widget, function(self, owner, request)
    Widget._ctor(self, "lumine_insight_exchange")
    self.owner = owner

    Style.Label(self, 18, "见闻兑换", -123, 13)
    self.balance = Style.Label(self, 14, "", -123, -12, Style.muted)
    self.next = Style.Label(self, 15, "", 2, 17)
    self.track = Style.Fill(self, 2, 0, BAR_WIDTH, 6, Style.wash)
    self.fill = Style.Fill(self, 2, 0, BAR_WIDTH, 6, Style.accent)
    self.hint = Style.Label(self, 13, "", 2, -17, Style.muted)
    self.button = self:AddChild(Templates.StandardButton(function()
        if self.can_exchange then request("exchange", self.exchange_number) end
    end, "兑换 1 点", {112, 25}))
    self.button:SetPosition(150, 0)
    self.button:SetTextSize(14)

    self.inst:ListenForEvent("lumine_insight_exchange_dirty", function() self:Refresh() end, owner)
    if owner.player_classified then
        self.inst:ListenForEvent("isghostmodedirty", function() self:Refresh() end, owner.player_classified)
    end
    self.inst:ListenForEvent("ms_becameghost", function() self:Refresh() end, owner)
    self.inst:ListenForEvent("ms_respawnedfromghost", function() self:Refresh() end, owner)
    self:Refresh()
end)

function Panel:Refresh()
    local available, count, cost = Exchange.Decode(self.owner._lumine_insight_exchange:value())
    local ghost = self.owner:HasTag("playerghost")
    self.exchange_number = count and count + 1
    self.can_exchange = cost ~= nil and cost > 0 and available >= cost and not ghost
    self.balance:SetString(available and ("可用见闻  " .. available) or "正在读取见闻")
    self.next:SetString(cost == nil and "下一点洞察"
        or cost == 0 and "洞察已达上限"
        or ("第 " .. self.exchange_number .. " 次  ·  " .. cost .. " 见闻"))
    local width = cost and cost > 0 and BAR_WIDTH * math.min(available / cost, 1) or 0
    if width > 0 then
        self.fill:SetSize(width, 6)
        self.fill:SetPosition(2 + (width - BAR_WIDTH) / 2, 0)
        self.fill:Show()
    else
        self.fill:Hide()
    end
    if cost and cost > 0 then
        self.track:Show()
        self.hint:SetString(math.min(available, cost) .. " / " .. cost
            .. (ghost and "  ·  复活后可兑换"
                or available < cost and ("  ·  还差 " .. (cost - available) .. " 见闻") or "  ·  可兑换"))
    else
        self.track:Hide()
        self.hint:SetString(count and ("已兑换 " .. count .. " 次") or "")
    end
    if self.can_exchange then self.button:Enable() else self.button:Disable() end
end

return Panel
