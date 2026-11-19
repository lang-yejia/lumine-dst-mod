# 莹角色的 DST 动画部件映射

依据 Extended Sample Character DST 模板的 `exported/esctemplate/` 目录。括号内为模板该符号的 PNG 数量；同一符号有多个方向、表情或动作变体，不能用一张 PNG 代替整组。

| 模板符号 | 数量 | 莹的设计内容 |
| --- | ---: | --- |
| `headbase`, `headbase_hat` | 4 + 4 | 脸部轮廓；帽子遮挡时的版本 |
| `face`, `cheeks`, `face_sail` | 33 + 2 + 1 | 金色眼睛、各表情及特殊动作表情 |
| `hair`, `hairfront`, `hair_hat`, `hairpigtails` | 4 + 2 + 4 + 5 | 金发、额前发、白花及帽子适配发型 |
| `torso`, `torso_pelvis`, `skirt` | 11 + 11 + 5 | 白金服装主体、腰饰、裙摆与背部飘带 |
| `arm_upper`, `arm_upper_skin`, `arm_lower`, `hand` | 7 + 3 + 7 + 20 | 双臂、分离袖套、手套及握持动作 |
| `leg`, `foot` | 11 + 8 | 深色长袜与鞋子 |
| `tail` | 12 | 根据实际动画检查；可用于后方飘带，不能直接删去符号 |
| `SWAP_ICON` | 2 | 游戏中的角色图标素材 |

## 已有源图到符号的关系

- `source/lumine-head-front-v1.png`：头部整体参考，用于重绘 `headbase`、`face` 和各发型符号。
- `source/lumine-body-front-v1.png`：身体整体参考，用于重绘躯干、裙摆、手臂、手、腿等符号。

两张源图尚未按模板尺寸、锚点、朝向与遮挡关系拆分。绘制时应在模板原有画布及命名规则上逐件替换，并检查全部动作变体；不能仅缩放整张源图并重命名。
