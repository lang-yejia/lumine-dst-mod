local M = {STATE = "lumine_hydro_cast"}
local COLOUR = {.32, .73, 1}
local normal = {
    pre = "atk_pre", anim = "atk", speed = 1.6, release = 5, finish = 16,
}
local burst = {
    pre = "staff_pre", anim = "staff", speed = 2.5, release = 21, finish = 28,
}

function M.Install(add_state)
    add_state("wilson", State {
        name = M.STATE,
        tags = {"busy", "doing", "nomorph", "nopredict"},
        onenter = function(inst, aim)
            local data = aim.skill == "stream" and normal or burst
            inst.sg.statemem.aim = aim
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            local x, y, z = inst.Transform:GetWorldPosition()
            inst:ForceFacePoint(x + aim.dx, y, z + aim.dz)
            inst.AnimState:PlayAnimation(data.pre)
            inst.AnimState:PushAnimation(data.anim, false)
            inst.AnimState:SetDeltaTimeMultiplier(data.speed)
            local fx = SpawnPrefab("staffcastfx")
            if fx then
                fx.entity:SetParent(inst.entity)
                fx:SetUp(COLOUR)
                fx.AnimState:SetDeltaTimeMultiplier(3)
                inst.sg.statemem.fx = fx
            end
            inst.sg:SetTimeout(data.finish * FRAMES)
        end,
        timeline = {
            FrameEvent(normal.release, function(inst)
                local aim = inst.sg.statemem.aim
                if aim and aim.skill == "stream" and inst.components.luminehydro:Release(aim) then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
                end
            end),
            FrameEvent(burst.release, function(inst)
                local aim = inst.sg.statemem.aim
                if aim and aim.skill == "bubble" and inst.components.luminehydro:Release(aim) then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/use_gemstaff")
                end
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
