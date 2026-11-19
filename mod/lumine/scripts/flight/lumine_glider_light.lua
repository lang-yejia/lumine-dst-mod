-- Local visuals follow the replicated flight phase on hosts and clients.
local Light = {}
local WINGS = { "lumine_glider_left", "lumine_glider_right" }

function Light.Refresh(inst)
    local phase = inst.lumine_glider_phase:value()
    local lit = TheWorld.state.isnight and (phase == 1 or phase == 2)
        and not inst:HasTag("INLIMBO") and not inst:HasTag("playerghost")
    for _, symbol in ipairs(WINGS) do
        inst.AnimState:SetSymbolLightOverride(symbol, lit and .45 or 0)
        inst.AnimState:SetSymbolMultColour(symbol, lit and .75 or 1, lit and .88 or 1, 1, 1)
    end
    if lit and not inst._lumine_glider_light then
        local fx = CreateEntity()
        fx.entity:AddTransform()
        fx.entity:AddLight()
        fx.entity:SetParent(inst.entity)
        fx.Transform:SetPosition(0, 0, 0)
        fx:AddTag("FX")
        fx:AddTag("NOCLICK")
        fx.persists = false
        fx.Light:SetColour(.55, .75, 1)
        fx.Light:SetIntensity(.45)
        fx.Light:SetFalloff(.8)
        fx.Light:SetRadius(2)
        fx.Light:Enable(true)
        inst._lumine_glider_light = fx
    elseif not lit then
        Light.Remove(inst)
    end
end

function Light.Remove(inst)
    if inst._lumine_glider_light then
        inst._lumine_glider_light:Remove()
        inst._lumine_glider_light = nil
    end
end

function Light.CommonInit(inst)
    if TheNet:IsDedicated() then return end
    inst._lumine_glider_light_visuals = true
    inst:WatchWorldState("isnight", Light.Refresh)
    for _, event in ipairs({ "lumine_glider_dirty", "enterlimbo", "exitlimbo", "ms_becameghost" }) do
        inst:ListenForEvent(event, Light.Refresh)
    end
    inst:ListenForEvent("onremove", Light.Remove)
    inst:DoTaskInTime(0, Light.Refresh)
end

return Light
