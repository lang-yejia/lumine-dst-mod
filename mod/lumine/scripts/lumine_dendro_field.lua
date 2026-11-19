local DirectDamage = require("lumine_direct_damage")
local Rules = require("lumine_dendro_rules")
local Targets = require("lumine_dendro_targets")
local FIELD, POISON = Rules.FIELD, Rules.POISON

local function ApplyPoison(caster, target)
    local poison = target._lumine_dendro_poison
    if poison then
        if poison.caster ~= caster then
            poison.caster.effects[poison] = nil
            caster:Track(poison)
            poison.caster = caster
        end
        poison.expires = GetTime() + POISON.duration
        return
    end

    poison = {caster = caster, expires = GetTime() + POISON.duration}
    target._lumine_dendro_poison = caster:Track(poison)
    function poison:Remove()
        if target._lumine_dendro_poison ~= self then return end
        target._lumine_dendro_poison = nil
        self.caster.effects[self] = nil
        self.task:Cancel()
        for _, event in ipairs({"death", "onremove", "enterlimbo"}) do
            target:RemoveEventCallback(event, self.clear)
        end
    end
    poison.clear = function() poison:Remove() end
    for _, event in ipairs({"death", "onremove", "enterlimbo"}) do
        target:ListenForEvent(event, poison.clear)
    end

    -- Keep the damage clock on the target when applications refresh the lifetime.
    poison.task = target:DoPeriodicTask(1, function()
        local now = GetTime()
        local source = poison.caster
        local slack = FRAMES * .5
        if now > poison.expires + slack or not source:CanUse()
            or not target:IsValid() or target.components.health:IsDead() then
            poison:Remove()
            return
        end
        if Targets.IsEnemy(source.inst, target) then
            local damage = math.min(POISON.cap, target.components.health.maxhealth * POISON.fraction)
            DirectDamage(source.inst, target, damage, nil, "lumine_dendro_poison")
        end
        if now >= poison.expires - slack then poison:Remove() end
    end)
end

local function PrepareCloud()
    local cloud = SpawnPrefab("sleepcloud_lunar")
    if not cloud then return end
    -- The prefab has no visual-only mode. Cancel its native drowsiness before its first tick.
    if not cloud._drowsytask or not cloud.components.timer then
        cloud:Remove()
        return
    end
    cloud._drowsytask:Cancel()
    cloud._drowsytask = nil
    cloud.persists = false
    cloud.components.timer:SetTimeLeft("disperse", FIELD.duration)
    cloud:ListenForEvent("onremove", function()
        -- Native overlays are network children created with entity:SetParent.
        for _, overlay in ipairs(cloud._overlayfx or {}) do
            if overlay:IsValid() then overlay:Remove() end
        end
        if cloud._basefx and cloud._basefx:IsValid() then cloud._basefx:Remove() end
    end)
    return cloud
end

local M = {Prepare = PrepareCloud}

function M.Start(caster, cloud)
    local owner = caster.inst
    local x, y, z = owner.Transform:GetWorldPosition()
    local expires = GetTime() + FIELD.duration
    local scale = FIELD.radius / 3.5 -- radius of the original moon-cap cloud
    cloud.Transform:SetPosition(x, y, z)
    cloud.Transform:SetScale(scale, scale, scale)
    cloud:SetOwner(owner)
    caster:Track(cloud)
    caster.field = cloud
    owner._lumine_dendro_field_until:set(expires)
    local function EndField()
        if caster.field == cloud then
            caster.field = nil
            owner._lumine_dendro_field_until:set(0)
        end
    end
    cloud:ListenForEvent("onremove", function()
        caster.effects[cloud] = nil
        EndField()
    end)
    local function Scan()
        if not caster:CanUse() then
            cloud:Remove()
            return
        end
        if GetTime() >= expires - FRAMES * .5 then return end
        for _, target in ipairs(Targets.Find(x, z, FIELD.radius)) do
            if Targets.IsEnemy(owner, target) then ApplyPoison(caster, target) end
        end
    end
    local scan = cloud:DoPeriodicTask(FIELD.interval, Scan)
    cloud:DoTaskInTime(FIELD.duration, function()
        scan:Cancel()
        EndField()
    end)
    Scan()
end

return M
