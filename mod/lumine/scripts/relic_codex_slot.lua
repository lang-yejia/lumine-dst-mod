local M = {}
local function MoveLast(bar, slot)
    local index, maxkey = nil, -1
    for i, info in ipairs(bar.equipslotinfo) do
        if info.slot == slot then index = i else maxkey = math.max(maxkey, info.sortkey or 0) end
    end
    if index ~= nil then
        local info = table.remove(bar.equipslotinfo, index)
        info.sortkey = maxkey + 1
        bar.equipslotinfo[#bar.equipslotinfo + 1] = info
    end
end

local function FitBackground(bar)
    local inventory = bar.owner.replica.inventory
    if inventory == nil then return end
    local slots = inventory:GetNumSlots()
    local buttons = bar.inspectcontrol ~= nil and 1 or 0
    local function Width(equipment)
        local gaps = math.ceil(slots / 5) + buttons
        local cells = slots + equipment + buttons
        return cells * 68 + (cells - gaps - 1) * 12 + gaps * 28
    end
    local scale = (buttons == 1 and 1.22 or 1.15) * Width(#bar.equipslotinfo) / Width(3)
    for _, background in ipairs({bar.bg, bar.bgcover}) do
        if background ~= nil and not background.Flow then
            local sx, sy, sz = background.inst.UITransform:GetScale()
            background:SetScale(math.max(sx, scale), sy, sz)
        end
    end
end

function M.Install(G, AddClassPostConstruct)
    AddClassPostConstruct("widgets/inventorybar", function(bar)
        if bar.owner == nil or not bar.owner:HasTag("lumine") or bar._lumine_relic_codex_slot then return end
        bar._lumine_relic_codex_slot = true
        local slot = G.EQUIPSLOTS.LUMINE_RELIC_CODEX
        bar:AddEquipSlot(slot, "images/hud.xml", "inv_slot.tex")
        MoveLast(bar, slot)
        local rebuild = bar.Rebuild
        bar.Rebuild = function(self, ...)
            MoveLast(self, slot)
            local result = rebuild(self, ...)
            local widget = self.equip[slot]
            if widget ~= nil then
                self.inst:DoTaskInTime(0, function()
                    if self.inst:IsValid() and self.equip[slot] == widget then FitBackground(self) end
                end)
                widget:SetBGImage2("images/inventoryimages/lumine_relic_codex.xml",
                    "lumine_relic_codex.tex", {.7, .65, .5, .4})
                widget.bgimage2:SetSize(54, 54)
                widget.bgimage2:SetClickable(false)
                local changed = widget.ontilechangedfn
                widget:SetOnTileChangedFn(function(tilewidget, tile)
                    if changed ~= nil then changed(tilewidget, tile) end
                    if tile ~= nil then tilewidget.bgimage2:Hide() else tilewidget.bgimage2:Show() end
                end)
                if widget.tile ~= nil then widget.bgimage2:Hide() end
            end
            return result
        end
    end)
end
return M
