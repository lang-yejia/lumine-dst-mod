# 莹的原生洞察技能树 · 第一阶段

## 架构审查

- 本机 DST 的 `prefabs/skilltree_defs.lua` 支持为模组角色注册技能树，`SkillTreeWidget` 可用原生节点、焦点导航和说明面板展示。原生锁节点没有可分配的 RPC 位，可用来显示预留能力。莹的界面另接分支标题、前置连线和旅行手册纸张。
- 原版 `skilltreeupdater` 的握手允许本地档案贡献经验，选角也能提供初始分配。莹沿用原生 `SkillTreeData` 和洞察阈值，由服务端玩家组件保存分配。进入世界后，通过原版「审查自我」兑换和分配。莹停用原生生存计时发放洞察，其他角色继续使用原来的洞察协议。
- 旧旅行手册的见闻奖励、消费记录和能力分别由 `luminejourney` 的 `insight`、`skills`、`elements` 等字段保存。现有风、岩施法和被动读取当前共鸣，神像负责供奉与切换。节点在这套流程之前授予权限，施法时再次检查。
- 两项配方原来使用角色门槛和炼金引擎原型。现在同时使用原生 `builder_skill` 和制作落地时的 `canbuild`，防止用洗点前排队的动作绕过门槛。配方材料、已存在的物品和建筑使用原系统管理。

## 节点

所有节点规划为 1 点洞察。表内稳定 ID 已包含 `lumine_` 前缀。已开放节点共 5 个，预留节点共 22 个。

| 分支 | 节点 | 稳定 ID | 前置 | 状态 |
| --- | --- | --- | --- | --- |
| 元素共鸣 | 元素之门 | `lumine_element_foundation` | 分支起点 | 已开放 |
| 元素共鸣 | 风元素 | `lumine_element_wind` | 元素之门 | 已开放 |
| 元素共鸣 | 岩元素 | `lumine_element_geo` | 元素之门 | 已开放 |
| 元素共鸣 | 雷元素 | `lumine_element_electro` | 元素之门 | 预留 |
| 元素共鸣 | 草元素 | `lumine_element_dendro` | 元素之门 | 预留 |
| 元素共鸣 | 水元素 | `lumine_element_hydro` | 元素之门 | 预留 |
| 元素共鸣 | 火元素 | `lumine_element_pyro` | 元素之门 | 预留 |
| 元素共鸣 | 冰元素 | `lumine_element_cryo` | 元素之门 | 预留 |
| 元素共鸣 | 共鸣研习 | `lumine_element_mastery` | 元素之门 | 预留 |
| 工坊与珍藏 | 星辉圣匣 | `lumine_workshop_codex` | 分支起点 | 已开放 |
| 工坊与珍藏 | 遗珍研读 | `lumine_workshop_relic_study` | 星辉圣匣 | 预留 |
| 工坊与珍藏 | 星辉珍藏 | `lumine_workshop_relic_curation` | 遗珍研读 | 预留 |
| 工坊与珍藏 | 旅人工艺 | `lumine_workshop_reforge` | 星辉圣匣 | 预留 |
| 森林与伙伴 | 兰纳罗小屋 | `lumine_partners_hut` | 分支起点 | 已开放 |
| 森林与伙伴 | 森林园丁 | `lumine_partners_garden` | 兰纳罗小屋 | 预留 |
| 森林与伙伴 | 温暖小屋 | `lumine_partners_hearth` | 森林园丁 | 预留 |
| 森林与伙伴 | 旅伴默契 | `lumine_partners_paimon` | 兰纳罗小屋 | 预留 |
| 战斗技巧 | 熟练剑士 | `lumine_combat_sword` | 分支起点 | 预留 |
| 战斗技巧 | 旅途防护 | `lumine_combat_ward` | 熟练剑士 | 预留 |
| 战斗技巧 | 战后振奋 | `lumine_combat_resolve` | 熟练剑士 | 预留 |
| 战斗技巧 | 月亮专精 | `lumine_combat_lunar` | 战后振奋 | 预留 |
| 战斗技巧 | 暗影专精 | `lumine_combat_shadow` | 战后振奋 | 预留 |
| 旅途生存 | 旅行口粮 | `lumine_survival_rations` | 分支起点 | 预留 |
| 旅途生存 | 轻盈步伐 | `lumine_survival_stride` | 旅行口粮 | 预留 |
| 旅途生存 | 风雨同行 | `lumine_survival_weather` | 旅行口粮 | 预留 |
| 旅途生存 | 野外急救 | `lumine_survival_firstaid` | 旅行口粮 | 预留 |
| 旅途生存 | 辨途 | `lumine_survival_navigation` | 轻盈步伐 | 预留 |

