-- Shared, ordered data for server progress and the client journal.
local M = {}

M.MILESTONES = {
    {id="night", name="第一夜", hint="亲自度过一夜。", reward=1, icon="torch.tex"},
    {id="winter", name="寒冬", hint="在冬季继续旅行。", reward=2, icon="winterhat.tex"},
    {id="spring", name="雨季", hint="经历春季的降雨。", reward=2, icon="umbrella.tex"},
    {id="summer", name="盛夏", hint="经历炎热的夏季。", reward=2, icon="icehat.tex"},
    {id="cave", name="地下世界", hint="进入洞穴。", reward=2, icon="lantern.tex"},
    {id="sail", name="扬帆出海", hint="登上船只。", reward=2, atlas="images/inventoryimages1.xml", icon="boat_item.tex"},
    {id="lunar", name="月岛", hint="踏上月岛的岩地。", reward=3, icon="moonrocknugget.tex"},
    {id="pigking", name="猪王领地", hint="找到猪王，探索交易与村落。", reward=1, icon="goldnugget.tex", landmark="pigking"},
    {id="ancient_altar", name="远古祭坛", hint="找到遗迹中的远古祭坛。", reward=1, icon="thulecite.tex", landmark="ancient_altar"},
    {id="hermitcrab", name="隐士之家", hint="找到寄居蟹隐士的海岛。", reward=1, icon="fish.tex", landmark="hermitcrab"},
    {id="deerclops", name="巨鹿", hint="参与击败巨鹿。", reward=3, icon="deerclops_eyeball.tex", boss=true},
    {id="dragonfly", name="龙蝇", hint="参与击败龙蝇。", reward=3, icon="dragon_scales.tex", boss=true},
    {id="minotaur", name="远古守护者", hint="参与击败洞穴守护者。", reward=4, icon="minotaurhorn.tex", boss=true},
    {id="alterguardian_phase3", name="天体英雄", hint="参与击败天体英雄。", reward=5, atlas="images/inventoryimages1.xml", icon="alterguardianhatshard.tex", boss=true},
    {id="bearger", name="秋季巨熊", hint="参与击败熊獾，体验秋季首领战。", reward=1, icon="meat.tex", boss=true},
    {id="moose", name="春季麋鹿鹅", hint="参与击败麋鹿鹅，体验春季首领战。", reward=1, icon="drumstick.tex", boss=true},
    {id="beequeen", name="蜂后", hint="参与击败蜂后，挑战蜂群战斗。", reward=1, icon="honey.tex", boss=true},
    {id="klaus", name="克劳斯", hint="参与击败克劳斯，挑战冬季首领战。", reward=1, icon="gears.tex", boss=true},
    {id="stalker_atrium", name="远古织影者", hint="参与击败远古织影者，完成遗迹挑战。", reward=2, icon="nightmarefuel.tex", boss=true},
    {id="crabking", name="帝王蟹", hint="参与击败帝王蟹，完成海上挑战。", reward=2, icon="rocks.tex", boss=true},
}

