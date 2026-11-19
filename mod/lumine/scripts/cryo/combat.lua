local M = {}

local function Frozen(target)
    local component = target and target.components.freezable
    return component and component:IsFrozen()
end

local function FinishAttack(cryo, previous, attack, ...)
    cryo.attack = previous
    if attack.pillars and cryo:CanUse() then
        local p = attack.pillars
        cryo:Pillars(p.x, p.z)
    end
    return ...
end

function M.Install(cryo)
    local combat = cryo.inst.components.combat
    cryo.original_combat = {}
    cryo.combat_hooks = {}
    local function Wrap(name, fn)
        local original = combat[name]
        cryo.original_combat[name] = original
        local hook = fn(original)
        cryo.combat_hooks[name] = hook
        combat[name] = hook
    end

    Wrap("GetAttacked_Internal", function(original)
        return function(component, attacker, damage, weapon, stimuli, special, ...)
            local total = damage or 0
            for _, amount in pairs(special or {}) do total = total + amount end
            if total > 0 and cryo.shield and cryo:CanUse()
                and not cryo.inst.components.health:IsInvincible() then
                cryo:BreakShield()
                cryo.inst:PushEvent("blocked", {attacker = attacker, damage = damage, weapon = weapon,
                    stimuli = stimuli, spdamage = special, damageresolved = 0})
                return false
            end
            return original(component, attacker, damage, weapon, stimuli, special, ...)
        end
    end)

    Wrap("CalcDamage", function(original)
        return function(component, target, ...)
            local damage, special = original(component, target, ...)
            if cryo:CanUse() then
                local attack = cryo.attack
                local frozen = Frozen(target)
                if attack and attack.resolved[target] then frozen = false end
                if frozen and ((damage or 0) > 0 or special ~= nil) then
                    damage = (damage or 0) * 2
                    if special then
                        local scaled = {}
                        for key, amount in pairs(special) do scaled[key] = amount * 2 end
                        special = scaled
                    end
                    if attack then attack.frozen[target] = true end
                end
            end
            return damage, special
        end
    end)

    for _, name in ipairs({"DoAttack", "DoAreaAttack"}) do
        Wrap(name, function(original)
            return function(component, ...)
                if not cryo:CanUse() or cryo.attack then return original(component, ...) end
                local previous = cryo.attack
                local attack = {resolved = {}, frozen = {}, projectile = name == "DoAttack" and select(3, ...) or nil}
                cryo.attack = attack
                return FinishAttack(cryo, previous, attack, original(component, ...))
            end
        end)
    end
end

function M.OnHit(cryo, data)
    local attack = cryo.attack
    if not attack or not data or not data.from_doattack or (data.damageresolved or 0) <= 0 then return end
    local target = data.target
    if not target or not target:IsValid() then return end
    if not attack.resolved[target] then
        attack.resolved[target] = true
        if attack.frozen[target] and Frozen(target) then target.components.freezable:Unfreeze() end
    end
    cryo:EnhanceHit(attack, data)
end

function M.Direct(cryo, target, damage, weapon, stimuli)
    local freezable = target.components.freezable
    if cryo:CanUse() and damage > 0 and freezable and freezable:IsFrozen() then
        damage = damage * 2
        freezable:Unfreeze()
    end
    return target.components.combat:GetAttacked(cryo.inst, damage, weapon, stimuli)
end

function M.Uninstall(cryo)
    local combat = cryo.inst.components.combat
    for name, hook in pairs(cryo.combat_hooks) do
        if combat[name] == hook then combat[name] = cryo.original_combat[name] end
    end
end

return M
