# 凛冬之力 · 冰元素 0.45.0

通过原版「审查自我」学习现有的冰元素节点，再向无属性七天神像供奉原有冰元素力并共鸣，即可使用冰元素。节点 ID 沿用 `lumine_element_cryo`。

## 原版源码与资源映射

| 原版来源 | 调查结果与复用方式 |
| --- | --- |
| `prefabs/deerclops_icespike_fx.lua` | 冰柱是视觉实体。复用其 `RestartFX` 与 `deerclops_icespike.zip`，伤害由莹的技能逻辑结算。 |
| `stategraphs/SGdeerclops.lua` | 变异巨鹿的 `icelance` 在指定落点生成冲击圈，连续三帧攻击并去重。莹采用单次落点结算。 |
| `prefabs/deerclops_mutated_fx.lua` | 原版冲击圈还会处理温度、疲劳、灭火和大范围冻结。冰元素以独立视觉 prefab 加载同一套 `ice_impact`、`deer_ice_circle` 动画。 |
| `components/freezable.lua` | 使用原生 `AddColdness(2, duration)`、`IsFrozen` 与 `Unfreeze`。保留冻结抗性、递减、转移判定和 `nofreeze` 状态。 |
| `components/combat.lua` | 本角色的受伤入口拦截冰盾。普通攻击在原有 `CalcDamage` 后处理双倍伤害，实际命中后消耗冻结，附魔冰柱在原攻击结束后生成。 |
| `prefabs/forcefieldfx.lua` | 复用护盾动画并染为蓝白色，附加三枚原版冰晶组成冰盾。 |

## 技能参数

| 技能 | 参数 |
| --- | --- |
| 寒冰护体 | 初次共鸣获得一层冰盾。抵消下一次战斗伤害，含普通与位面伤害。破裂后在半径 4 内尝试冻结敌人 2 秒，20 秒后恢复。 |
| 破冰 | 冻结目标受到莹的下一次攻击时，普通伤害和位面伤害均翻倍，然后消耗该冻结。直接元素技能同样支持破冰。 |
| 霜刃附魔 | 20 元素力，12 秒冷却。当前旅行者剑获得四次附魔。每次有效武器攻击生成一组冰柱，半径 2.5，额外伤害 30，尝试冻结 1.5 秒。 |
| 极寒冰陨 | 40 元素力，25 秒冷却，施法 0.6 秒。鼠标落点最多距角色 12，冰锥命中半径 4.5，伤害 100，尝试冻结 3 秒。 |
| 冰冻领域 | 冰陨落点产生半径 4、持续 8 秒的固定领域。本人位于领域内时，旅行者剑有效攻击获得冰柱效果。每个目标触发间隔 0.75 秒。 |

冻结时长针对普通可冻结生物。Boss 使用其原有抗性和递减，无冻结组件或处于冻结免疫状态时仍会结算直接伤害。

## 状态和结算

- 冰盾在战斗入口检查正向攻击伤害，于生命和护甲结算前挡下一次攻击。饥饿、温度等直接生命变化沿用原流程。
- 冻结通过原版组件产生。技能只限制自己创建的冻结时长，后续其他来源接管冻结时保留其状态。原版冻结后还有解冻阶段，本技能在指定时间结束自己的冻结，避免额外延长控制。
- 同一次原版攻击使用独立上下文。普通伤害与位面伤害使用同一冻结快照，多目标与多次命中回调共用一次附魔消耗。
- 附魔按 `lumine_gear_stats.swords` 中注册的四个武器 prefab 校验。显示名称和标签不参与授权。附魔绑定实例，换下、移除或耗尽四次后结束。
- 领域优先于四次附魔，每次攻击只生成一组冰柱，领域触发保留一技能剩余次数。领域、冰盾、附魔和目标触发间隔均为玩家个人状态。
- 目标坐标由服务端限制距离并验证地面，释放时再次检查。施法中断不支付元素力，成功释放后才扣费和开始冷却。
- 伤害经过原版战斗接口。敌我判定沿用项目现有规则，排除玩家、友方、宠物、常见召唤物、建筑和无效目标。

## 存档与 HUD

冰盾的是否就绪及恢复倒计时、两个技能的剩余冷却写入组件存档。重载时清理临时附魔、飞行冰锥和领域，再按已保存的冰盾恢复状态和冷却重建。换元素、死亡、离场均清理临时效果。

HUD 显示冰盾状态与恢复时间、附魔次数、技能冷却和领域剩余时间。冰陨默认鼠标定位，支持技能栏内切换面朝方向。0.45.1 接入了统一的冰蓝色手绘徽记，覆盖冰元素、寒冰护体、霜刃附魔、极寒冰陨和冰元素力物品。

## 修改文件

- 技能逻辑与表现为 `scripts/components/luminecryo.lua`、`scripts/cryo/rules.lua`、`scripts/cryo/combat.lua`、`scripts/cryo/attacks.lua`、`scripts/cryo/freeze.lua`、`scripts/flight/lumine_cryo_cast.lua`、`scripts/prefabs/lumine_cryo_fx.lua`。
- 接入文件为 `modmain.lua`、`modinfo.lua`、`scripts/prefabs/lumine.lua`、`scripts/components/luminejourney.lua`、`scripts/lumine_direct_damage.lua`、`scripts/lumine_statue_elements.lua`、`scripts/lumine_progression.lua`、`scripts/skilltree/lumine_nodes.lua`。
- 界面文件为 `scripts/widgets/lumine_element_hud.lua`、`scripts/widgets/lumine_energy_hud.lua`、`scripts/screens/lumine_element_screen.lua`、`scripts/screens/lumine_resonance_screen.lua`。
- 本地测试文件为 `tests/cryo_test.lua`、`tests/skilltree_test.lua`、`tests/run.lua`、`tests/README.md`、`tools/test-journey.py`。

