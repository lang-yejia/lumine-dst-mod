local Rules = require("pyro/rules").scorch
local Targets = require("lumine_dendro_targets")

local M = {}
local CAUSE = "lumine_pyro_scorch"
local STOP_EVENTS = {"death", "onremove", "enterlimbo"}

local function GetCaster(mark)
    local owner = mark.owner
    local pyro = owner:IsValid() and owner.components.luminepyro
    if pyro and not owner.components.health:IsDead() and not owner:HasTag("playerghost")
        and pyro:IsResonating() then
        return pyro
    end
end

function M.IsActive(target)
    local mark = target and target._lumine_pyro_scorch
    return mark ~= nil and GetTime() <= mark.expires + FRAMES * .5 and GetCaster(mark) ~= nil
end

local function Tick(target)
    local mark = target._lumine_pyro_scorch
    if not mark then return end
    local now = GetTime()
    local pyro = GetCaster(mark)
    local health = target.components.health
    if not pyro or not health or health:IsDead() or now > mark.expires + FRAMES * .5 then
        mark.clear()
        return
    end
    if Targets.IsWaveTarget(mark.owner, target) then
        -- Go through Health's usual protections without invoking burnable or hit reactions.
        local damage = Rules.damage * pyro:GetDamageMultiplier(target) * health:GetFireDamageScale()
        if damage > 0 then
            health:DoDelta(-damage, true, CAUSE, nil, mark.owner)
            if health:IsDead() and mark.owner:IsValid() then
                mark.owner:PushEvent("killed", {victim = target, attacker = mark.owner})
                local combat = target.components.combat
                if combat and combat.onkilledbyother then combat.onkilledbyother(target, mark.owner) end
            end
        end
    end
    if now >= mark.expires - FRAMES * .5 then mark.clear() end
end

function M.Apply(owner, target)
    if not Targets.IsWaveTarget(owner, target) or target.components.health:GetFireDamageScale() <= 0 then return end
    local mark = target._lumine_pyro_scorch
    if mark then
        mark.owner, mark.expires = owner, GetTime() + Rules.duration
        mark.expiry:Cancel()
        mark.expiry = target:DoTaskInTime(Rules.duration + FRAMES, mark.clear)
        return
    end

    mark = {owner = owner, expires = GetTime() + Rules.duration, fx = SpawnPrefab("lumine_pyro_scorch_fx")}
    target._lumine_pyro_scorch = mark
    if mark.fx then
        target:AddChild(mark.fx)
        mark.fx.Transform:SetPosition(0, .2, 0)
    end
    mark.clear = function()
        if target._lumine_pyro_scorch ~= mark then return end
        target._lumine_pyro_scorch = nil
        mark.tick:Cancel()
        mark.expiry:Cancel()
        for _, event in ipairs(STOP_EVENTS) do target:RemoveEventCallback(event, mark.clear) end
        if mark.fx and mark.fx:IsValid() then mark.fx:Remove() end
    end
    for _, event in ipairs(STOP_EVENTS) do target:ListenForEvent(event, mark.clear) end
    mark.tick = target:DoPeriodicTask(Rules.interval, Tick)
    mark.expiry = target:DoTaskInTime(Rules.duration + FRAMES, mark.clear)
end

return M
