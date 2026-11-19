local M = {STATE = "lumine_dendro_root_cast"}

-- Native lunge_pre is 12 frames. For a spear the hit is 8 frames into atk_pre/atk.
local SPEED = 2
local WINDUP_FRAME = 12 / SPEED
local CONTACT_FRAME = WINDUP_FRAME + 8 / SPEED
local END_FRAME = WINDUP_FRAME + math.ceil((6 + 19) / SPEED)

function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nopredict", "nomorph"},
        onenter = function(inst, aim)
            inst.sg.statemem.aim = aim
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            if aim then
                local x, y, z = inst.Transform:GetWorldPosition()
                inst:ForceFacePoint(x + aim.dx, y, z + aim.dz)
            end
            inst.AnimState:PlayAnimation("lunge_pre")
            inst.AnimState:SetDeltaTimeMultiplier(SPEED)
            inst.sg:SetTimeout(END_FRAME * FRAMES)
        end,
        timeline = {
            FrameEvent(WINDUP_FRAME, function(inst)
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
            end),
            FrameEvent(CONTACT_FRAME, function(inst)
                local dendro = inst.components.luminedendro
                local aim = inst.sg.statemem.aim
                inst.sg.statemem.aim = nil
                if dendro and dendro:ReleaseRoot(aim) then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
                end
            end),
        },
        ontimeout = function(inst) inst.sg:GoToState("idle") end,
        onexit = function(inst) inst.AnimState:SetDeltaTimeMultiplier(1) end,
    })
end

return M
