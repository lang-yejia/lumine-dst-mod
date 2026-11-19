local Rules = require("hydro/rules").drop

local function TryCollect(drop)
    local hydro = drop.hydro
    local owner = hydro.inst
    if not hydro:CanUse() then
        drop:Remove()
        return
    end
    if drop.claiming or not owner:IsNear(drop, Rules.pickup_range) then return end
    local health, hunger = owner.components.health, owner.components.hunger
    if not hunger or hunger.current < Rules.hunger or hunger.redirect or health.redirect
        or owner.is_teleporting or health:IsInvincible() or not health:IsHurt() then
        return
    end

    drop.claiming = true
    local before = hunger.current
    hunger:DoDelta(-Rules.hunger)
    local paid = before - hunger.current
    if math.abs(paid - Rules.hunger) <= .001 then
        local current = health.currenthealth
        health:DoDelta(Rules.heal, false, "lumine_hydro_drop", false, owner)
        if health.currenthealth > current then
            local fx = SpawnPrefab("waterstreak_burst")
            if fx then
                fx.Transform:SetPosition(drop.Transform:GetWorldPosition())
                fx.Transform:SetScale(.65, .65, .65)
            end
            drop:Remove()
            return
        end
    end
    if paid > 0 then hunger:DoDelta(paid) end
    drop.claiming = false
end

return function(drop, hydro)
    drop.hydro = hydro
    hydro:Track(drop)
    drop:DoPeriodicTask(.15, TryCollect)
    drop:DoTaskInTime(Rules.duration, drop.Remove)
end
