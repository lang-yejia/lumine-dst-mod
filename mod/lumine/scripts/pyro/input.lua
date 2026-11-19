local Elements = require("lumine_statue_elements")
local Rules = require("pyro/rules")
local M = {KEY = 1, BUTTON = 2}

function M.IsActive(owner)
    return owner and owner._lumine_element_active and owner._lumine_element_active:value() == Elements.pyro.wire
end

function M.New(send, get_aim_mode)
    local held
    local function SendAim(operation, owner, input)
        if owner._lumine_pyro_burst:value() and get_aim_mode() == "mouse"
            and not TheInput:ControllerAttached() and not TheInput:GetHUDEntityUnderMouse() then
            local aim = TheInput:GetWorldPosition()
            if aim then
                send(operation, input, aim.x, aim.z)
                return
            end
        end
        send(operation, input)
    end
    local function Release(input, key)
        if not held or held.input ~= input or (key and key ~= held.key) then return end
        held.task:Cancel()
        held = nil
        send("release", input)
    end
    local function Press(owner, input, key, button)
        if held and held.owner ~= owner then Release(held.input) end
        if held then return end
        local control = button and (TheFrontEnd.isprimary and CONTROL_PRIMARY or CONTROL_ACCEPT)
        SendAim("press", owner, input)
        local task = owner:DoPeriodicTask(Rules.hold_heartbeat, function()
            local down = key and TheInput:IsKeyDown(key)
                or button and button.down and button:IsVisible()
                    and TheInput:IsControlPressed(control)
            if not down or ThePlayer ~= owner or not owner.HUD
                or TheFrontEnd:GetActiveScreen() ~= owner.HUD or owner.HUD:IsChatInputScreenOpen() then
                Release(input)
            elseif M.IsActive(owner) and owner._lumine_pyro_burst:value() then
                SendAim("renew", owner, input)
            end
        end)
        held = {task = task, owner = owner, input = input, key = key}
    end
    return {Press = Press, Release = Release}
end

return M
