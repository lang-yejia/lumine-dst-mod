local function Step(id, title, image, text, items, boss)
    return {id=id, title=title, image=image, text=text, items=items, boss=boss}
end

return {
    lunar = {
        title = "月亮路线",
        intro = "从三座祭坛到隐士岛，跟随瓦格斯塔夫调查月亮裂隙。",
        image = "alterguardian_phase1",
        stages = {
            {title="三座祭坛", lanes={
                {title="月岛", steps={
                    Step("find_island","找到月岛","moon_altar","驾船寻找有月岩和天体裂隙的岛屿。记下三处能围成三角的裂隙，再挖开三座诱人的地形构造。"),
                    Step("altar","拼装天体祭坛","moon_altar","把三件重物运到同一裂隙，依次安装底座、宝球、神像。其余两处裂隙留给圣所和贡品。",{{"moon_altar_glass",1},{"moon_altar_seed",1},{"moon_altar_idol",1}}),
                }},
                {title="档案馆", steps={
                    Step("detector","星象探测仪","archive_orchestrina_main","下洞进入远古档案馆，以彩虹宝石启动档案馆能源，完成远古乐谱的知识谜题并解读对应知识，学会探测仪。",{{"opalpreciousgem",1},{"moonrocknugget",1},{"thulecite",1}}),
                    Step("sanctum","天体圣所碎片","moon_altar_astral","在大陆反复放置探测仪并顺指向移动。靠近埋藏点时可掘出重物。把圣所图标和守卫运到月岛第二处裂隙，先放图标，再装守卫。",{{"archive_resonator_item",1},{"moon_altar_icon",1},{"moon_altar_ward",1}}),
                }},
                {title="隐士与帝王蟹", steps={
                    Step("pearl","取得珍珠之泪","hermitcrab","到隐士岛帮珍珠修屋、照料花与蜂箱或完成赠礼等不同任务。累计十项好感任务后领取珍珠之泪；用空瓶在商店换打捞等航海蓝图。",{{"hermit_pearl",1},{"messagebottleempty"}}),
                    Step("tribute","打捞天体贡品","crabking","备夹夹绞盘与船补丁。给帝王蟹嵌珍珠之泪和八枚宝石，击败后打捞沉底的天体贡品，运到第三处裂隙。",{{"hermit_pearl",1},{"purplegem",8,"其余八槽可混搭宝石"},{"winch",1},{"moon_altar_crown",1}},"crabking"),
                }},
            }},
            {title="月亮风暴与天体英雄", lanes={
                {title="三祭坛合流", steps={
                    Step("triangle","让三座祭坛共鸣","moon_altar_link","在同一组邻近且能围成三角的裂隙完成三座祭坛。看到中央神秘能量，等大陆出现月亮风暴。大陆的可疑月岩可挖出天体宝球，留到最后安装。",{{"moonrockseed",1}}),
                    Step("wagstaff","保护风暴中的实验","moonstorm_glass","进入地图标出的风暴，跟随瓦格斯塔夫。留意他要的实验工具，在附近寻找并递给他，同时保护实验设备。完成可取蓝图和收集受控静电。",{{"moonstorm_goggleshat",1},{"moonstorm_static_item",1},{"blueprint",1,"未完成实验蓝图"}}),
                    Step("siphon","建立未完成实验","moon_device_construction1","读蓝图，在三祭坛中央的神秘能量处建造实验。废料可从拾荒设施及相关战斗获得，月熠来自风暴。",{{"wagpunk_bits",4},{"moonstorm_spark",5},{"transistor",2}}),
                    Step("upgrade","升级实验","moon_device_construction2","在实验的建造栏放入废料、月熠和充能月亮碎片，把设备推进到接近完成。",{{"wagpunk_bits",4},{"moonstorm_spark",10},{"moonglass_charged",10}}),
                    Step("champion","完成虹吸器，召唤天体英雄","alterguardian_phase1","提前穿好防具。放入受控静电、充能月亮碎片和天体宝球，虹吸器完成并触发三阶段首领。战后开采遗留物。",{{"moonstorm_static_item",1},{"moonglass_charged",20},{"moonrockseed",1}},"alterguardian_phase3"),
                }},
            }},
            {title="开启裂隙与海岛工程", lanes={
                {title="主线前置", steps={
                    Step("rift","用启迪碎片开启月亮裂隙","lunarrift_portal","击败天体英雄后，瓦格斯塔夫会在遗留物旁做实验。带一枚启迪碎片靠近，按提示打开建造栏投入。若他已离开，就在地表找移走的实验。",{{"alterguardianhatshard",1}}),
                    Step("mutations","击败三种月亮变异首领","mutateddeerclops","裂隙开启后，分别让月能附身普通巨鹿、熊獾和座狼的尸体，击败三种变异。完成后等瓦格斯塔夫交付安全脉冲容器，推进隐士岛任务。",{{"security_pulse_cage"}},"mutateddeerclops"),
                }},
                {title="可提前测绘", steps={
                    Step("map","绘制包含月亮码头的地图","mapscroll","探索月亮码头的猴岛中心区域。用制图桌、羽毛笔与莎草纸记录地图，保存一份实际覆盖猴岛的地图卷。",{{"featherpencil",1},{"papyrus",1},{"mapscroll",1}}),
                }},
            }},
            {title="瓦器人首次挑战", lanes={
                {title="前置合流", steps={
                    Step("relocate","帮助珍珠搬迁","hermitcrab","用岛上的工作站见瓦格斯塔夫，交给他覆盖猴岛的地图，再把他给的地图交给珍珠。等她完成搬迁，回到原隐士岛找工作站。",{{"mapscroll",1}}),
                    Step("floor","铺满基底扩展器","wagpunk_floor_kit","在工作站制作扩展器，每组产出四个。按隐士岛周围的海面标记铺满 76 格，使中央构造体出现并解锁捕获器。",{{"wagpunk_floor_kit",76},{"cutstone",19},{"wagpunk_bits",19}}),
                    Step("cages","交付六个已装填的捕获器","gestalt_cage","用幻灵捕获器收纳普通幻灵、高阶幻灵或月亮食草兽。首次向瓦格斯塔夫交六只，地面与飞行类至少各一只。额外保留一个空捕获器。",{{"gestalt_cage",7},{"thulecitebugnet",7},{"wagpunk_bits",14}}),
                    Step("revenant","击败并收纳天体仇灵","alterguardian_phase1_lunarrift","交第六只后准备接战。击败天体仇灵，用空捕获器收取留下的幻灵，然后交给岛上的瓦格斯塔夫。",{{"gestalt_cage",1}},"alterguardian_phase1_lunarrift"),
                    Step("robot","拉选择器挑战瓦器人","wagboss_robot","交付仇灵后，操作机体旁的选择器。进入场地应对瓦器人的导弹、冲击与光束，留一套防具给下一场。",nil,"wagboss_robot"),
                    Step("scion","迎战天体后裔","alterguardian_phase4_lunarrift","瓦器人之后继续在岛上作战。击败从机体剧情中登场的天体后裔，领取材料并解锁瓦器人复战配方。",nil,"alterguardian_phase4_lunarrift"),
                }},
            }},
            {title="天体后裔之后的复战", lanes={
                {title="重建机体", steps={
                    Step("base","制作底座与三个部件","wagboss_robot_constructionsite_kit","在原隐士岛标记处放置底座，用三份瓦器人部件完成建造。配方由天体后裔首杀后的工作站提供。",{{"wagboss_robot_constructionsite_kit",1},{"wagboss_robot_creation_parts",3},{"cutstone",5},{"boards",2},{"wagpunk_bits",7}}),
                    Step("replay","重新捕获并启动","wagboss_robot","把六只已捕获幻灵放到机体周围标记处，复战可全用同类。再战天体仇灵，用空捕获器收纳并装进机体，拉选择器开战，随后应对天体后裔。",{{"gestalt_cage",7}},"wagboss_robot"),
                }},
            }},
        },
    },
    shadow = {
        title = "暗影路线",
        intro = "穿过遗迹与圣所，完成中庭的暗影仪式。",
        image = "charlie_boss",
        stages = {
            {title="织影者的三个前置", lanes={
                {title="迷宫与中庭", steps={
                    Step("key","取得远古钥匙","minotaur","进洞后沿苔藓地带进入遗迹，再穿过迷宫。击败远古守护者，拾取远古钥匙。",{{"atrium_key",1}},"minotaur"),
                    Step("gate","定位暗影中庭","atrium_gate","寻找连接暗影中庭的大触手，击倒触手后钻入其洞口。确认出口、远古大门和周围可用的战场。"),
                }},
                {title="洞穴搜集", steps={
                    Step("fossils","收集化石碎片","fossil_piece","在洞穴采掘含化石的石笋等来源，集齐八块。一块用于放骨架底部，其余七块用于拼接。",{{"fossil_piece",8}}),
                }},
                {title="地表新月", steps={
                    Step("atrium","取得暗影中庭","shadow_knight","准备骑士、主教与战车三座可敲碎的雕像，新月夜敲开并应战。最后的三阶棋子掉落暗影中庭。",{{"shadowheart",1}},"shadow_knight"),
                }},
            }},
            {title="织影者与裂隙", lanes={
                {title="前置合流", steps={
                    Step("weaver","召唤远古织影者","stalker_atrium","先把远古钥匙插进大门。带着暗影中庭在门前搭八块化石，确保骨架成形正确；等夜间把普通暗影中庭插入。击败后带走暗影香炉。",{{"atrium_key",1},{"fossil_piece",8},{"shadowheart",1},{"thurible",1,"击败后拾取"}},"stalker_atrium"),
                    Step("repair","召唤之手与暗影裂隙","atrium_gate","击败织影者后回到远古大门附近，向第一只召唤之手交五块绝望石。查理修复大门并开启洞穴暗影裂隙。绝望石可先从梦魇疯猪处准备。",{{"dreadstone",5}}),
                }},
                {title="可并行准备", steps={
                    Step("sanctum_key","圣所试炼与钥石","vault_pillar_guard","开启档案馆开关，从圣所前厅走路标，借路标罗盘找钥石房。给四个基座各送一个安全脉冲，击败守卫塔。拉杆取四只发光象鼻虫填槽，再从圣物箱取钥石。",{{"vault_key",1},{"vault_compass",1}},"vault_pillar_guard"),
                }},
            }},
            {title="启动大门仪式", lanes={
                {title="裂隙与钥石合流", steps={
                    Step("ritual","向第二只召唤之手交钥石","atrium_gate","把钥石带到修复后的大门。如果门上没有远古钥匙，还要交一把远古钥匙。查理开启三处祭品圆圈，并提供被附身的暗影中庭。",{{"vault_key",1},{"atrium_key",1,"大门尚未插钥匙时"},{"shadowheart_infused",1,"仪式获得"}}),
                    Step("friend","召唤友方织影者","stalker_atrium","到中庭外的洞穴用八块化石搭骨架，夜间插入被附身的暗影中庭。手持加过噩梦燃料的暗影香炉引它接近活目标。丢失中庭可让遗迹暴躁箱吞下普通中庭后击败它。",{{"fossil_piece",8},{"shadowheart_infused",1},{"thurible",1},{"nightmarefuel"}}),
                }},
            }},
            {title="三种祭品，可任选先后", lanes={
                {title="蝠鲼洞", steps={
                    Step("larynx","枯萎喉头","bat_boss_shadow","去洞穴的蝠鲼洞找猎犬蝠鲼。引友方织影者靠近并腐化活体，击败变种，拾取一件喉头。",{{"atrium_ritual_organ_bat",1}},"bat_boss_shadow"),
                }},
                {title="岩石地带", steps={
                    Step("claw","枯萎钳爪","rocky_boss_shadow","在洞穴岩石地带找岩石大师。让友方织影者腐化后击败，拾取一件钳爪。",{{"atrium_ritual_organ_rocky",1}},"rocky_boss_shadow"),
                }},
                {title="蠕虫袭击", steps={
                    Step("guts","枯萎内脏","worm_boss_shadow","在洞穴等待巨大洞穴蠕虫来袭。让友方织影者腐化活体再迎战，拾取一件内脏。",{{"atrium_ritual_organ_worm",1}},"worm_boss_shadow"),
                }},
            }},
            {title="暗影女王与暗影憎恶", lanes={
                {title="三种祭品合流", steps={
                    Step("queen","摆放三祭品，挑战暗影女王","charlie_boss","在大门边三个圆圈分别丢下一件不同器官。确认祭品悬浮、仪式推进，准备打女王。留好下一场的护甲与治疗。",{{"atrium_ritual_organ_bat",1},{"atrium_ritual_organ_rocky",1},{"atrium_ritual_organ_worm",1}},"charlie_boss"),
                    Step("abomination","进入暗影憎恶场地","shrouden","女王阶段结束后，经裂隙入口追击暗影憎恶。击败后踩下残留眼睛结束战斗，从场中央返回中庭领取奖励。",{{"king_cane"},{"queen_torch"},{"mask_charlie_bosshat"}},"shrouden"),
                    Step("shadow_replay","复战与重置","atrium_gate","通关后再次击败织影者，可随遗迹重置重开圣所钥石路线。等大门冷却，再准备三种器官。也可用完全腐化的国王权杖腐化目标。",{{"vault_key",1},{"king_cane"}}),
                }},
            }},
        },
    },
}
