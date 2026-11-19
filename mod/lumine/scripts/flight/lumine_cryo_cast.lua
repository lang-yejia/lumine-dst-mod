local M = {STATE = "lumine_cryo_cast"}
function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nopredict", "nomorph"},
        onenter = function(inst, cast)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst.sg.statemem.cast = cast
            inst.AnimState:PlayAnimation("staff_pre")
            inst.AnimState:PushAnimation("staff", false)
            inst.AnimState:SetDeltaTimeMultiplier(3)
            inst:ForceFacePoint(cast.x, 0, cast.z)
            local fx = SpawnPrefab("staffcastfx")
            if fx then
                fx.entity:SetParent(inst.entity)
                fx:SetUp({.5, .8, 1})
                fx.AnimState:SetDeltaTimeMultiplier(3)
                inst.sg.statemem.fx = fx
            end
            inst.sg:SetTimeout(23 * FRAMES)
        end,
        timeline = {
            FrameEvent(18, function(inst)
                inst.components.luminecryo:Release(inst.sg.statemem.cast)
            end),
        },
        ontimeout = function(inst) inst.sg:GoToState("idle") end,
        onexit = function(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1)
            local fx = inst.sg.statemem.fx
            if fx and fx:IsValid() then fx:Remove() end
        end,
    })
end
return M
