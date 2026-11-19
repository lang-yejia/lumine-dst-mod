# 火元素 · 0.44.2

在原有洞察技能树中学习「元素之门」和「火元素」，再到已献上火元素力的七天神像共鸣。沿用既有节点 ID、供奉物和神像状态。

| 技能 | 运行规则 |
| --- | --- |
| 炽热之心 | 火元素共鸣期间，普通武器和 Mod 敌对技能伤害乘以 1.1。目标有流火之刃灼烧时改用 1.25 倍。常规、位面和技能伤害各通过自己的结算入口取一次倍率。 |
| 流火之刃 | 消耗 18 点元素力。随身火环半径 1.5，视觉缩放 0.83。跟随角色 6 秒，施放时及其后每 1.5 秒攻击一次，共四次。基础伤害 20，冷却 11 秒。命中给敌人施加 4 秒灼烧，每秒 4 点基础火伤，通常为 5 点实际伤害。后续命中刷新持续时间。 |
| 爆炎状态 | 二技能切换。开启时需要至少 7 点元素力。原版饱食消耗和持续理智消耗各乘以 1.5，饱食倍率叠加使用原版修正器。环境本身没有持续理智消耗时，爆炎也没有额外理智扣除。 |
| 火焰球 | 爆炎期间，一技能首次按下立即发射一颗。按住后按 0.50、0.42、0.34、0.28、0.23 秒的间隔连发，之后维持最快档。每颗消耗 7 点元素力。默认朝鼠标，爆炎时可用技能栏上方按钮切换角色朝向。飞行速度 15，最远 10；撞到敌人或建筑阻挡时以 2.5 为爆炸半径。范围判定纳入目标碰撞半径。 |

火焰球的五级基础伤害为 35、45、55、65、75，继续连发维持 75。经过炽热之心后分别为 38.5、49.5、60.5、71.5、82.5，随后仍由原版目标的防护与免疫处理。松手重置连发。手动关闭、元素力不足、受到有效伤害、强制状态、死亡、离场和切换元素均清理对应状态。最后一颗元素力足够的火焰球可以正常飞完。冷却可跨存档保留，爆炎、火焰环与吟唱是临时状态。

客户端使用普通按键与原版 HUD 按钮的实际按住、抬起事件。键盘按住期间同步鼠标地面坐标，下一发采用最新方向。鼠标在界面上或手柄操作时使用角色朝向。服务器控制发射间隔并校验共鸣、角色状态及资源。抬起和 HUD 失焦会停止连发，输入确认超时也会停止连发。爆炎开启时二技能亮起，一技能切换为火球图标；连发时显示阶数，元素力不够时通过图标和悬停提示反馈。

## 原版资源和伤害判定

- 施法沿用薇洛的 `pyrocast_pre`、`pyrocast` 动作和点火施法音效。火焰环使用薇洛的 `frenzy_fx` 原版循环动画。
- 0.44.1 用新绘制的火球编译了以实体为中心的循环动画。0.44.2 将火球视觉放大到 1.5 倍并抬升出手点，飞行时逐渐降到约 0.9 的高度。命中时在空中的接触点播放爆炸，同一平面坐标的地面火光标出实际伤害位置。
- 灼烧使用只播放原版火焰动画的视觉实体，扣血经过原版生命组件并计入火焰抗性。每跳不产生原版着火、火伤或受击事件，火焰不会向场景传播。
- 火焰环、火焰球和爆炸只执行视觉播放及服务器直接攻击。目标需符合敌对生物判定，玩家、队友、跟随宠物、常见召唤物、建筑和无敌目标均排除。撞建筑时会提前爆炸，飞到最大距离时熄灭。视觉实体没有燃烧、火焰传播或发热组件。

## 0.44.1 图案源文件

- `art/source/element/pyro-medallions.png` 是用内置 ImageGen 绘制的透明图集。生成提示要求延续水元素的黑色手绘轮廓、窄黄铜环和菱形饰钉，使用深红底、橘红火焰和暖金高光。按行排列火焰徽记、炽热之心、火环、爆炎和彗星火球五枚独立纹章，第六格留空。
- `art/source/element/pyro-fireball.png` 是用内置 ImageGen 绘制的透明投射物原画。生成提示要求正视的紧凑圆形火焰，以亮黄色火核居中，外缘是贴近球面的橙红火舌，背景、尾焰和地面阴影留空。火球美术独立于技能栏的彗星形图标。
- `py -3 tools/build-pyro-icons.py` 输出六组图集，覆盖五枚界面图标和火元素力供奉物。 `py -3 tools/build-pyro-orb-art.py` 将居中火球编译为 `mod/lumine/anim/lumine_pyro_orb.zip`。

<details>
<summary>ImageGen 原始提示</summary>

