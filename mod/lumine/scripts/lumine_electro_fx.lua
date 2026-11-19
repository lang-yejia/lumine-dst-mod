local M = {}

function M.TintImpact(inst)
    inst.AnimState:SetMultColour(.68, .22, 1, 1)
    inst.AnimState:SetAddColour(.15, .01, .30, 0)
end

function M.WeaponHit(attacker, target)
    if not attacker or not attacker:IsValid() or not target or not target:IsValid() then return end
    local prefab = IsEntityElectricImmune(target) and "lumine_electro_immune_sparks" or "lumine_electro_sparks"
    local sparks = SpawnPrefab(prefab)
    if sparks then sparks:AlignToTarget(target, attacker) end
end

return M
