# 陈默动作 v2

2026-10-15，使用内置 image generation 按原主角身份参考重新生成。保留棕发、橄榄色连帽外套、浅色内搭、深裤和背包，不更改碰撞/移动/跳跃参数。旧动作目录保留，可回退。

| 动作 | 来源帧数 | 播放 |
| --- | --- | --- |
| idle | 6 | 6fps 循环 |
| walk（运行时名称） | 12 | 改用jog目录的小跑，基准16fps，按实际移速缩放 |
| jump | 4 | 已按用户要求回退原版 `../jump` 素材与5fps顺序播放 |
| interact | 6 | 12fps；移动或跳跃可打断 |

生成参考为原 `../idle/idle-1.png`；行走最终采用新待机帧与 `walk-anchor.png` 的双参考，第一版比例检查未通过，没有接入。每组完整提示词位于对应的 `prompt-used.txt`。

`generate2dsprite.py process` 完成去洋红、组件清理、独立动作切片和QC。idle/walk/interact共用 `character-scale-profile.json`；行走组帧内尺寸变异约3.9%，与待机的面积尺度差异约2.9%，均通过检查。jump因空中压缩姿态使用独立中心锚点，但保持相同处理倍率，没有逐帧尺寸归一化。

`tools/normalize_hero_v2.py` 只平移128×128帧：头部横轴固定64，地面动作鞋底固定125，空中动作保留原纵向姿态差异。不会逐帧缩放身体。该脚本应只对全新processor输出运行一次；重复运行在已对齐输入上不会改变位置。

运行使用 `scripts/player/hero_anim.gd`。立姿显示约70世界像素、鞋底嵌地6像素，与原NPC尺寸契约一致。初版新jump因用户反馈已停用；当前恢复原版四帧及原播放方式，删除独立蜷身落地帧。移动改用jog目录，保留屈肘摆臂和四张短腾空姿态，没有改变130移速或-320跳跃初速度。

小跑原图：`exec-a146f65a-ca8c-41fb-8d8d-7585af1edf8a.png`（内置生图）；提示词在 `jog/prompt-used.txt`。共用待机尺度配置，帧内面积尺度变异约1.7%，与待机差异约2.6%。`tools/normalize_hero_jog.py`仅平移对齐头部和接触帧鞋底，保留4、5、9、10帧的短腾空，不逐帧缩放。

原始生成文件保留在Codex生成目录，同时processor保存每组raw-sheet.png：

- idle: exec-a9a3a45e-1e10-4f24-bfd5-b4a512eeb01a.png
- walk: exec-af6d17c1-6b6a-4ffa-986b-ab9a2a1d660c.png
- jump: exec-7630d8ff-6246-4255-8210-c9359c3fe54a.png
- interact: exec-59e5393f-d2c1-4d41-9acb-c85a2a8e2116.png

验证：`tools/test_hero_animation_v2.gd` 检查完整12帧、左右朝向、鞋底锚点、上升/最高点/下降、落地、交互打断与冻结待机；另回归前关视觉和第六关真实输入流程。重启运行实例后生效，未导出EXE/PCK。
