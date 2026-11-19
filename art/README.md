# 莹：角色美术工作区

## 当前素材

- `concepts/lumine-dst-concept-v1.png`：正面、侧面、背面外观设定稿。
- `source/lumine-head-front-v1.png`：正面头部透明源图。
- `source/lumine-body-front-v1.png`：正面身体透明源图。
- `working/lumine/lumine.scml`：可供 Spriter 和编译器读取的动画工作副本。`SWAP_ICON/SWAP_ICON-0.png` 已换为莹的头部图标；其余 PNG 仍是模板占位图，**角色身体和动作尚不是莹的外观**。

这些是绘制参考和源图，尚未按 DST 的角色动画符号拆分，也没有编译为游戏使用的 `anim/*.zip`。不要把这些 PNG 直接当成可运行角色资源。

## 下一阶段

1. 使用 `../reference/extended-sample-character-dst.zip` 中的 SCML 与 PNG 核对符号名、画布尺寸、锚点和部件遮挡顺序；详见 `template-map.md`。
2. Don't Starve Mod Tools 已安装在 `F:\SteamLibrary\steamapps\common\Don't Starve Mod Tools`。可运行 `tools/compile-art.ps1` 编译工作副本；模板已成功完成一次编译验证。
3. 将正面源图重绘、拆分为脸、前后发、躯干、手臂、手、裙摆、腿等独立透明部件；补齐侧面、背面和表情。
4. 编译角色动画，接入最小角色 Mod，在游戏中检查站立、移动、攻击、装备、受伤及死亡动作。

图标从 `source/lumine-head-front-v1.png` 通过 `tools/build-swap-icon.ps1` 导出为模板要求的 268×244 透明 PNG。修改头部源图后重新运行该脚本，再运行 `tools/compile-art.ps1`。已验证编译结果 ZIP 包含 `anim.bin`、`build.bin` 和贴图。

参考模板：https://github.com/DragonWolfLeo/extendedsamplecharacter-dontstarvetogether

源图由内置 imagegen 依据项目设定稿生成，作为后续手工整理的基础。
