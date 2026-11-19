local L = require("languages/lumine").For("paimon/config")
-- 所有机制数值集中于此；时间单位为真实秒（默认游戏日 480 秒）。
local function Distance(base) return base * 1.5 end
local C = {
    MAX_HUNGER = 200, AUTO_EAT_BELOW = 120,
    HUNGER_PER_DAY = 75, SLOTS = 6, PERISH_RATE = .40,
    SANITY_PER_SECOND = 3 / 60, SANITY_RADIUS = Distance(6),
    SCALE = 1.20, -- 由 1.30 略缩小，接近九成，保留一位小数。
    FOLLOW_MIN = Distance(2), FOLLOW_MAX = Distance(4), REST_RADIUS = Distance(3), TELEPORT_DISTANCE = Distance(6),
    BAG_OPEN_DISTANCE = Distance(4), BAG_CLOSE_DISTANCE = Distance(4.5),
    SPAWN_OFFSET = Distance(2), REST_BRAKE_MARGIN = Distance(.9),
    CATCHUP_RADIUS_MIN = Distance(2.7), CATCHUP_RADIUS_MAX = Distance(3.4),
    IDLE_RADIUS_MIN = Distance(2.8), IDLE_RADIUS_MAX = Distance(3.7),
    VARIATION_CHANCE = .60, DECISION_MIN = 4, DECISION_MAX = 7,
    IDLE_GESTURE_MIN = 5, IDLE_GESTURE_MAX = 9,
    FOLLOW_GESTURE_MIN = 3, FOLLOW_GESTURE_MAX = 6, FOLLOW_GESTURE_CHANCE = .80,
    PAUSE_MIN = .25, PAUSE_MAX = .65, COMBAT_MEMORY_TIME = 3,
    INTERACTION_GRACE = 2, -- 靠近或开包动作结束后，留出停步取物的时间。
    HEIGHT_RECOVERY_DISTANCE = .75,
    FOLLOW_SPEED = 5, CATCHUP_SPEED = 10, FOLLOW_TICK = .1,
    TRAVEL_MIN_SPEED = 1, TRAVEL_START_TIME = .2, TRAVEL_STOP_GRACE = .25,
    OWNER_SPEED_SMOOTH_TIME = .15, TRAVEL_SMOOTH_TIME = .2, TRAVEL_GAIN = 2, TRAVEL_EXTRA_SPEED = 4,
    TRAVEL_BRAKE_TIME = .08, TRAIL_MAX_POINTS = 64,
    REST_BRAKE_TIME = .16, REST_SETTLE_TIME = .65, REST_STOP_SPEED = .15,
    TRAVEL_TURN_RATE = 600, -- 度/秒；掉头至少分三次更新，不瞬间翻向。
    EAT_INTERVAL = 1.6, OBSERVE_INTERVAL = 5,
    GUIDE_RADIUS = 48, GUIDE_SCAN_INTERVAL = 1, GUIDE_GAP = 12, GUIDE_MAX_SITES = 2048,
    GUIDE_POINT_TIME = 2, GUIDE_CATCHUP_TIME = 8, GUIDE_CATCHUP_EXTRA_SPEED = 10,
    GUIDE_INDICATOR_TIME = 5,
    ORDER_DAYS = 2, ANNIVERSARY_DAYS = 70,
    CAKE_HEALTH = 150, CAKE_HUNGER = 150, CAKE_SANITY = 200,
    GUIDE_RECOVER_DISTANCE = 64,
    RECENT_LINES = 15, SPEECH_TIME = 4.5, SPEECH_GAP = 12,
    QUIET_MIN = 20, QUIET_MAX = 30, -- 一句话结束后的普通闲聊留白；不阻塞紧急提醒。
    LORE_COOLDOWN = 480, LORE_CHANCE = .22,
}
function C.ConfigurePerishRate(rate)
    C.PERISH_RATE = (rate == 0 or rate == -.1) and rate or .4
end
function C.ConfigureAnniversary(days)
    C.ANNIVERSARY_DAYS = (days == 35 or days == 140) and days or 70
end
function C.ConfigureSanityRecovery(amount)
    C.SANITY_PER_SECOND = ((amount == 6 or amount == 9) and amount or 3) / 60
end
function C.PerishDescription()
    if C.PERISH_RATE == 0 then return L(1, "永久保鲜") end
    if C.PERISH_RATE < 0 then return L(2, "缓慢返鲜（速度 ×0.10）") end
    return L(3, "腐烂速度 ×0.40")
end
return C
