-- For base damage supplied directly to GetAttacked. Combat:DoAttack already
-- applies the attacker's externaldamagemultipliers when it calculates damage.
return function(attacker, target, damage, weapon, stimuli)
    local pyro = attacker and attacker.components.luminepyro
    if pyro then damage = damage * pyro:GetDamageMultiplier(target) end
    local cryo = attacker and attacker.components.luminecryo
    if cryo then return require("cryo/combat").Direct(cryo, target, damage, weapon, stimuli) end
    return target.components.combat:GetAttacked(attacker, damage, weapon, stimuli)
end
