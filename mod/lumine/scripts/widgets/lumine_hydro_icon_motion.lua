local UIAnim = require("widgets/uianim")
local BANK = "lumine_hydro_water"
local LOOPS = {hydro_drop = true, hydro_stream = true, hydro_bubble = true}
local M = {}

function M.Attach(icon, skill, size)
    if not LOOPS[skill] then return end
    local motion = icon:AddChild(UIAnim())
    local anim = motion:GetAnimState()
    anim:SetBank(BANK)
    anim:SetBuild(BANK)
    anim:PlayAnimation(skill, true)
    motion:SetScale(size / 128)
    motion:SetClickable(false)
    return motion
end

function M.SetStrength(motion, strength)
    if motion._lumine_strength ~= strength then
        motion._lumine_strength = strength
        motion:GetAnimState():SetMultColour(1, 1, 1, strength)
    end
end

return M
