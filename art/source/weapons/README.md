# 四把剑的美术源图

这些 PNG 是通过内置 imagegen 生成的透明背景原画，参考《原神》的武器轮廓，再调整为《饥荒联机版》适用的墨线手绘风格；并非游戏官方贴图。当前仅将无锋剑接入配方和物品预制体，其余三把已编译好图标与动画资源，留待升级系统使用。

| 文件 | 参考武器 | 稀有度 | 主要外形提示词 |
| --- | --- | --- | --- |
| `lumine_dull_blade.png` | 无锋剑 | 1 星 | 简洁灰铁直刃、短护手、蓝色缠柄 |
| `lumine_harbinger_of_dawn.png` | 黎明神剑 | 3 星 | 细长银蓝剑刃、深蓝剑脊、蓝宝石护手 |
| `lumine_prototype_rancour.png` | 试作斩岩 | 4 星 | 宽银刃、深色机械剑脊、金铜色几何护手 |
| `lumine_aquila_favonia.png` | 风鹰剑 | 5 星 | 明亮银刃、青色剑脊、白金羽翼护手 |

共同提示词：单把完整长剑，剑尖向上、握柄向下，正视图，居中，透明背景，无人物、文字或其他物件；饥荒风格的手绘墨线，缩小至 64 像素仍可辨认。

`tools/build-sword-art.py` 将源图转为 Spriter 工程用的落地图、七张持握图和图标 PNG。`mod/lumine/anim/` 中的对应 ZIP 由 Don't Starve Mod Tools 的 `scml.exe` 编译；`mod/lumine/images/inventoryimages/` 中的 TEX 由 ktools 的 `ktech.exe` 转换。
