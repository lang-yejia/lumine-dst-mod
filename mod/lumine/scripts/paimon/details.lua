-- 只改变动画、眼睛符号与停稳后的朝向，不操作位移、容器或玩家输入。
local C = require("paimon/config")
local M = {}
local idleposes = {"lookaround", "stretch", "wave", "proud", "cheer"}
local followposes = {"follow_wave", "follow_proud", "follow_cheer"}
local durations = {lookaround=2, stretch=2, wave=2, proud=2.4, cheer=1.8,
    follow_wave=2, follow_proud=2.4, follow_cheer=1.8}
local function Between(a, b) return a + (b-a)*math.random() end
local function Eyes(inst, closed)
    for _, facing in ipairs({"down", "side"}) do
        if closed then
            inst.AnimState:OverrideSymbol("idle_"..facing, "lumine_paimon", "blink_"..facing)
        else inst.AnimState:ClearOverrideSymbol("idle_"..facing) end
    end
end
function M.Reset(inst)
    if inst._details and inst._details.closeduntil then Eyes(inst, false) end
    inst._details = nil
    inst._guide_look = nil
end
function M.Select(inst, base, combat)
    local now = GetTime()
    if not inst._details then
        inst._details = { blinkat = now+Between(3,7) }
    end
    local d = inst._details
    if d.closeduntil and now >= d.closeduntil then
        Eyes(inst, false); d.closeduntil = nil; d.blinkat = now+Between(3,7)
    elseif not d.closeduntil and now >= d.blinkat then
        Eyes(inst, true); d.closeduntil = now+.16
    end
    local action = inst.owner and inst.owner:GetBufferedAction()
    local interacting = inst.components.container:IsOpen() or (action and action.target == inst)
    if base == "follow" and not interacting and not combat and (inst.satiety or 1) > 0 then
        inst._guide_look = nil
        d.followed = true
        d.idlesince,d.stage,d.gesture,d.gestureat = nil,nil,nil,nil
        d.followat = d.followat or now+Between(C.FOLLOW_GESTURE_MIN,C.FOLLOW_GESTURE_MAX)
        if d.followgesture and now >= d.followuntil then
            d.followgesture = nil
            d.followat = now+Between(C.FOLLOW_GESTURE_MIN,C.FOLLOW_GESTURE_MAX)
        end
        if not d.followgesture and now >= d.followat then
            d.followat = now+Between(C.FOLLOW_GESTURE_MIN,C.FOLLOW_GESTURE_MAX)
            if math.random() < C.FOLLOW_GESTURE_CHANCE then
                -- 排除上一次姿势，连续跑动时也会换动作，不改变朝向或速度。
                local choices = {}
                for _,pose in ipairs(followposes) do
                    if pose ~= d.lastfollow then choices[#choices+1] = pose end
                end
                local index = math.min(#choices, math.floor(math.random()*#choices)+1)
                d.followgesture = choices[index]
                d.lastfollow = d.followgesture
                d.followuntil = now+durations[d.followgesture]
            end
        end
        return d.followgesture or base
    end
    d.followgesture,d.followat,d.followuntil = nil,nil,nil
    local pointing = inst._guide_look and (base=="hungry" or base=="worried")
    local busy = (base ~= "idle" and not pointing) or interacting or combat
    if busy then
        inst._guide_look = nil
        d.followed = base == "follow"
        d.idlesince,d.stage,d.gesture,d.gestureat = nil,nil,nil,nil
        return base
    end
    local look = inst._guide_look
    if look then
        if now<look.untiltime and look.target:IsValid() then
            inst:ForceFacePoint(look.target.Transform:GetWorldPosition())
            d.gesture = nil
            d.gestureat = now+Between(3,5)
            return "lookaround"
        end
        inst._guide_look = nil
    end
    if not d.idlesince then
        d.idlesince = now
        d.stage = d.followed and 0 or 1
        d.gestureat = d.gestureat or now+(d.followed and .6 or Between(3,5))
        d.followed = nil
    end
    if d.gesture and now >= d.untiltime then
        d.gesture = nil; d.gestureat = now+Between(C.IDLE_GESTURE_MIN,C.IDLE_GESTURE_MAX)
    end
    if not d.gesture and now >= d.gestureat then
        if d.stage == 0 then
            -- 刚停稳时先看一眼主人，只转向，不挪到某个精确位置。
            if inst.owner and inst.owner:IsValid() then
                inst:ForceFacePoint(inst.owner.Transform:GetWorldPosition())
            end
            d.stage,d.gestureat = 1,now+Between(3,5)
        else
            d.gesture = idleposes[d.stage]
            d.stage = d.stage % #idleposes + 1
            d.untiltime = now + durations[d.gesture]
        end
    end
    return d.gesture or base
end
return M
