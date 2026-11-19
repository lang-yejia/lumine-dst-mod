local M = {STATE = "lumine_electro_cast"}
local CAST_RATE = 2.5
local RELEASE_FRAME = math.ceil(53 / CAST_RATE)
local END_FRAME = math.ceil(69 / CAST_RATE)
local PURPLE = {.66, .33, 1}

local function Finish(inst)
    inst.sg:GoToState("idle")
end

function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nopredict", "nomorph"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("staff_pre")
            inst.AnimState:PushAnimation("staff", false)
            inst.AnimState:SetDeltaTimeMultiplier(CAST_RATE)
            local fx = SpawnPrefab("staffcastfx")
            if fx then
                fx.entity:SetParent(inst.entity)
                fx:SetUp(PURPLE)
                fx.AnimState:SetDeltaTimeMultiplier(CAST_RATE)
                inst.sg.statemem.cast_fx = fx
            end
            inst.sg:SetTimeout(END_FRAME * FRAMES)
        end,
        timeline = {
            FrameEvent(RELEASE_FRAME, function(inst)
                local electro = inst.components.lumineelectro
                if electro and electro:ActivateBurst() then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/use_gemstaff")
                end
            end),
        },
        ontimeout = Finish,
        onexit = function(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1)
            local fx = inst.sg.statemem.cast_fx
            if fx and fx:IsValid() then fx:Remove() end
        end,
    })
end

return M