## 定向验收

离线命令为 `py -3 tools/test-journey.py core --module cryo`，直接读取本机原版冻结组件。涵盖致命攻击和位面伤害拦截、破盾冻结、双倍结算、武器白名单、四次附魔、多目标与多回调去重、鼠标落点、免冻伤害、领域优先级、玩家隔离与存档清理。

图形客户端集中确认冰晶环绕、武器冰霜跟随、大型冰锥抛射、爆炸和领域显示，以及不同 UI 缩放与真实联机输入。

## 本轮验证结果

- 本轮 22 个 Lua 文件语法检查通过，测试运行器的 Python 语法检查通过，四个原版图标的 atlas 引用已核对。
- 11 项冰元素模拟通过，直接执行了本机原版冻结组件，另有 12 项技能树测试通过。相关共享伤害接口的火、水、雷、草回归和章节数据检查共 41 项通过。
- 真实 DST 隔离服务器验证了神像解锁共鸣、含位面伤害的致命攻击拦截、普通目标两秒冻结结束、原版武器拒绝附魔、旅行者剑附魔扣次、冰柱、破冰后重新冻结，以及换下武器清理。
- 同一服务器还验证了冰锥和冰霜爆炸动画可加载、龙蝇受到直接伤害、友方免伤、领域内免费冰柱、目标触发间隔、领域八秒结束和冷却保存。
- 测试中修复了冻结到期任务与原版解冻任务落到同一游戏帧时的顺序问题。自定义到期任务先注册，确保不会被额外延长到原版解冻阶段。
- 图形客户端视觉、鼠标输入手感、两名真实客户端同时操作和切换地表／洞穴仍需人工验收。当前服务器测试使用隔离测试世界。

## 0.45.1 冰元素图标

源图位于 `art/source/element/cryo-medallions.png`，通过内置 ImageGen 制作。参考了现有水元素图集的黑色手绘线条、旧黄铜边框和菱形饰钉，使用冰蓝、银白和深蓝灰底色。四枚图案依次为雪花徽记、冰晶护盾、冰霜剑和坠落冰锥。

运行 `py -3 tools/build-cryo-icons.py` 可导出 `images/element/cryo-emblem`、`cryo-passive`、`cryo-infusion`、`cryo-meteor` 和 `images/inventoryimages/lumine_cryo_essence` 的 XML／KTEX 文件。技能图标采用 128 像素画布，物品图标增加透明留白以匹配现有物品栏尺寸。

本次修改涉及 `modmain.lua`、`modinfo.lua`、`scripts/lumine_statue_elements.lua`、`scripts/lumine_progression.lua`、`scripts/skilltree/lumine_nodes.lua`、`scripts/prefabs/lumine_element_essence.lua`、`scripts/widgets/lumine_element_hud.lua`、`scripts/widgets/lumine_energy_hud.lua`、`scripts/screens/lumine_element_screen.lua` 及新增图集、源图和打包脚本。神像界面通过共享元素数据读取新徽记。

9 个修改过的 Lua 文件语法检查通过，12 项技能树定向检查通过，5 组图集的透明边距、纹理文件和资源名称已核对。缩小预览已检查，游戏内实际显示仍待集中验收。

<details>
<summary>图标生成提示</summary>

Create one new game UI sprite sheet for the Cryo ice element of a Don't Starve Together character mod. Use the attached image as a STYLE REFERENCE only. Four distinct circular medallions in a strict 2 by 2 square grid, matching the reference's bold irregular black ink outlines, narrow worn brass rim, four tiny diamond studs, matte hand-painted brush texture, and readable silhouettes at 48 px. Each medallion occupies about 80% of its square cell with a clear fully transparent margin on all sides. True transparent background outside the medallions. Dark muted slate-blue backgrounds, frosty icy cyan, ivory-white and cool silver-blue subjects with modest warm brass accents, clear lighter palette than the Hydro reference. TOP LEFT: Cryo elemental emblem, symmetric six-point snowflake made of angular ice crystals and a central diamond, no water waves. TOP RIGHT: Ice Guard passive, an upright shield made of large ice facets, tiny snowflake at its heart, a few compact crystal points on its shoulders, represents protection and shatter counterattack. BOTTOM LEFT: Frostblade infusion, a diagonal sword embedded in sharply faceted ice with two small crystal shards, simple bold shape and white cutting edge. BOTTOM RIGHT: Glacial Meteor, one large pointed ice lance descending diagonally toward a small circular cracked frost impact ring, clear falling motion, large crystal silhouette. Balance icon size and visual weight across all four. Keep all artwork and rings fully within their individual cell. No lettering, captions, layout dividers, shadows outside the rings, glow spilling outside the rings, characters, glossy 3D styling, or sheet background. Deliver a genuine transparent PNG.

</details>
