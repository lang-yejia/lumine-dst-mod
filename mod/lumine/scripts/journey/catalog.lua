local Progress = require("lumine_progression")
local Artifacts = require("lumine_artifact_data")
local Forge = require("lumine_forging_data")

local M = {volumes = {}, by_volume = {}, by_id = {}, by_milestone = {}, milestone_index = {}}
local forge_icon_groups = {
    [1] = {"cookiecutterhat", "armor_lunarplant", "armordreadstone", "armor_voidcloth"},
    [2] = {"dreadstonehat", "horrorfuel", "eyemaskhat", "glasscutter", "lunarplanthat"},
    [3] = {"sword_lunarplant", "purebrilliance", "voidcloth_scythe", "voidclothhat"},
}
M.forge_icons = {}
for suffix, prefabs in pairs(forge_icon_groups) do
    for _, prefab in ipairs(prefabs) do M.forge_icons[prefab] = "images/inventoryimages" .. suffix .. ".xml" end
end
for index, milestone in ipairs(Progress.MILESTONES) do
    M.milestone_index[milestone.id] = index
end
local volume

local function Volume(id, title, groups, subtitle, feature, ink)
    volume = {id = id, title = title, entries = {}, groups = groups, subtitle = subtitle,
        feature = feature, ink = ink}
    M.volumes[#M.volumes + 1] = volume
    M.by_volume[id] = volume
end

local function Add(chapter)
    assert(M.by_id[chapter.id] == nil, chapter.id)
    chapter.volume = volume.title
    chapter.volume_id = volume.id
    chapter.number = #volume.entries + 1
    volume.entries[#volume.entries + 1] = chapter
    M.by_id[chapter.id] = chapter
    for _, id in ipairs(chapter.milestones or {}) do
        assert(M.by_milestone[id] == nil, id)
        M.by_milestone[id] = chapter
    end
end

local function InventoryImage(name, atlas)
    return {atlas = atlas or "images/inventoryimages/" .. name .. ".xml", tex = name .. ".tex"}
end

local function World(id, group, title, intro, body, comment, related, image)
    local milestone = assert(Progress.MILESTONES[M.milestone_index[id]], id)
    Add({
        id = id, title = title, group = group, intro = intro, body = body, comment = comment,
        milestones = {id}, unlock = Progress.EVIDENCE[id] and "evidence" or "explore",
        related = related, image = image or {atlas = milestone.atlas or "images/inventoryimages.xml", tex = milestone.icon},
    })
end

Volume("world", "饥荒世界", {"世界与地区", "生物与生态", "首领与强敌", "奇遇与特殊机制"},
    "从营火到未知的海岸", "deerclops", {.43,.24,.18,1})
World("night", "世界与地区", "地表的第一夜", "日光退到树梢时，第一处营地才算选定。",
    "黄昏前收集草和树枝做火把。若已选好营地，就提前备好木材。沿途找好撤回火边的路线，再决定夜里是否继续赶路。",
    "派蒙负责看火，你负责别把最后一根树枝全花掉！", {"seasons"})
World("cave", "世界与地区", "地下世界的入口", "石洞下方，光源决定这趟旅行能走多远。",
    "下洞前准备备用光源和返程补给。洞里的荧光果能给提灯添燃料，但采集时也要留出回到洞口的光照。若准备深入遗迹，先记住地形分岔。",
    "拐弯太多了，派蒙决定用手册记路，绝不靠回声！", {"ancient_altar"})
World("lunar", "世界与地区", "月岛的另一种光", "熟悉的海水退开，岸上的月光连理智的规则也一起改变。",
    "月岛用启蒙影响旅行者。先辨认岸线与可返航的船位，再往岛内找资源。亲自踏上月岛的岩地后，带一块月岩回来记录。",
    "派蒙刚才盯着石头看了好久，它该不会也在盯着我们吧？", {"alterguardian_phase3", "sail"})
World("sail", "世界与地区", "从海岸扬帆", "海图第一段路，通常就在看得见陆地的地方。",
    "先试船的转向和停靠，再驶离海岸。出远门时带修补材料、照明与食物。隐士小岛适合作为远航目标，海上首领则值得专门留出一艘准备充分的船。",
    "出航前还要数一遍补给，派蒙已经把上船时吃掉的那份算进去了！", {"hermitcrab", "lumine_wing"})
Add({
    id = "seasons", title = "四季的行囊", group = "生物与生态", unlock = "explore",
    intro = "秋天预备下一季，剩下的三个季节轮流考验行囊。",
    body = "秋季可备燃料、存粮与保暖衣物。冬季缩短离开热源的行程。春雨让湿度上升，防雨与干燥处更值钱。盛夏先解决降温和营地防火，再计划长距离外出。",
    comment = "同一个包要塞冬帽、雨伞和降温用品？派蒙先给零食留个位子！",
    image = InventoryImage("winterhat", "images/inventoryimages.xml"),
    milestones = {"winter", "spring", "summer"}, related = {"deerclops", "bearger"},
    seasons = {
        {title = "秋 · 备粮", icon = "berries", text = "趁气候温和勘察营地附近的资源。留下几份燃料与保暖材料，给第一场寒潮准备一条短路线。"},
        {title = "冬 · 保暖", icon = "winterhat", id = "winter", text = "离开热源前检查保暖用品。缩短外出时间，给回到篝火旁的最后一段路留足体温。"},
        {title = "春 · 防雨", icon = "umbrella", id = "spring", text = "带好雨具，观察湿度和温度。准备可以停留的干燥处，巢区附近先看清麋鹿鹅的动静。"},
        {title = "夏 · 降温", icon = "icehat", id = "summer", text = "先准备降温方式和营地防火，再决定白天要走多远。留出回到补给点的时间。"},
    },
})
World("pigking", "生物与生态", "猪村的邻居", "猪人沿着房屋活动，猪王把村落变成旅途中的交易点。",
    "白天可观察猪人出门活动，夜里它们通常回家。满月靠近村落前先观察，猪人可能变成疯猪。找到猪王后，拿可交换的物品换金，交易线路比只记一个金块更值得画在地图上。",
    "派蒙先跟猪王打招呼。等换到金子，我们再回去造点有用的东西！", {"night"},
    InventoryImage("pigskin", "images/inventoryimages.xml"))
World("ancient_altar", "奇遇与特殊机制", "遗迹里的远古祭坛", "铥矿的用途在祭坛前才渐渐清楚。",
    "找到祭坛后，先确认可用的远古配方与携带材料。将探路与制作分开安排，能减少在遗迹里来回走动。继续深入前记住能回到洞口的路。",
    "铥矿有几块，路上还剩多少光？派蒙想先把这两件事写在一起。", {"minotaur", "stalker_atrium"})
World("hermitcrab", "奇遇与特殊机制", "隐士的岛与回信", "一座海上的小屋，也能成为反复回访的地方。",
    "第一次来岛上先找到寄居蟹隐士，再看看附近有哪些可以帮忙的事。把物资和返程留有余量，下次来就能继续照顾这段关系。找到隐士时，手册会记下这次见面。",
    "下次路过也来看看她吧。派蒙想知道上次帮完忙，小岛变成什么样了。", {"sail", "crabking"},
    InventoryImage("messagebottle", "images/inventoryimages2.xml"))
World("deerclops", "首领与强敌", "雪夜里的巨鹿", "听到冬夜里的脚步声，先想好让它在哪儿停下。",
    "把战斗引离脆弱的营地设施，给撤退和保暖留出空间。参与击败后可把眼球暂借派蒙，取回后再决定它的制作去向。",
    "这颗眼睛放进背包时，能不能把它转过去？派蒙总觉得它还睁着！", {"seasons"})
World("bearger", "首领与强敌", "熊獾的秋日脚步", "秋日的觅食者经过，营地和树木都可能遭殃。",
    "留意熊獾经过的地方，把存粮和战场分开。挑一处有撤退空间的场地再交手。参与击败后，用它的厚毛记录这次遭遇。",
    "它找吃的声势比派蒙大多了。幸好这回我们把存粮藏好了！", {"seasons", "lumine_armor"},
    InventoryImage("bearger_fur", "images/inventoryimages.xml"))
World("moose", "首领与强敌", "春水边的麋鹿鹅", "春季的巢附近，一阵拍翅声就值得停下来观察。",
    "接近巢区前带好防雨装备，观察成体与幼崽的活动。挑开阔地站稳，避免被巢边的混战堵住退路。羽毛是交给派蒙的证物。",
    "它看起来像鹅，发起脾气来可一点都不适合叫作小鸟。", {"seasons"},
    InventoryImage("goose_feather", "images/inventoryimages.xml"))
World("klaus", "首领与强敌", "冬林里的克劳斯", "藏在冬林里的战利品袋，会把寻找物资变成一场首领战。",
    "在战利品袋附近作战，要同时留意克劳斯和随行的鹿。带好保暖与恢复物品。手册的钥匙图用来辨认这场战斗，交付时请选择雕像草图。",
    "派蒙本来还期待冬天的礼物。这个袋子，我们还是准备好再打开吧。", {"seasons"},
    InventoryImage("klaussackkey", "images/inventoryimages.xml"))
World("dragonfly", "首领与强敌", "岩浆边的龙蝇", "池边的岩浆幼虫会改变这场战斗的节奏。",
    "认清岩浆池、撤退线路与适合补给的位置。分清幼虫骚扰和龙蝇的暴怒阶段，再安排灭火、降温和恢复。战后保留一枚鳞片用于记录。",
    "派蒙数着池边冒出来的东西，数到一半就只想离岩浆远一点！", {"lumine_armor"})
World("beequeen", "首领与强敌", "蜂后的巢与蜂群", "蜂后带来的压力，往往来自一整群翅膀。",
    "把蜂群的追逐与攻击蜂后的时机分开处理，给移动留空间。蜂王浆可作原版烹饪材料，提交后会返到派蒙背包，派蒙不会自动吃掉这件证物。",
    "蜂王浆先写进手册，再放回背包。放心，派蒙已经记住顺序了！", {"lumine_aranara"},
    InventoryImage("royal_jelly", "images/inventoryimages.xml"))
World("minotaur", "首领与强敌", "迷宫深处的守护者", "狭窄的走廊会让一次冲撞变得难以闪躲。",
    "进入迷宫前备好照明，找出能侧移的位置，避免在死角接战。取得守护者角以后仍要穿过遗迹返程，把最后一份燃料留给回去的路。",
    "派蒙现在看到走廊尽头的角，第一反应就是先往旁边挪两步。", {"ancient_altar"})
World("stalker_atrium", "首领与强敌", "远古织影者", "走过遗迹迷宫后，中庭还有一场关于暗影的长战。",
    "把照明、战斗补给与返程路线都安排妥当，再在中庭迎战。参与击败远古织影者后，把对应雕像草图交给派蒙记录。",
    "回到有光的地方再画那道影子吧，派蒙可不想在中庭多看一眼。", {"ancient_altar"},
    InventoryImage("thurible", "images/inventoryimages.xml"))
World("crabking", "首领与强敌", "海上的帝王蟹", "在海上，脚下的船也是战场的一部分。",
    "出发前检查修补材料，开战后同时留意站位与船体。雕像草图适合留作这趟海战的证物。若还要回访隐士，给返航留一套完整补给。",
    "派蒙在船上还没站稳，你已经开始找下一次出手的机会了！", {"sail", "hermitcrab"},
    InventoryImage("chesspiece_crabking_sketch", "images/inventoryimages1.xml"))
World("alterguardian_phase3", "首领与强敌", "天体英雄的最后一幕", "月岛的见闻通向一场分阶段的长战。",
    "给每一阶段留出不同的恢复时机，别在开场就耗尽补给。战后的碎片本身带容器。交给派蒙前先取出其中的物品，空碎片仍会在记录结束后返还。",
    "这一页从登岛写到最后一战。派蒙得留出整整一页画那片月光！", {"lunar"})

local function Collection(id, group, title, intro, body, comment, related, image, extra)
    local chapter = extra or {}
    chapter.id, chapter.title, chapter.group, chapter.unlock = id, title, group, "collection"
    chapter.intro, chapter.body, chapter.comment = intro, body, comment
    chapter.related, chapter.image = related, image
    Add(chapter)
end

Volume("traveler", "莹的旅程", {"元素系统", "探索能力"},
    "元素共鸣与风之翼", "lumine_statue", {.23,.38,.36,1})
Collection("lumine_energy", "元素系统", "元素之力", "战斗里的微粒和晶球，都是下一次出手的余量。",
    "莹的元素力上限为 100。平时自然恢复，飞行时暂停。攻击普通目标有机会产生微粒，攻击首领有机会产生晶球。靠近即可吸收，可把能量留给技能或风之翼。",
    "派蒙负责提醒你捡小光球，至于要留给护盾还是飞行，你得自己决定。", {"lumine_elements"},
    InventoryImage("lumine_element_particle"))
Collection("lumine_statue", "元素系统", "七天神像", "每座神像只接受一次供奉，随后永久固定一种元素。",
    "建造者供奉元素力后，个人收集按仍存在的不同元素计数。每种增加 20 最大生命、10 最大理智和 10 最大饱食度。学习风、岩或雷后，可在对应神像共鸣，也可回归无元素。",
    "下次路过神像的时候，派蒙想看看你又想选哪一种元素。", {"lumine_elements", "lumine_energy"},
    InventoryImage("lumine_seven_statue-icon"))
Collection("lumine_elements", "元素系统", "风、岩与雷的能力", "风帮你腾出空间，岩帮你守住位置，雷为武器附魔。",
    "风行适合短距离移位，风涡剑可牵引小怪。岩元素用护盾和领域稳住站位。雷元素在交战时加快回能，开启附魔后才能释放雷霆唤星，让接下来的武器命中追加雷电球。",
    "怪围上来时先选站位。派蒙可不想你把最后一点元素力用在原地转圈！", {"lumine_statue", "lumine_wing"},
    InventoryImage("wind-dash", "images/element/wind-dash.xml"))
Collection("lumine_wing", "探索能力", "风之翼与异世探索", "起飞前在地图上找好下一处落脚点。",
    "风之翼展开和飞行都消耗元素力。风共鸣消耗较低，海面消耗更高。落地需要安全地面或船只。过水前先看对岸的位置，长途航行优先准备船。",
    "船在下面的时候再降落！派蒙可没带第二把桨。", {"sail", "lumine_energy"},
    InventoryImage("lumine_wing_skill", "images/element/lumine_wing_skill.xml"))

local function Routes(kinds)
    local routes = {}
    for _, kind in ipairs(kinds) do
        local route = {}
        for _, stage in ipairs(Forge.STAGES) do
            if stage.kind == kind then
                if #route == 0 then route[1] = stage.old end
                route[#route + 1] = stage.new
            end
        end
        routes[#routes + 1] = route
    end
    return routes
end

Volume("treasures", "旅途珍藏", {"武器与护甲", "圣遗物收藏"},
    "重铸装备与收集遗珍", "lumine_relic", {.46,.34,.16,1})
Collection("lumine_sword", "武器与护甲", "旅途中的武器", "从无锋剑到风鹰剑，升级路线沿着原版武器向前走。",
    "用相应阶段的原版武器打出有效攻击，再到合成台登记。登记后武器归还。带着上一阶剑、指定材料和元素力完成重铸，详细要求可在装备见闻查阅。",
    "原版武器用过、登记过，再收起来。派蒙可不想把哪一把留在了战场上。", {"lumine_armor"},
    InventoryImage("lumine_dull_blade"), {routes = Routes({"weapon"})})
Collection("lumine_armor", "武器与护甲", "冒险者的护甲", "同一趟远征，头部与身体的防具各记各的。",
    "穿上对应原版防具承受有效攻击，再用合成台记录使用经历。花冠和护衣分别重铸。先决定下一场战斗更需要哪件防具，再投入材料和元素力。",
    "头上和身上的材料分开放。上次派蒙差点把两份配方抄到同一行。", {"lumine_sword", "dragonfly"},
    InventoryImage("lumine_traveler_head"), {routes = Routes({"head", "body"})})
Collection("lumine_relic", "圣遗物收藏", "圣遗物的秘密", "星辉圣匣收录的是三套遗珍与各自的专长。",
    "装备圣匣参与战斗，可发现掉落的圣遗物。拿起圣遗物，右键随身圣匣即可收录。每个圣匣共享同一份收藏，套装属性和四件专长在装备圣匣时生效。",
    "五件都能写进收藏册，可激活时得挑一套。派蒙先把你想收的那套圈起来。", {"relic_wilson", "relic_wickerbottom", "relic_warly"},
    InventoryImage("lumine_relic_codex"))

local set_copy = {
    wilson = {"试剂量杯和护目镜记录了威尔逊的实验习惯。", "适合关心资源转换的旅行者。基础配方可把手头材料转成另一种物资，制作仍看科技与原版用料。", "派蒙只负责读标签，没贴标签的试剂可别递过来！"},
    wickerbottom = {"书页押花、墨羽笔和茶杯，像刚从书桌上收起来。", "适合愿意准备书籍的旅行者。施放前先确认书籍用途、可用次数和读书代价，带哪一本出门由计划决定。", "这页借书条派蒙替你夹好了，读完别折书角。"},
    warly = {"从香草花束到主厨高帽，每件都像一道菜的准备步骤。", "适合把烹饪当作远行准备的旅行者。便携厨具和调味为同一顿饭提供不同选择，先想好队伍下一程需要什么。", "主厨高帽可以戴，试菜的活也可以交给派蒙！"},
}
for _, set in ipairs(Artifacts.SETS) do
    local copy = set_copy[set.id]
    Collection("relic_" .. set.id, "圣遗物收藏", set.name, copy[1],
        copy[2], copy[3], {"lumine_relic"},
        InventoryImage("lumine_relic_" .. set.id .. "_1"), {relic_set = set.id})
end

Volume("partners", "旅途伙伴", {"派蒙", "兰纳罗小屋"},
    "同行的旅伴与林间小屋", "lumine_aranara", {.32,.39,.22,1})
Collection("lumine_paimon", "派蒙", "派蒙：最好的旅伴", "飞在身边的派蒙，替你留住值得写下来的东西。",
    "派蒙有六格背包，也有自己的饱食度。亲历章节后，手持对应证物请她记录。完成后见闻会写入手册，证物放回背包。背包满时可先腾格子，再取回等待中的证物。",
    "这可是派蒙亲手整理的手册！不过翻到这一页的时候，你也可以给派蒙留点零食。", {"lunar", "lumine_aranara"},
    {anim = "lumine_paimon", clip = "idle", scale = .52})
Collection("lumine_aranara", "兰纳罗小屋", "森林中的小屋", "小屋暖起来时，附近农作物才有了帮手。",
    "把可燃物放进三个燃料格。最多三只兰纳罗会照料小屋周边的作物。冬季和有危险时它们会躲回屋里。给小屋留一片连在一起的农地，收获时再亲自过来。",
    "派蒙听见屋里有动静。等它们出来，我们再看看哪一株先被照顾。", {"seasons"},
    InventoryImage("lumine_aranara_hut-icon"))

function M.Find(id)
    return M.by_id[id] or M.by_milestone[id] or (id == "lumine_alchemy" and M.by_id.lumine_sword)
end

return M
