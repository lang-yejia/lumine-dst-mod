local Nodes = require("skilltree/lumine_nodes")
local M = {}

function M.Install(postconstruct, request)
    local SkillWidget = require("skilltree/lumine_widget")
    local PlayerInfo = require("screens/playerinfopopupscreen")
    local make_tree = PlayerInfo.MakeSkillTree

    function PlayerInfo:MakeSkillTree()
        local character = self.data.inst and self.data.inst.prefab or self.data.prefab
        if character ~= Nodes.character then return make_tree(self) end

        local owner = self.owner
        local is_self = owner.prefab == Nodes.character
            and (self.data.inst == owner or (owner.userid ~= nil and self.data.userid == owner.userid))
        if not self.lumine_self_inspect and not (is_self and owner.HUD and owner.HUD.lumine_inspecting_self) then
            if self.root.tabs then
                self.root.tabs:Kill()
                self.root.tabs = nil
            end
            self.GetHelpText = function()
                return TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK
            end
            return self:MakePlayerAvatarPopup()
        end

        self.lumine_self_inspect = true
        if self.data.userid ~= owner.userid then
            local data = {}
            for key, value in pairs(self.data) do data[key] = value end
            data.userid = owner.userid
            self.data = data
        end
        make_tree(self)
        SkillWidget.Attach(self.skilltree, owner, request)
    end

    postconstruct("screens/playerhud", function(hud)
        local inspect_self = hud.InspectSelf
        function hud:InspectSelf(...)
            if not self.owner or self.owner.prefab ~= Nodes.character then return inspect_self(self, ...) end
            -- The native button and key both call this method. Player-list
            -- profiles use TogglePlayerInfoPopup directly.
            self.lumine_inspecting_self = true
            local opened = inspect_self(self, ...)
            self.lumine_inspecting_self = nil
            return opened
        end
    end)

    postconstruct("widgets/redux/loadoutselect", function(loadout)
        if loadout.currentcharacter == Nodes.character then
            loadout.can_show_skilltree = false
            loadout.switch_context_button:Hide()
        end
    end)
end

return M
