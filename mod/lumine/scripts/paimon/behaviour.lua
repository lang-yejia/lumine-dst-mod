-- 有边界的小幅变化：只选择主人周围的位置，不寻找/操作世界物体。
local C = require("paimon/config")
local M = {}
local function Between(a, b) return a + (b - a) * math.random() end
local function SetWorldSpeed(inst, speed)
    -- 原生 Physics 的 motor 速度还会乘 Transform 缩放；跟随计算使用世界单位。
    -- 不能直接把世界速度送入 motor，否则 1.2 倍模型实际会多跑 20%。
    local scale = inst.Transform:GetScale()
    inst.Physics:SetMotorVel(speed / math.max(.001, math.abs(scale)), 0, 0)
end
local function TrailTarget(travel, ox, oz, vx, vz, dt)
    -- 只保留走过的最后一段跟随路线；拐角处追旧路线，不追固定世界方位。
    local points = travel.points
    if not points then
        local speed = math.max(.001,math.sqrt(vx*vx+vz*vz))
        points = {{x=ox-vx/speed*C.REST_RADIUS,z=oz-vz/speed*C.REST_RADIUS},{x=ox,z=oz}}
        travel.points = points
    elseif (ox-points[#points].x)^2+(oz-points[#points].z)^2 > .0001 then
        points[#points+1] = {x=ox,z=oz}
    end
    while #points>C.TRAIL_MAX_POINTS do table.remove(points,1) end
    local remaining, gx, gz = C.REST_RADIUS, points[1].x, points[1].z
    for i=#points,2,-1 do
        local a,b = points[i],points[i-1]
        local dx,dz = b.x-a.x,b.z-a.z
        local length = math.sqrt(dx*dx+dz*dz)
        if length>=remaining then
            gx,gz = a.x+dx*remaining/length,a.z+dz*remaining/length
            for _=1,i-2 do table.remove(points,1) end
            break
        end
        remaining = remaining-length
    end
    local tx,tz = travel.gx and (gx-travel.gx)/dt or vx,travel.gz and (gz-travel.gz)/dt or vz
    local oldspeed = (travel.targetvx or tx)^2+(travel.targetvz or tz)^2
    local tau = tx*tx+tz*tz<oldspeed and C.TRAVEL_BRAKE_TIME or C.OWNER_SPEED_SMOOTH_TIME
    local blend = 1-math.exp(-dt/tau)
    travel.targetvx = (travel.targetvx or tx)+((tx)-(travel.targetvx or tx))*blend
    travel.targetvz = (travel.targetvz or tz)+((tz)-(travel.targetvz or tz))*blend
    travel.gx,travel.gz = gx,gz
    return gx,gz
end
local function State(inst)
    if not inst._motion then
        inst._motion = { nextdecision = GetTime() + Between(C.DECISION_MIN, C.DECISION_MAX) }
    end
    return inst._motion
end
function M.Reset(inst)
    inst._motion = nil
    inst._guide_look,inst._guide_catchup_until = nil,nil
    inst.Physics:Stop()
end
function M.MarkCombat(inst)
    inst._combat_until = GetTime() + C.COMBAT_MEMORY_TIME
end

-- 指方向时允许两秒自然拉开间距，随后实际飞回；不在 9 单位处打断成瞬移。
function M.GuideRecoveryDistance(inst, owner, distance, combat)
    local look = inst._guide_look
    local action = owner:GetBufferedAction()
    if combat or inst.components.container:IsOpen() or (action and action.target==inst)
        or GetTime()<(inst._eating_until or 0) or (look and not look.target:IsValid()) then
        inst._guide_look = nil
    elseif look and GetTime()>=look.untiltime then
        inst._guide_look = nil
    end
    if inst._guide_catchup_until then
        if GetTime()>=inst._guide_catchup_until or (not inst._guide_look and distance<=C.FOLLOW_MAX) then
            inst._guide_catchup_until = nil
        else
            return C.GUIDE_RECOVER_DISTANCE
        end
    end
    return C.TELEPORT_DISTANCE
end
function M.InCombat(inst, owner)
    if GetTime() < (inst._combat_until or 0) then return true end
    local target = owner.components.combat and owner.components.combat.target
    return target ~= nil and target:IsValid()
        and owner:GetDistanceSqToInst(target) <= 12 * 12
        and (target.components.health == nil or not target.components.health:IsDead())
        or (owner.sg ~= nil and owner.sg:HasStateTag("attack")) or false
end

local function AwayAngle(owner, px, pz, ox, oz, combat)
    local target = combat and owner.components.combat and owner.components.combat.target
    if target and target:IsValid() then
        local tx, _, tz = target.Transform:GetWorldPosition()
        if (tx-ox)^2+(tz-oz)^2 > .01 then return math.atan2(oz-tz, ox-tx) end
    end
    return (px-ox)^2+(pz-oz)^2 > .01 and math.atan2(pz-oz, px-ox) or 0
end

function M.Recover(inst, owner, combat)
    local ox, oy, oz = owner.Transform:GetWorldPosition()
    local px, _, pz = inst.Transform:GetWorldPosition()
    local angle = AwayAngle(owner, px, pz, ox, oz, combat)
    M.Reset(inst)
    inst.Physics:Teleport(ox + math.cos(angle)*C.REST_RADIUS, oy, oz + math.sin(angle)*C.REST_RADIUS)
    return C.REST_RADIUS
end

function M.Step(inst, owner, distance, combat)
    local state, now = State(inst), GetTime()
    local ox, oy, oz = owner.Transform:GetWorldPosition()
    local px, _, pz = inst.Transform:GetWorldPosition()
    local moving = state.ox ~= nil and (ox-state.ox)^2+(oz-state.oz)^2 > .0025
    local approaching = moving and distance*distance < (px-state.ox)^2+(pz-state.oz)^2
    local dt = math.max(.001, now - (state.sampletime or now - C.FOLLOW_TICK))
    local vx, vz = state.ox and (ox-state.ox)/dt or 0, state.oz and (oz-state.oz)/dt or 0
    local owner_speed = math.sqrt(vx*vx+vz*vz)
    -- 位置采样会跨动画帧/服务器帧，单次差分不能直接当作稳定速度。
    -- 连续慢行也进入跟随；短暂的零位移不清空已经建立的追赶状态。
    state.movingtime = moving and (state.movingtime or 0)+dt or 0
    if moving then state.lastmoving = now end
    local sampleblend = 1-math.exp(-dt/C.OWNER_SPEED_SMOOTH_TIME)
    if state.velocityx == nil or (moving and not state.travel and state.movingtime <= dt) then
        state.velocityx, state.velocityz = vx, vz
    else
        state.velocityx = state.velocityx+(vx-state.velocityx)*sampleblend
        state.velocityz = state.velocityz+(vz-state.velocityz)*sampleblend
    end
    state.fasttime = owner_speed >= 6.8 and (state.fasttime or 0) + dt or 0
    if state.fasttime == 0 then state.fastremark = nil end
    state.sampletime = now
    state.ox, state.oz = ox, oz
    local combatstarted = combat and not state.combat
    if combat ~= state.combat then state.goal = nil; state.combat = combat end
    -- 原版 RUMMAGE 需要走到物理半径附近；近身阈值只作停留参考，不能用于赶走主人。
    -- GetBufferedAction 同时覆盖实体和 locomotor 中尚在走路的动作。
    local action = owner:GetBufferedAction()
    local opening = action and action.target == inst
        and (action.action == ACTIONS.RUMMAGE or action.action == ACTIONS.PAIMON_FEED
            or action.action == ACTIONS.PAIMON_WISHES)
    local look = inst._guide_look
    if look and now<look.untiltime and look.target:IsValid() and not combat and not opening
        and not inst.components.container:IsOpen() and now>=(inst._eating_until or 0) then
        -- 继续采样主人位置，但本体停住；结束后从最新位置恢复连续追赶。
        state.goal,state.pauseuntil,state.travel,state.interactionuntil = nil,nil,nil,nil
        state.nextdecision = now+Between(C.DECISION_MIN,C.DECISION_MAX)
        inst.Physics:Stop()
        inst:ForceFacePoint(look.target.Transform:GetWorldPosition())
        return false
    end
    -- 正在同行时，变速/转弯导致的短暂靠近不是开包意图，不能打断跟随。
    -- 原地等候的派蒙仍会让手动靠近的主人取物；明确 RUMMAGE 始终优先。
    if distance <= C.FOLLOW_MAX and (opening or (approaching and not state.travel)) then
        state.interactionuntil = now + C.INTERACTION_GRACE
    elseif moving and not approaching and not opening then
        -- 主人已经路过并离开，取物等待应立即结束，不能等到活动范围外才突然追赶。
        state.interactionuntil = nil
    end
    local waiting = distance <= C.FOLLOW_MAX
        and ((distance < C.FOLLOW_MIN and not state.goal and not state.travel and (not moving or approaching))
            or now < (state.interactionuntil or 0))
    if inst.components.container:IsOpen() or opening or waiting then
        state.goal, state.pauseuntil = nil, nil
        state.travel = nil
        state.nextdecision = now + Between(C.DECISION_MIN, C.DECISION_MAX)
        inst.Physics:Stop()
        return false
    end
    -- 停在合适范围后只消散已有速度，不再追精确圆点。短暂丢采样仍保留路线。
    if not moving and state.travel and distance <= C.FOLLOW_MAX then
        local travel = state.travel
        local oldspeed = math.sqrt(travel.vx^2+travel.vz^2)
        local brake = math.min(C.REST_BRAKE_TIME,math.max(.04,(distance-C.REST_BRAKE_MARGIN)/math.max(.001,oldspeed)))
        local decay = math.exp(-dt/brake)
        travel.vx,travel.vz = travel.vx*decay,travel.vz*decay
        local speed = math.sqrt(travel.vx^2+travel.vz^2)
        state.goal = nil
        state.nextdecision = now + Between(C.DECISION_MIN,C.DECISION_MAX)
        if speed > C.REST_STOP_SPEED and now-(state.lastmoving or now) < C.REST_SETTLE_TIME then
            SetWorldSpeed(inst,speed)
            return true
        end
        state.travel = nil
        inst.Physics:Stop()
        return false
    end
    -- 不再按每次采样是否越过 4 单位速度来切换两套控制器。
    -- 小幅移动需持续两次采样，普通跑动立即跟上，赶路中容忍短暂采样间断。
    -- 突然的大位移也先确认持续移动，避免一次位置修正被当成极高速起跑。
    local travelling = moving and ((owner_speed >= C.FOLLOW_SPEED and owner_speed <= C.CATCHUP_SPEED*2)
        or (owner_speed >= C.TRAVEL_MIN_SPEED and state.movingtime >= C.TRAVEL_START_TIME-.001))
        or (state.travel ~= nil and now-(state.lastmoving or 0) <= C.TRAVEL_STOP_GRACE)
    if travelling then
        if state.fasttime >= 4 and not state.fastremark then
            inst.dialogue:Offer("fast_travel")
            state.fastremark = true
        end
        if not state.travel then
            state.travel = { vx = state.velocityx, vz = state.velocityz, departure = distance < C.FOLLOW_MIN }
        end
        local travel = state.travel
        local gx,gz = TrailTarget(travel,ox,oz,state.velocityx,state.velocityz,dt)
        travel.angle = math.atan2(gz-oz,gx-ox)
        local gain = C.TRAVEL_GAIN+math.min(1,math.max(0,distance-C.FOLLOW_MAX))
        local desiredx, desiredz = travel.targetvx + (gx-px)*gain, travel.targetvz + (gz-pz)*gain
        -- 主人刚从身旁走过时，新目标可能暂时落在派蒙后面。
        -- 近身时缓慢同向前进让间距自然拉开，不倒退或在零速附近反复启停。
        if distance >= C.FOLLOW_MIN then travel.departure = nil end
        if moving and travel.departure then
            local ux,uz = vx/owner_speed,vz/owner_speed
            local forward = desiredx*ux+desiredz*uz
            local minimum = owner_speed*.1
            if forward < minimum then
                desiredx,desiredz = desiredx+ux*(minimum-forward),desiredz+uz*(minimum-forward)
            end
        end
        -- 主人停步后的短暂减速不为了回到精确圆点突然倒车。
        if not moving and desiredx*travel.vx+desiredz*travel.vz < 0 then desiredx,desiredz = 0,0 end
        local desiredspeed = math.sqrt(desiredx*desiredx+desiredz*desiredz)
        local extra = now<(inst._guide_catchup_until or 0) and C.GUIDE_CATCHUP_EXTRA_SPEED or C.TRAVEL_EXTRA_SPEED
        local limit = math.sqrt(state.velocityx^2+state.velocityz^2) + extra
        if desiredspeed > limit then desiredx, desiredz = desiredx*limit/desiredspeed, desiredz*limit/desiredspeed end
        local tau = desiredspeed*desiredspeed < travel.vx*travel.vx+travel.vz*travel.vz
            and C.TRAVEL_BRAKE_TIME or C.TRAVEL_SMOOTH_TIME
        local blend = 1 - math.exp(-dt/tau)
        local smoothx = travel.vx+(desiredx-travel.vx)*blend
        local smoothz = travel.vz+(desiredz-travel.vz)*blend
        -- 掉头时相反的速度向量会相互抵消，即使主人仍在跑也可能误判为停步。
        -- 接近抵消点时改用目标方向，随后仍由转向限幅带着她绕回去。
        if moving and desiredx*travel.vx+desiredz*travel.vz < 0 then
            local targetlength = math.sqrt(desiredx^2+desiredz^2)
            local minimum = math.min(targetlength, math.sqrt(travel.vx^2+travel.vz^2))*.25
            if smoothx^2+smoothz^2 < minimum^2 then
                smoothx,smoothz = desiredx*minimum/targetlength,desiredz*minimum/targetlength
            end
        end
        local oldangle = math.atan2(travel.vz,travel.vx)
        local newangle = math.atan2(smoothz,smoothx)
        local delta = (newangle-oldangle+math.pi)%(2*math.pi)-math.pi
        local turn = math.rad(C.TRAVEL_TURN_RATE)*dt
        local angle = oldangle+math.max(-turn,math.min(turn,delta))
        -- 掉头时先收速再绕回来，不能保持直线速度画大圈触发远距回收。
        local speed = math.sqrt(smoothx^2+smoothz^2)
        if math.abs(delta)>turn then speed = speed*.4 end
        travel.vx,travel.vz = math.cos(angle)*speed,math.sin(angle)*speed
        state.goal = { angle = travel.angle, radius = C.REST_RADIUS }
        state.pauseuntil = nil
        state.nextdecision = now + Between(C.DECISION_MIN, C.DECISION_MAX)
        if speed > .01 then
            inst:ForceFacePoint(px+travel.vx, oy, pz+travel.vz)
            SetWorldSpeed(inst, speed)
            return true
        end
        inst.Physics:Stop()
        return false
    end
    -- 已停在允许范围就原地休息，不再追着上一次的偏移点来回校正。
    if state.travel and distance <= C.FOLLOW_MAX then state.goal = nil end
    state.travel = nil
    -- 战斗只在开始时让开一次，在跟随半径附近停留；主人靠近取物时停止让位。
    -- 不设置战斗最小间距，否则主人越靠近，派蒙越往外逃。
    if combat then
        state.pauseuntil = nil
        if approaching and distance <= C.FOLLOW_MAX then state.goal = nil
        elseif combatstarted or distance > C.FOLLOW_MAX then
            if not state.goal then
                state.goal = { angle = AwayAngle(owner, px, pz, ox, oz, true), radius = C.REST_RADIUS }
            end
        end
    end
    local urgent = distance > C.FOLLOW_MAX
    if urgent then state.pauseuntil = nil end
    if state.pauseuntil and now < state.pauseuntil then inst.Physics:Stop(); return false end

    if not combat and urgent and not state.goal then
        state.goal = { angle = AwayAngle(owner, px, pz, ox, oz, combat),
            radius = Between(C.CATCHUP_RADIUS_MIN, C.CATCHUP_RADIUS_MAX) }
    elseif not combat and not urgent and now >= state.nextdecision and now >= (inst._eating_until or 0) then
        state.nextdecision = now + Between(C.DECISION_MIN, C.DECISION_MAX)
        -- 每次低频决策有 60% 概率做小幅变化；持续赶路仍走上面的平滑跟随分支。
        if math.random() < C.VARIATION_CHANCE then
            if moving then
                state.pauseuntil = now + Between(C.PAUSE_MIN, C.PAUSE_MAX)
                state.goal = nil
                inst.Physics:Stop()
                return false
            else
                local angle = AwayAngle(owner, px, pz, ox, oz, false)
                local side = math.random() < .5 and -1 or 1
                state.goal = { angle = angle + side*Between(.30, .65), radius = Between(C.IDLE_RADIUS_MIN, C.IDLE_RADIUS_MAX) }
            end
        end
    end
    local goal = state.goal
    if not goal then inst.Physics:Stop(); return false end
    local gx, gz = ox + math.cos(goal.angle)*goal.radius, oz + math.sin(goal.angle)*goal.radius
    local remaining = math.sqrt((gx-px)^2+(gz-pz)^2)
    if remaining < .15 then state.goal = nil; inst.Physics:Stop(); return false end
    inst:ForceFacePoint(gx, oy, gz)
    local speed = math.min(C.CATCHUP_SPEED, C.FOLLOW_SPEED + math.max(0, distance-C.FOLLOW_MAX)*C.TRAVEL_GAIN)
    SetWorldSpeed(inst, math.min(speed, remaining / C.FOLLOW_TICK))
    return true
end
return M
