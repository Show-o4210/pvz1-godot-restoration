# PVZ1 · Godot v1.1 UI 与动画还原

**素材来源版本：PVZ 汉化2版（PVZ1 1.0.0.1051 CN V2）**。当前阶段为 v1.1.0；固定的 v1 标签与旧归档保持不变。

**GitHub 发布不附带原版素材。** 克隆后请先按 [素材导入说明](docs/ASSETS.md) 生成 `assets/`，再打开 Godot。还原基线发布说明见 [RELEASE_V1.md](docs/RELEASE_V1.md)；大改将使用独立的 [Mod 仓库](https://github.com/Show-o4210/pvz1-godot-mod)。

v0 用本地原版资源还原最小白天草坪战斗。当前 v1 保留该玩法，修正卡片尺寸、草坪坐标和角色落点，加入射击反馈、植物受伤、坚果裂纹、路障破损、僵尸断臂/掉头/倒地淡出、推车待机/启动以及原版风格菜单和进度条。阶段范围、来源和剩余差异见 [docs/VERSIONS.md](docs/VERSIONS.md)。

v1 已修复颜色变暗、豌豆头身联动、僵尸下巴、步态移动/停走过渡，以及啃咬后恢复行走的手部贴图残留。此前遇到的 UI、缩放、反馈、损伤和动画问题，现已统一整理为 [问题与解决方式文档](docs/ANIMATION_RENDERING.md)；更新后的全彩动画预览为 `build/v1-detail.mp4`。

v1.1.0 将画面扩为 900×600，重新对齐九列草坪与原背景，露出右侧人行道和道路；卡槽整体留边，点击范围与阳光回收目标同步。阳光恢复原版三层动画的缓慢循环旋转，暂停和收集飞行也正确处理。本轮原因、社区依据和复用方法见 [LAYOUT_AND_SUN.md](docs/LAYOUT_AND_SUN.md)，8 秒预览为本地 `build/v1.1-layout-sun.mp4`。本轮同步还原及 Mod 两个源码仓库。

关卡采用三波简短出怪，尚未照搬原版冒险关卡；不包含图鉴、存档、夜晚、泳池、屋顶和其他植物。已有原版角色动画与音效，背景音乐暂未接入。

## 启动

双击 `启动游戏.cmd`，或在 Godot 4.7.2 中导入 `project.godot` 后按 F6/F5 运行。

左键选择种子，再点击草坪种植；点击阳光收集。右键取消；1/2/3 选择豌豆射手/向日葵/坚果，4 选择铲子，空格/ESC 暂停，R 重开。右上角“菜单”可以暂停并重新开始。

## 社区调查与复用

调查日期：2026-10-05。实际下载并阅读了以下项目：

| 项目 | 实际检查结果 | 使用决定 |
| --- | --- | --- |
| [ZeroMarker/pvz-godot](https://github.com/ZeroMarker/pvz-godot) | 代码中实际只有三种基础植物，视觉使用 icon.svg 占位；发射时直接伤害目标，飞行豌豆只是装饰；没有有限关卡胜利流程 | 用来了解现有进度，没有复制游戏代码 |
| [NightsReimu/pvz-godot](https://github.com/NightsReimu/pvz-godot) | SVG 同人项目，加入大量融合、天气和东方内容；主 game.gd 约 1.6 MB，当前 v1.0.171 | 与本次最小原版还原范围差异较大，没有复制代码或素材 |
| [ec50n9/pvz2godot](https://github.com/ec50n9/pvz2godot) | 成功解包本地 main.pak，转换六个动画并通过仓库动画语义校验 | 复用资源转换工具，固定提交 ba9df9a5aaef7449dd7507d0d7d3993615fec239 |

`tools/pvz2godot/` 为上游 GPL-3.0 工具，保留原许可证。游戏逻辑由本项目编写。`assets/` 来自用户本地游戏安装目录，不属于这些社区工具的源码许可。原版安装目录未修改。

## 重新导入素材

本机已导入当前版本所需资源，公开仓库不包含这些资源。首次克隆或需要重新生成时，在本目录执行：

```powershell
python -m pip install -r requirements.txt
python tools/prepare_assets.py ..\Plants_Vs_Zombies_V1.0.0.1051_CN_V2
```

使用 Python 3.9+ 和 Pillow。原始解包缓存位于 `.source_assets/`；只有选用资源进入 `assets/`。

## 验证

```powershell
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --quit
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/gameplay_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/presentation_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/animation_detail_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/discrete_state_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/blink_alignment_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/sun_collection_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/layout_sun_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --path . --script tests/layout_sun_render_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --path . --script tests/color_render_test.gd
..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/level_playthrough.gd
python tools/pvz2godot/verify.py --all .source_assets/compiled/reanim assets/actors
```

玩法检查覆盖资源扣除、重复种植、冷却、真实子弹飞行与首个目标命中、分行判定、护甲溢出、阳光点击优先级、暂停、铲除、啃食、推车和胜负。

本机 Godot 4.7.2 的 v1 当前验证结果（2026-10-06）：22 项玩法、24 项动画/UI、18 项动画联动/位移、36 项离散状态/动作切换、33 项眨眼绑定、12 项阳光收集、5 项 GPU 颜色检查，共 150 项通过。GPU 零效果颜色对照的 RGBA 误差为零；自动操作按正常经济和冷却规则完成三波关卡，约 188.2 秒击败 15/15 僵尸。v0 的六个动画已通过转换工具语义校验；v1 使用同一转换结果并保留步态元数据，在运行时绑定部件和管理播放，尚未逐像素对照整个原版画面。实际 GPU 截图和连续视频保存在 `build/`，已人工检查；`build/v1-detail.mp4` 保留手型修复后的 8 秒画面，新近景 `build/sunflower-blink.mp4` 展示三个不同摇摆相位的眨眼绑定。既有 `v1` 标签、发行包和完整归档保留原基线，本次修复提交在 `main`。

2026-10-06：阳光收集新增飞回槽位、缩小和计数强调的表现，保持点击入账一次，支持暂停、并发和结算清理。预览位于本地 `build/sun-collection.mp4`。

v1.1.0 当前共 171 项通过：既有 150 项、布局/阳光 14 项、实际鼠标/GPU 7 项。最新正常经济通关 188.3 秒，击败 15/15。完整本地快照为 `versions/v1.1.0-layout-sun-20261006.zip`，附逐文件清单与 SHA-256；GitHub 保持不附原版素材。