> Create ONE new transparent game sprite sheet, a 3-column 2-row strict grid, landscape 3:2, for the Pyro (fire) element of a Don't Starve Together mod. The attached image is only the style reference: same large round hand-painted medallions with black ink, weathered narrow brass edge and four small diamond studs at the cardinal points, bold silhouettes, brush-painted matte texture legible at 48px. Replace the cool blue with dark coal/oxblood centers and rich warm terracotta, coral vermilion, ember-orange and parchment-gold highlights. Five distinct, separately isolated ROUND medallions only. Place their centers exactly at cell centers in a regular 3 columns x 2 rows layout, each sized about 78 percent of a square cell; true transparent gutters around every medallion and the entire sixth cell blank transparent. First row, left to right: (1) Pyro elemental emblem, a strongly symmetrical stylized three-tongued flame with small ember diamond; (2) Burning Heart passive, a red stylized heart with flame licking upwards; (3) Ring of Fire, a clearly hollow elliptical ring made of licking flame with a dark open center. Bottom row: (4) Blazing State, compact tall flare like a torch crown rising above a tiny circular base; (5) Fireball, one round bright fiery head with a strong diagonal trailing flame like a comet; (6) empty. Distinct compositions, comparable silhouettes and visual weight. No lettering, captions, callouts, checkerboard, shadow, glow outside the medallion, extraneous objects or sheet background. Output genuine transparent alpha.

> Generate one isolated GAME VFX SPRITE to render a red-orange Pyro fireball in a hand-painted Don't Starve Together style. Square transparent PNG, centered round ball of densely swirling hot oranges, vermilion and ochre flame with a luminous butter-yellow core in the exact center of the canvas; lively short jagged lick flames contained close to the circumference, tight readable circular silhouette, dark ink accents inside the fire, matte brush grain, distinct red outer layer. This is a small projectile and will be animated by the game. Compact radial shape seen straight-on, the center of the core and bounding circle aligned exactly, a little alpha around the edge. Ball occupies 72% of the canvas, transparent alpha by the margins, no tail, no ground, no oval shadow or ambient glow, no border, no frame, no lettering, no other objects.

</details>

## 修改文件

- 技能执行与输入：`scripts/components/luminepyro.lua`、`scripts/flight/lumine_pyro_cast.lua`、`scripts/pyro/rules.lua`、`scripts/pyro/attacks.lua`、`scripts/pyro/input.lua`、`scripts/prefabs/lumine_pyro_fx.lua`。
- 共鸣、同步与 HUD：`modmain.lua`、`modinfo.lua`、`scripts/prefabs/lumine.lua`、`scripts/components/lumineenergy.lua`、`scripts/components/luminejourney.lua`、`scripts/skilltree/lumine_nodes.lua`、`scripts/lumine_statue_elements.lua`、`scripts/lumine_progression.lua`、`scripts/widgets/lumine_element_hud.lua`、`scripts/widgets/lumine_energy_hud.lua`、`scripts/screens/lumine_element_screen.lua`、`scripts/screens/lumine_resonance_screen.lua`。
- 直接伤害接入：`scripts/lumine_direct_damage.lua`、`scripts/lumine_dendro_field.lua`、`scripts/lumine_dendro_root.lua`、`scripts/lumine_electro_orb.lua`、`scripts/prefabs/lumine_wind_tornado.lua`、`scripts/hydro/bubble.lua`、`scripts/hydro/stream.lua`。已有技能沿用各自基础数值、触发条件和伤害来源。
- 本地检测：`tests/pyro_test.lua`、`tests/skilltree_test.lua`、`tests/run.lua`、`tests/README.md`、`tools/test-journey.py`。火元素定向模拟命令为 `py -3 tools/test-journey.py core --module pyro`。

## 0.44.0 验证结果

- Lua 5.1 语法检查 28 项通过，五枚原版技能图标已在本机图集中核对。
- 火元素模拟 8 项、洞察技能树 11 项、章节数据 5 项、相关水／雷／草回归 25 项通过。
- DST 隔离无渲染服务器验证了神像共鸣、常规及位面伤害倍率、火环跟随、原版施法和投射物动画加载、爆炸只结算一次、草地未被点燃、定时连发、资源耗尽及原版离场清理。

## 0.44.1 验证结果

- 本次修改的 Lua 文件和定向测试文件共 17 项语法检查通过。火元素、洞察技能树、水元素共 29 项定向模拟通过。
- 六组新图集均有配套 KTEX 纹理，19 帧飞行动画的图像原点平移为零。
- DST 隔离服务器验证了火环范围缩小、鼠标变向后的连发、连发提速、火球原地切换爆炸动画，以及撞到原版石墙时在接触侧爆炸且石墙生命值保持不变。

## 0.44.2 验证结果

- 12 项 Lua 语法检查、11 项火元素定向模拟和 25 项水、雷、草回归通过。覆盖灼烧首次应用、刷新、到期、抗火及增伤，以及火球的抬升和近距离阻挡。
- DST 隔离服务器验证了抬手高度发射、空中爆炸与地面命中标记对齐、石墙碰撞，以及实际灼烧扣血时未触发原版点燃、火伤和受击事件。原版武器伤害与风鹰剑位面伤害均对灼烧目标正确取到 1.25 倍。

## 图形客户端待验收

1. 在火元素神像共鸣并展开技能栏，分别用键盘和鼠标短按、长按；松手或将鼠标移出按钮后确认连发结束。
2. 检查火环范围、橙红弹道、爆炸视觉、受击退出、技能图标切换和动作衔接。
3. 在真实联机客户端验证持续按键、断线重连和地表／洞穴切换时的状态同步。
