local Rules = require("cryo/rules")

-- Use native coldness/resistance. Limit only freezes created by this skill,
-- leaving a later freeze from another source under that source's control.
return function(caster, target, duration)
    local freezable = target.components.freezable
    if not freezable or target.components.health:IsDead() then return end
    local old = target._lumine_cryo_freeze
    if freezable:IsFrozen() and not old then return end
    if old then old:Remove(false) end
    local mark = {}
    function mark:Remove(thaw)
        if target._lumine_cryo_freeze ~= self then return end
        target._lumine_cryo_freeze = nil
        caster.effects[self] = nil
        self.task:Cancel()
        target:RemoveEventCallback("onremove", self.clear)
        target:RemoveEventCallback("death", self.clear)
        if thaw ~= false and freezable.wearofftask == self.native_task then
            if self.native_task then self.native_task:Cancel() freezable.wearofftask = nil end
            freezable:Unfreeze()
        end
    end
    mark.clear = function() mark:Remove() end
    -- Register the expiry before AddColdness creates its native thaw timer.
    -- DST rounds both tasks to simulation ticks, so their insertion order matters.
    mark.task = target:DoTaskInTime(duration, mark.clear)
    freezable:AddColdness(Rules.coldness, duration)
    if not freezable:IsFrozen() then mark.task:Cancel() return end
    mark.native_task = freezable.wearofftask
    target._lumine_cryo_freeze = mark
    caster:Track(mark)
    target:ListenForEvent("onremove", mark.clear)
    target:ListenForEvent("death", mark.clear)
end
