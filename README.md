# 莹 · Lumine

《饥荒联机版》角色模组，当前版本为 **0.45.1**，处于开发预览阶段。

主要内容包括七种元素的战斗能力、见闻兑换洞察的技能树、旅行手册与派蒙记录、武器护甲成长、圣遗物收藏和兰纳罗小屋。

## 安装

1. 下载或克隆本仓库。
2. 将 `mod/lumine` 文件夹复制到游戏安装目录的 `mods` 文件夹。
3. 在世界的模组设置中启用 **Lumine (Journey Preview)**，并选择角色莹。

模组要求所有客户端安装。技能树通过原版「审查自我」打开，元素能力需要学习对应洞察节点并在七天神像处共鸣。

## 项目目录

| 目录 | 内容 |
| --- | --- |
| `mod/lumine` | 可直接安装的 Lua 脚本、纹理、图集和动画 |
| `art` | 源图、分层素材与动画工作文件 |
| `tools` | 美术打包、资源核对与本地测试脚本 |
| `tests` | 自动化测试与人工验收清单 |
| `design` | 系统说明、修改记录和验收结果 |

本地的 `reference` 保存下载的研究资料，`.build` 保存编译中间文件、测试环境和版本备份，`.tools` 保存本地工具依赖。这些目录由 Git 忽略。

## 本地检查

使用 Python 3 安装本地测试依赖，然后运行快速检查。

```powershell
py -3 -m pip install --target .tools/journey-lua -r tests/requirements.txt
py -3 tools/test-journey.py quick
```

按修改范围运行定向测试，例如 `py -3 tools/test-journey.py core --module cryo`。等级、覆盖范围和游戏安装路径的配置见 [测试说明](tests/README.md)。

部分测试需要本机安装 DST。实际画面、操作手感和多人联机的验收状态记录在 `design` 和 `tests/manual` 中。
