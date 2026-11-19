-- Reading copy and navigation live outside the UI and reward rules.
-- The original twenty milestone IDs retain their saved bit positions.
local Progress = require("lumine_progression")
local M = {all={}, by_id={}, index_by_id={}, groups={survival={}, places={}, bosses={}, traveler={}}}

local related = {
    night={"winter"}, winter={"deerclops"}, spring={"moose"}, summer={"dragonfly"},
    cave={"ancient_altar"}, sail={"hermitcrab"}, lunar={"alterguardian_phase3"},
    pigking={"lumine_sword"}, ancient_altar={"minotaur"}, hermitcrab={"crabking"},
    deerclops={"winter"}, dragonfly={"lumine_armor"}, minotaur={"ancient_altar"},
    alterguardian_phase3={"lunar"}, bearger={"lumine_armor"}, moose={"spring"},
    beequeen={"lumine_aranara"}, klaus={"winter"}, stalker_atrium={"ancient_altar"},
    crabking={"sail"}, lumine_energy={"lumine_statue"}, lumine_statue={"lumine_energy"},
    lumine_wing={"sail"}, lumine_sword={"lumine_alchemy"},
    lumine_armor={"lumine_alchemy"}, lumine_alchemy={"lumine_sword"},
    lumine_relic={"lumine_sword"}, lumine_aranara={"spring"},
}

