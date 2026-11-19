# 第六阶段探索指南核对记录

本机客户端日志记录版本 **762172**，Steam 安装 build ID **26474873**。该版本含 Cursed Confrontation Part 2。以本地脚本为条件、道具和素材的直接依据。 [Klei 版本记录](https://kleiforums.com/forums/topic/173971-game-update-762172/) · [暗影章节发布说明](https://kleiforums.com/game-updates/dst/759423-r2818/)

## 收录口径

逐项比对 `screens/redux/scrapbookdata.lua` 的 `giant` 分类、`prefabs` 的 `epic` 标签及实际世界生成。双子魔眼、暗影棋子和天体英雄的多阶段共用攻略页。小座狼、钢羊、海象、普通猎犬蝠鲼与岩石大师、裂隙精英等按各自身份列出。普通重复刷新的生物只在特定攻略中作为机制或材料来源出现。仅存在于熔炉等活动规则集的敌人未列入标准生存目录。首领召唤的小怪与同一战斗的动画状态并入对应攻略。

首领与精英的完整收录清单和运行时图集路径见[原版图片映射](journey-native-art.md)。图鉴原生路径来自 `scrapbookscreen.lua` 和 `simutil.lua`。核对了三套剪贴簿 atlas 与 TEX、原版库存 atlas，以及生物 prefab 的动画引用。首领页使用静态原版图像。四季用原版冬帽索引，天体英雄沿用原版图鉴第一形态封面。虹吸器阶段沿用游戏自身 `scrapbook_proxy = "moon_device"` 的共用图元，实验蓝图使用原版蓝图通用图标。

## 条件与数量的本机依据

| 流程 | 主要脚本 |
| --- | --- |
| 季节预警、巨兽重生、区域首领 | `components/hounded.lua`、`prefabs/antlion.lua`、`prefabs/dragonfly_spawner.lua`、`prefabs/beequeenhive.lua`、`tuning.lua` |
| 海上首领、鱼群与冰钓 | `prefabs/crabking.lua`、`stategraphs/SGcrabking.lua`、`components/malbatrossspawner.lua`、`components/sharkboimanager.lua` |
| 疯猪与两种形态 | `prefabs/daywalker_pillar.lua`、`components/shard_daywalkerspawner.lua`、`prefabs/junk_pile_big.lua` |
| 月岛三祭坛、风暴与虹吸器 | `prefabs/moon_altar.lua`、`prefabs/moon_altar_pieces.lua`、`components/moonstormmanager.lua`、`prefabs/wagstaff_npc.lua`、`prefabs/moon_device.lua`、`recipes.lua` |
| 月亮变异、瓦器人与两种后续战 | `components/lunarriftmutationsmanager.lua`、`components/wagpunk_arena_manager.lua`、`prefabs/gestalt_cage.lua`、`prefabs/wagboss_robot_constructionsite.lua`、`prefabs/alterguardian_phase4_lunarrift.lua` |
| 织影者、大门与圣所试炼 | `prefabs/fossil_mound.lua`、`prefabs/atrium_gate.lua`、`prefabs/charlie_hand.lua`、`components/charliecutscene.lua`、`prefabs/vault_key_trial.lua` |
| 三种腐化与暗影后续战 | `components/atriumritualorgantracker.lua`、`prefabs/atrium_ritual_organs.lua`、`prefabs/stalker.lua`、`prefabs/charlie_boss_trial.lua`、`prefabs/charlie_boss.lua`、`prefabs/shrouden.lua` |

本轮验证为静态数据与界面逻辑检查。世界设置会改变生成、事件和裂隙是否启用。待实机验收项目包括简体中文长道具名、手柄焦点、窄窗口下的路线分栏，以及不同世界设置下主线首次触发和复战的提示。未以此记录替代实际通关。