## 迁移与存档

- 旧档初次加载时，从已有共鸣记录、当前元素及更早版本的元素购买标记补录元素之门和已获得的风、岩。用原生阈值补足这些已分配节点所需的最低经验。当前元素为无元素的存档保持无元素。
- 0.41.0 存档中已有的洞察进度和分配原样保留。兑换次数从零开始，已有洞察无需补交见闻。
- 新组件即使洗点成空也保存自身数据。再次加载时优先使用它，避免历史供奉记录重新开启节点。洗点归还已分配洞察，结束当前共鸣、岩盾与由该玩家维持的岩域。旧见闻金额和购买记录继续保留。
- 六项旧购买映射为未来节点的对应主题。`rations` → 旅行口粮，`ward` → 旅途防护，`swift` → 轻盈步伐，`rainproof` → 风雨同行，`swordmaster` → 熟练剑士，`resolve` → 战后振奋。已购买的旧加成按原存档继续生效，预留节点不重复发放加成。
- 正常重连、洞穴迁移和读档走 DST 玩家存档。换角色沿用 DST 的 `SaveForReroll` / `LoadForReroll`，临时把莹的数据带在其他角色的存档上，换回莹时取回。圣遗物收藏和伙伴现有换角规则独立于该过程。

## 见闻兑换

「审查自我」的技能树底部显示可用见闻、下一次价格、进度条和兑换按钮。每次主动兑换获得一点洞察。第 `n` 次兑换花费 `2 + (n - 1) + floor((n - 1)^2 / 8)` 点见闻，前五次分别需要 2、3、4、6、8 点，合计 23 点。当前 20 条见闻累计奖励 40 点，全部完成时可兑换六点，余下 7 点。上限沿用原生 15 点。

## 审查自我窗口

物品栏原生按钮和按键共用 `PlayerHud:InspectSelf()`，该方法在原版玩家资料窗口建立技能页时提供入口上下文。选角的莹技能预览被隐藏，玩家列表仍可打开资料页。节点图标以原始宽高比居中装入 20×20 的容器。

DST 762172 中，威尔逊通过较宽的炼金组与较窄的火炬、胡须、阵营组分配画布。伍迪用五排变身节点和错落的伐木节点安排不同深度。两者都在 `ORDERS` 指定标题位置，用 `group` 和 `pos` 交给 `SkillTreeBuilder`。该版本的 `connects` 负责前置关系和激活判定，界面没有通用连线绘制。莹用同一份前置关系绘制节点间连线，坐标在 `lumine_layout.lua` 单独维护。左侧元素节点环绕基础节点，右侧的工坊、伙伴、战斗、生存各用独立坐标。详情沿用原生纸框和状态，洞察与重置同在上方，兑换使用独立底栏。六项旧旅行技能的效果文案保留在对应预留节点的说明里。

见闻累计总额继续记录历程。可用见闻同时扣除旧购买和已兑换支出。兑换次序和支出随技能树存档保存。重置技能只返还分配的洞察，兑换价格与见闻支出保持。服务端按当前余额、兑换次序、角色状态和洞察上限核验，每次请求对应一次兑换。

## 扩展接口

1. 在 `mod/lumine/scripts/skilltree/lumine_nodes.lua` 内用现有稳定 ID 挂接效果，配置前置、图标和位置。重新排列显示位置不会改变存档键。新增正式节点时留意原版检查面板的 32 位限制。
2. 效果定义是 `{type, key}`。现有类型为 `unlock_element`、`unlock_recipe`、`unlock_feature` 和 `passive_modifier`。被动修饰器在 `lumine_effects.lua` 登记为 `fn(inst, enabled)`，使用可撤销的来源键。若开放旧加成对应节点，按能力去重并单独决定旧购买如何结算。
3. 新元素接入实际共鸣、技能组件和神像交互后，再把对应节点改成可分配。新配方沿用 `builder_skill` 和最终 `canbuild` 检查。
4. 兑换价格在 `lumine_exchange.lua`，服务端结算入口是 `lumineskilltree:ExchangeInsight(exchange_number)`。新见闻来源继续走见闻奖励系统，兑换界面随 `lumine_milestone` 事件更新。

## 验证范围

`py -3 tools/test-journey.py core --module skilltree` 使用本机 DST 数据包中的原生注册、经验阈值和校验代码，验证节点与图集、客户端快照、服务端拦截、旧档迁移、洗点、原配方材料及换角数据。用 `quick --file <Lua 文件>` 检查修改文件的语法。界面鼠标与手柄交互、实际制作、洞穴换区和远端联机需要游戏内验证。