local copy = {
    night={"求生与季节", "黑夜会让没有光源的旅行者陷入危险。第一天的目标，是在天黑前准备可靠的照明和燃料。", "火把方便移动，篝火适合停留。走过第一夜之后，记得为下一次远行留出燃料。", "派蒙刚才听见了什么？算了，先别让火灭掉！"},
    winter={"求生与季节", "寒冬会持续消耗体温，也让食物储备变得紧张。进入冬季前准备保暖和稳定的食物来源。", "保暖衣物、热源和出行路线各有用途。冬天的挑战不只是一场首领战。", "派蒙觉得今天适合待在火边……不过你一定又想出门吧？"},
    spring={"求生与季节", "春雨会使装备潮湿，也会影响火源与体温。雨具能让探索更从容。", "准备防雨装备，并观察农作物和生物在春季的变化。", "派蒙的头发都要湿透啦，快找个干燥的地方！"},
    summer={"求生与季节", "盛夏让过热和火灾成为重要风险。降温装备与基地防火同样值得准备。", "出远门前确认身上的降温手段，不要只依赖一次性的补给。", "好热！派蒙希望手册不会被太阳晒着火。"},
    cave={"地区与地标", "洞穴拥有地表没有的资源，也有独立的光照与危险。首次下洞前应准备照明和返程路线。", "远古区域在洞穴深处；旅行手册会把进入洞穴与抵达远古祭坛分别记录。", "这里连天空都看不见……派蒙可得跟紧你。"},
    sail={"地区与地标", "船只让海上群岛成为真正可探索的地区。登船只是出海旅程的第一步。", "检查船体、方向和返航补给。风之翼可以短途移动，不能替代长距离航海。", "派蒙喜欢看海！不过别忘了我们还得回岸上。"},
    lunar={"地区与地标", "月岛的地形、资源和生物与大陆不同。亲自踏上岛屿，才能理解这块月岩从何而来。", "把月岩带给派蒙记录后，原物会放回她的背包，仍可用于原版制作。", "这里和大陆的感觉完全不一样，派蒙要把路记清楚。"},
    pigking={"地区与地标", "猪王与周围村落提供了交易和探索线索。找到他就能完成这一段见闻。", "留意原版交易规则与村落资源，手册不会要求交出猪王或破坏地标。", "这位国王看起来很喜欢礼物。派蒙也喜欢！"},
    ancient_altar={"地区与地标", "远古祭坛连接遗迹探索与远古科技。抵达这里意味着你已经深入洞穴。", "观察可制作的物品与遗迹周边危险，再决定哪些材料值得带回。", "这么古老的东西，派蒙得轻一点翻手册。"},
    hermitcrab={"地区与地标", "隐士的岛屿是海上旅程的一站。找到她的家即可完成此项体验。", "她的请求把海洋资源与长期探索联系起来，值得多次造访。", "她一个人住在这里？派蒙想再来看看她。"},
    deerclops={"生物与首领", "巨鹿在冬季给基地与旅行者带来战斗考验。参与战斗后，带它的眼球给派蒙记录。", "眼球也是原版制作的重要材料。派蒙记录后会将原物返还，不妨继续体验它的用途。", "它的脚步声派蒙到现在都记得！这颗眼球可得好好保管。"},
    dragonfly={"生物与首领", "龙蝇是高强度战斗目标。充分准备场地、装备与恢复，再参与挑战。", "鳞片有原版装备用途。交给派蒙只是暂借，不会消耗这份战利品。", "那么大的翅膀……派蒙才不要和它比飞行！"},
    minotaur={"生物与首领", "远古守护者位于遗迹深处。它的牛角象征一次完整的地下远征。", "取得战利品后仍要安全返回；派蒙记录不会取代遗迹科技的原版体验。", "派蒙一想到刚才的冲撞，手都在抖。"},
    alterguardian_phase3={"生物与首领", "天体英雄连接月岛与更深的月亮探索。获得战利品前需要经历较长的原版路线。", "这章奖励较高，但只结算一次；派蒙记录后仍会返还物品。", "我们真的走到这里了？派蒙要把每一步都写下来！"},
    bearger={"生物与首领", "熊獾让秋季的资源准备与战斗相遇。参与击败后，可带厚毛给派蒙。", "厚毛仍能用于原版制作；记录过程只暂时保管。", "它差点把派蒙的午饭都吓掉了！"},
    moose={"生物与首领", "麋鹿鹅是春季的强大生物。观察它的行动并准备好战斗补给。", "羽毛是春季战斗留下的证物，也能继续用于原版物品。", "派蒙原以为它只是一只很大的鸟……"},
    beequeen={"生物与首领", "蜂后和蜂群考验走位与持续作战。参与击败后，把蜂王浆交给派蒙。", "蜂王浆可食用，派蒙会把它作为证物保护，不会自动吃掉。", "这次派蒙真的不会偷吃，至少记录完之前不会！"},
    klaus={"生物与首领", "克劳斯让冬季探索出现另一条首领路线。击败后可取得对应雕像草图。", "草图代表这场战斗；派蒙记录后会把它放回背包。", "这位可不像会送礼物的好人。还是快把战斗写下来吧。"},
    stalker_atrium={"生物与首领", "远古织影者是遗迹深处的挑战。参与击败后，用它的雕像草图作为记录证物。", "暗影战斗与远古探索紧密相连；这张草图仍会原样返还。", "派蒙不想再看见那些影子了……但这页必须写完。"},
    crabking={"生物与首领", "帝王蟹要求玩家认真准备海上的战斗环境。参与击败后带回雕像草图。", "它的战利品与海洋探索相连；记录后仍可继续使用。", "派蒙在船上站都站不稳，你居然还和它打起来了！"},
}