-- Evidence is returned after Paimon records it. A witnessed event is also
-- required, so traded materials alone cannot skip exploration or boss fights.
M.EVIDENCE = {
    lunar="moonrocknugget",
    deerclops="deerclops_eyeball", dragonfly="dragon_scales", minotaur="minotaurhorn",
    alterguardian_phase3="alterguardianhatshard", bearger="bearger_fur",
    moose="goose_feather", beequeen="royal_jelly",
    klaus="chesspiece_klaus_sketch", stalker_atrium="chesspiece_stalker_sketch",
    crabking="chesspiece_crabking_sketch",
}
M.EXPERIENCE = {}
M.RECORD = {}
M.BY_EVIDENCE = {}
for index, milestone in ipairs(M.MILESTONES) do
    local evidence = M.EVIDENCE[milestone.id]
    local group = evidence and M.RECORD or M.EXPERIENCE
    group[#group + 1] = {index=index, milestone=milestone}
    if evidence then
        local prefabs = type(evidence) == "table" and evidence or {evidence}
        for _, prefab in ipairs(prefabs) do
            local matches = M.BY_EVIDENCE[prefab] or {}
            matches[#matches + 1] = milestone.id
            M.BY_EVIDENCE[prefab] = matches
        end
    end
end
M.CHAPTERS = {
    night="黑夜是恒常大陆最早的考验。点起火把，留意燃料与光照，旅程才刚开始。",
    winter="寒冬让食物和温度都成为问题。保暖衣物是探索冬季生态的起点。",
    spring="春雨会淋湿装备与燃料。准备雨具，观察潮湿如何改变生存节奏。",
    summer="盛夏考验降温与防火。尝试原版降温装备，再规划远行。",
    cave="地下有新的资源、光照风险和远古遗迹。亲自进入就能留下这段见闻。",
    sail="船只把旅程延伸到海面。风之翼只能短途移动，远航仍需认真造船。",
    lunar="月岛有独特地形与材料。先亲自踏上月岛，再带回一块月岩。",
    pigking="猪王与附近村落提供交易线索。亲自找到猪王即可记录。",
    ancient_altar="远古祭坛连接遗迹科技。亲自到达祭坛即可记录。",
    hermitcrab="隐士的小岛鼓励玩家了解海洋。找到她的家即可记录。",
    deerclops="巨鹿提醒旅行者准备冬季战斗。它的眼球也是原版装备的重要材料。",
    dragonfly="龙蝇的鳞片能制成原版护甲。记录战斗后，继续体验它的用途。",
    minotaur="远古守护者位于遗迹深处。牛角是完成地下探索的证明。",
    alterguardian_phase3="天体英雄串起月岛与月亮剧情。记录它的战利品，回顾漫长旅程。",
    bearger="熊獾让秋季资源准备变得重要。厚毛也有实用的原版制作价值。",
    moose="麋鹿鹅体现春季首领的节奏。羽毛可继续用于原版物品。",
    beequeen="蜂后战斗考验准备与走位。蜂王浆也有原版烹饪价值。",
    klaus="克劳斯让冬季探索更有目标。将战斗后得到的雕像草图交给派蒙记录。",
    stalker_atrium="远古织影者是遗迹深层挑战。将雕像草图交给派蒙，留下暗影旅程的一页。",
    crabking="帝王蟹需要海上准备与耐心。将它的雕像草图交给派蒙记录这场海战。",
}

M.BOSS_MILESTONES = {}
M.LANDMARK_MILESTONES = {}
for _, milestone in ipairs(M.MILESTONES) do
    if milestone.boss then M.BOSS_MILESTONES[milestone.id] = true end
    if milestone.landmark then M.LANDMARK_MILESTONES[milestone.landmark] = milestone.id end
end

M.SKILLS = {
    {id="rations", branch="求生", name="旅行口粮", hint="饥饿消耗降低 10%。", cost=2, icon="berries.tex"},
    {id="ward", branch="求生", name="旅途防护", hint="受到的伤害降低 6%。", cost=4, requires="rations", icon="armorwood.tex"},
    {id="swift", branch="远行", name="轻盈步伐", hint="陆上移动速度提高 7%。", cost=3, icon="cane.tex"},
    {id="rainproof", branch="远行", name="风雨同行", hint="额外获得 20% 防雨效果。", cost=4, requires="swift", icon="umbrella.tex"},
    {id="swordmaster", branch="剑术", name="熟练剑士", hint="本模组的剑造成 8% 额外伤害。", cost=3, icon="spear.tex"},
    {id="resolve", branch="剑术", name="战后振奋", hint="击败较强敌人时恢复 4 理智；20 秒冷却。", cost=5, requires="swordmaster", icon="nightmarefuel.tex"},
}

M.ELEMENT_SKILLS = {
    {id="wind_swift", element="风", name="顺风而行", hint="陆上移动速度提高 5%，可与轻盈步伐相加。", atlas="images/element/wind-passive.xml", icon="wind-passive.tex"},
    {id="wind_dash", element="风", name="风行", hint="最多冲刺 5 个世界单位，消耗 20 元素力，冷却 6 秒。冲刺期间可闪避攻击。", atlas="images/element/wind-dash.xml", icon="wind-dash.tex"},
    {id="wind_tornado", element="风", name="风涡剑", hint="挥击释放推进的龙卷风，大怪会挡住它，小怪会被牵引。消耗 35 元素力，冷却 35 秒。", atlas="images/element/wind-tornado.xml", icon="wind-tornado.tex"},
    {id="geo_resolve", element="岩", name="磐岩之心", hint="常驻减伤 8%，可与旅途防护叠加。", atlas="images/element/geo-passive.xml", icon="geo-passive.tex"},
    {id="geo_shield", element="岩", name="星岩护佑", hint="金岩护盾最多吸收 100 点战斗伤害（含位面伤害），持续 6 秒；冷却 35 秒。", atlas="images/element/geo-shield.xml", icon="geo-shield.tex"},
    {id="geo_field", element="岩", name="岩域共鸣", hint="10 秒领域：增伤 15%、减伤 12%、抗控制。", atlas="images/element/geo-field.xml", icon="geo-field.tex"},
    {id="electro_regen", element="雷", name="雷息回流", hint="命中或受击后 6 秒内，基础元素力恢复提高 50%。", atlas="images/element/electro-passive.xml", icon="electro-passive.tex"},
    {id="electro_infusion", element="雷", name="雷元素附魔", hint="武器附带原版电属性，每秒消耗 5.5 点元素力，可随时关闭。", atlas="images/element/electro-infusion.xml", icon="electro-infusion.tex"},
    {id="electro_burst", element="雷", name="雷霆唤星", hint="附魔时可释放。强化 5 秒，命中追加弹射雷球，每颗耗能 2 点。", atlas="images/element/electro-burst.xml", icon="electro-burst.tex"},
    {id="dendro_guard", element="草", name="荆棘援护", hint="旅行者武器命中敌人，25% 概率召唤亮茄藤蔓。", atlas="images/element/dendro-passive.xml", icon="dendro-passive.tex"},
    {id="dendro_root", element="草", name="藤蔓缠绕", hint="扇形缠根，减速 35%。下次有效受击会留下孢子球。", atlas="images/element/dendro-root.xml", icon="dendro-root.tex"},
    {id="dendro_field", element="草", name="孢子领域", hint="原地形成 10 秒孢子领域，敌人中毒后持续失去生命。", atlas="images/element/dendro-field.xml", icon="dendro-field.tex"},
    {id="hydro_drop", element="水", name="清澈之水", hint="旅行者剑命中有几率生成水滴。触碰水滴以 5 饱食度换取 15 生命。", atlas="images/element/hydro-passive.xml", icon="hydro-passive.tex"},
    {id="hydro_stream", element="水", name="水纹剑", hint="朝鼠标或面朝方向挥出水流，穿过敌人并造成短暂潮湿。", atlas="images/element/hydro-stream.xml", icon="hydro-stream.tex"},
    {id="hydro_bubble", element="水", name="涨潮之水", hint="放出可以受击的水泡，吸引敌人，周期攻击并在结束时爆裂。", atlas="images/element/hydro-bubble.xml", icon="hydro-bubble.tex"},
    {id="pyro_heart", element="火", name="炽热之心", hint="武器和元素伤害提高 10%，对被流火之刃灼烧的敌人改为提高 25%。", atlas="images/element/pyro-passive.xml", icon="pyro-passive.tex"},
    {id="pyro_ring", element="火", name="流火之刃", hint="随身火环使敌人灼烧 4 秒。爆炎时改为发射火焰球，长按可加速连发。", atlas="images/element/pyro-ring.xml", icon="pyro-ring.tex"},
    {id="pyro_burst", element="火", name="爆炎状态", hint="饱食和持续理智消耗提高到 1.5 倍。再次操作或元素力不足 7 点时退出。", atlas="images/element/pyro-burst.xml", icon="pyro-burst.tex"},
    {id="cryo_guard", element="冰", name="寒冰护体", hint="冰盾抵消一次攻击，破裂后 20 秒恢复。击碎冻结目标时，当前攻击伤害翻倍。", atlas="images/element/cryo-passive.xml", icon="cryo-passive.tex"},
    {id="cryo_infusion", element="冰", name="霜刃附魔", hint="为当前旅行者剑附魔，接下来四次有效攻击产生冰柱。换下武器结束附魔。", atlas="images/element/cryo-infusion.xml", icon="cryo-infusion.tex"},
    {id="cryo_meteor", element="冰", name="极寒冰陨", hint="向落点投出冰锥并留下 8 秒领域。身处领域时，旅行者剑命中自动产生冰柱。", atlas="images/element/cryo-meteor.xml", icon="cryo-meteor.tex"},
}

return M
