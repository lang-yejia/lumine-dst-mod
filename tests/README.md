# 旅行手册本地测试

从项目根目录运行。一次性安装 Python 测试依赖到被 Git 忽略的 `.tools` 目录。Lupa 只用于本地测试，入口明确加载其中的 Lua 5.1 解释器。

```powershell
py -3 -m pip install --target .tools/journey-lua -r tests/requirements.txt
```

| 等级 | 命令 | 覆盖 |
| --- | --- | --- |
| 快速 | `py -3 tools/test-journey.py quick` | Lua 5.1 语法、章节字段、旧章节顺序、奖励、关联和证物索引。 |
| 核心 | `py -3 tools/test-journey.py core` | 证物提交条件、快照拒收、单件提取异常、独立玩家与服务端权限、奖励幂等、损坏存档、旧档与恢复。 |
| 完整 | `py -3 tools/test-journey.py full` | 快速和核心检查，加上从派蒙动作进入的模拟集成、满格、队列上限、存档时点、入袋回调异常、换角、实际 DST 安装中的图集、纹理和证物定义。 |

默认读取本机 F 盘的 DST 安装。其他位置可传 `--dst-root "D:\SteamLibrary\steamapps\common\Don't Starve Together"` 或设置环境变量 `DST_ROOT`。快速与核心不需要安装游戏。

## 日常用法

- 只改一个 Lua 文件时运行 `py -3 tools/test-journey.py quick --file mod/lumine/scripts/screens/lumine_journal_screen.lua`。多个文件可以重复传 `--file`。
- 只检查原生洞察技能树时运行 `py -3 tools/test-journey.py core --module skilltree`。该测试读取本机 DST 数据包，可用 `--dst-root` 指定安装目录。
- 修改风行时运行 `py -3 tools/test-journey.py core --module wind_dash`。该测试模拟位移、障碍、闪避、消耗和冷却。
- 修改雷元素时运行 `py -3 tools/test-journey.py core --module electro`。该测试模拟战斗回能、持续扣能、施法、弹道结算和中断清理。
- 修改草元素时运行 `py -3 tools/test-journey.py core --module dendro`。该测试直接执行模组 Lua，模拟召唤概率和间隔、动作触发点、缠根、定点爆炸、领域中毒、冷却和退出清理。
- 修改水元素时运行 `py -3 tools/test-journey.py core --module hydro`。该测试覆盖水滴的生成与扣费、水纹剑的轨迹和潮湿，以及水泡的仇恨、生命值、爆炸和清理。
- 修改火元素时运行 `py -3 tools/test-journey.py core --module pyro`。该测试模拟随身火环、资源倍率、按下与抬起、递增伤害、爆炸目标和中断清理。
- 修改冰元素时运行 `py -3 tools/test-journey.py core --module cryo`。该测试读取本机原版冻结组件，覆盖冰盾拦截、破冰结算、真实武器限制、附魔去重、冰陨落点、领域、抗性和存档清理。
- 只改章节数据时运行 `py -3 tools/test-journey.py quick --module data`。改图集时可直接运行 `py -3 tools/check-journey-assets.py`。
- 修改交付、奖励、存档或权威逻辑时运行核心。涉及背包、存档或游戏动作衔接时，再运行 `py -3 tools/test-journey.py full --module flow`。它只执行模拟集成，不扫描资源或语法。
- 完成一个里程碑时运行一次完整测试。已经通过且受影响范围之外的检查可以沿用上次结果。

## 测试模块

- `data_test.lua` 加载真实的章节及奖励数据。
- `recording_test.lua` 通过真实玩家组件测试交付判定、持久化和奖励边界。
- `flow_test.lua` 从实际的派蒙动作或玩家事件进入，用模拟背包、派蒙、计时与存档执行流程。
- `fixtures.lua` 模拟测试触及的 DST API。真实运行时验证按 [游戏验收清单](manual/journey.md)执行。

所有命令由本地脚本执行，可重复运行，失败退出码为 1。优先看 `FAIL`、用例名、文件行号和最后一条诊断。资源文件路径或语法错误可以直接处理。只有遇到不明的回归、数据丢失或重复、引擎行为与模拟不同、或者需要改变玩法规则时，才让 Codex 分析失败用例、相关日志与对应代码。