local group_ids = { ["求生与季节"]="survival", ["地区与地标"]="places", ["生物与首领"]="bosses" }
for _, milestone in ipairs(Progress.MILESTONES) do
    local detail = assert(copy[milestone.id], "Missing journey chapter " .. milestone.id)
    local chapter = {
        id=milestone.id, source="vanilla", group=group_ids[detail[1]], title=milestone.name,
        image={atlas=milestone.atlas or "images/inventoryimages.xml", tex=milestone.icon},
        teaser=milestone.hint, summary=detail[2], body={detail[2],detail[3]},
        paimon={complete=detail[4]}, reward=milestone.reward,
        evidence=Progress.EVIDENCE[milestone.id],
        related=related[milestone.id],
    }
    M.all[#M.all+1]=chapter
    M.by_id[chapter.id]=chapter
    M.index_by_id[chapter.id]=#M.all
    M.groups[chapter.group][#M.groups[chapter.group]+1]=chapter
end

local mod_entries = {
    {"lumine_energy", "元素力", "系统", "lumine_element_particle", "白色元素微粒补充元素力；神像共鸣决定图标与颜色。", "攻击怪物会有机会得到微粒，首领战则可能出现晶球。元素力自然恢复，但主动技能与风之翼会消耗它。", "派蒙看到小光球就想追，不过你更需要它来放技能。"},
    {"lumine_statue", "七天神像", "建筑", "lumine_seven_statue-icon", "供奉风或岩元素力后，可以在神像处切换共鸣。", "莹也可以回到无元素状态。神像提供选择，元素力数值仍遵循统一的上限和恢复规则。", "每次站在神像前，派蒙都觉得旅途又要开始了！"},
    {"lumine_wing", "风之翼", "探险技能", "lumine_wing_skill", "风之翼用于短途飞行，消耗元素力展开并持续飞行。", "风元素的飞行消耗较低，其他状态较高；海上飞行代价更大。它帮助跨越短距离，却不能替代原版航海。", "飞起来的时候记得看好落脚处，派蒙可不想掉进海里。"},
    {"lumine_sword", "旅行者的剑", "装备", "lumine_dull_blade", "从无锋剑出发，用亲自使用过的原版武器留下装备见闻。", "在合成台完成记录，再将见闻用于上一阶段武器的重铸。原版装备被登记后归还，继续保留其特殊用途。", "同一把剑也会记住我们走过的路吗？"},
    {"lumine_armor", "旅者的防护", "装备", "lumine_traveler_head", "旅者花冠与护衣沿用逐阶重铸的成长方式。", "头部与身体分别收集原版防具的使用经历。新的外观不应盖过原版防具的用途，战斗前仍要按场景选择。", "派蒙希望这套衣服既好看又真的能保护你。"},
    {"lumine_alchemy", "合成台", "建筑", "alchemy_table", "合成台把原版装备的使用经历整理为旅行的见闻。", "记录不会吞掉原版装备；更高阶段的重铸还要准备对应材料和元素力。", "派蒙负责记下来，你负责把材料摆整齐！"},
    {"lumine_relic", "星辉圣匣", "收集", "lumine_relic_codex", "装备星辉圣匣后可以打开圣遗物收藏页。", "三名原版角色各有五件圣遗物；收集四件可开启对应能力，一次只激活一套。第五件继续提供小幅属性。", "花、羽、沙漏、杯、冠……派蒙要一件一件数清楚。"},
    {"lumine_aranara", "兰纳罗小屋", "建筑", "lumine_aranara_hut-icon", "小屋消耗可燃物，换取兰纳罗照料附近作物的活动时间。", "小屋可容纳三格燃料、最多三只兰纳罗；冬季不出门，危险接近时会回屋。它们照料农场，不替玩家收获。", "它们的头比身体还大！派蒙觉得我们一定能成为朋友。"},
}
local icon_atlas = {
    lumine_wing_skill="images/element/lumine_wing_skill.xml",
}
for _, row in ipairs(mod_entries) do
    local id,title,kind,icon,summary,body,comment = unpack(row)
    local atlas = icon_atlas[icon] or "images/inventoryimages/"..icon..".xml"
    local chapter = {
        id=id, source="mod", group="traveler", kind=kind, title=title,
        image={atlas=atlas, tex=icon..".tex"}, teaser=summary,
        summary=summary, body={summary,body}, paimon={complete=comment}, reward=0,
        related=related[id],
    }
    M.all[#M.all+1]=chapter
    M.by_id[id]=chapter
    M.groups.traveler[#M.groups.traveler+1]=chapter
end

for _, chapter in ipairs(M.all) do
    for _, id in ipairs(chapter.related or {}) do
        assert(M.by_id[id] ~= nil, "Unknown related chapter " .. id)
    end
end

return M
