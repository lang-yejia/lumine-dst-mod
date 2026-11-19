local M = {
    ENTER = "lumine_pyro_burst_enter",
    CHANNEL = "lumine_pyro_fire_channel",
    RELEASE = "lumine_pyro_fire_release",
}

function M.PlayShot(inst)
    if inst.sg:HasStateTag("lumine_pyro_shot") then
        inst.AnimState:PlayAnimation("pyrocast")
        inst.AnimState:SetFrame(3)
        inst.SoundEmitter:PlaySound("meta3/willow/pyrokinetic_activate")
    end
end

local function StopMovement(inst)
    inst.components.locomotor:Stop()
    inst:ClearBufferedAction()
end

local function Idle(inst)
    inst.sg:GoToState("idle")
end

function M.Install(add_state)
    add_state("wilson", State {
        name = M.ENTER,
        tags = {"busy", "doing", "nopredict", "nomorph"},
        onenter = function(inst)
            StopMovement(inst)
            inst.AnimState:PlayAnimation("pyrocast_pre")
            inst.AnimState:PushAnimation("pyrocast", false)
            inst.SoundEmitter:PlaySound("meta3/willow/pyrokinetic_activate")
            inst.sg:SetTimeout(9 * FRAMES)
        end,
        ontimeout = Idle,
    })
    add_state("wilson", State {
        name = M.CHANNEL,
        tags = {"busy", "doing", "canrotate", "nopredict", "nomorph", "lumine_pyro_shot"},
        onenter = function(inst)
            StopMovement(inst)
        end,
        onexit = function(inst)
            local pyro = inst.components.luminepyro
            if pyro then pyro:EndHold(false) end
        end,
    })
    add_state("wilson", State {
        name = M.RELEASE,
        tags = {"busy", "doing", "nopredict", "nomorph"},
        onenter = function(inst, finish_shot)
            StopMovement(inst)
            if not finish_shot then inst.AnimState:PlayAnimation("pyrocast_pre") end
            inst.sg:SetTimeout((finish_shot and 5 or 4) * FRAMES)
        end,
        ontimeout = Idle,
    })
end

return M
