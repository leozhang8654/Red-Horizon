# 一号游戏 — 项目说明（给 Claude 看）

## 关于作者
- 完全的游戏开发新手，第一次用 Godot。
- 引擎：Godot 4.6，系统：macOS。

## 沟通规矩（每次回复都要遵守）
- 全程用**中文**。
- 用**大白话**，不要技术黑话；必须用术语时先解释它是什么。
- **一步一步**来，每步先讲"为什么要这样改"，再给"具体怎么操作"（点哪里、改什么数字）。
- 每讲完一步就**停下来**，等我说"继续"再做下一步。
- **需要调参/调试时，主动告诉我"具体在哪调"**：哪个文件、哪个参数（脚本里的 `@export` 变量名 / Inspector 里显示的名字）、它管什么、往哪个方向调会怎样（调大/调小的效果）。**不要反过来问我要数字、或让我描述**——直接给出可调的旋钮和建议值。

## 干活方式（重要）
- **Claude 直接改文件**（用读写/编辑工具改 `.gd`、`.tscn`，需要处理图片就用 Python/Pillow）。
- **我（用户）在 Godot 编辑器里运行游戏**：按 F5 或左上角 ▶。Godot 提示"文件在外部被修改"时，我点 **Reload（重新加载）**。
  - 跑**主游戏**用 **F5 / ▶**；跑**当前打开的那个场景**用 **F6 / 拍板图标**。
- **不要用电脑控制（computer-use）替我操作 Godot**，由我自己点。
- **不要永久删除文件**：要"删"的东西用 `mv` 移动到 `/tmp`，**绝不用 `rm`**。
- **不要打开可疑或临时链接**。
- **脚本/场景改名要在 Godot 的 FileSystem 面板里改**（不要在外部直接改文件名），否则会断掉引用。

## 项目结构（哪个文件管什么）
- `main.tscn` — 主场景：背景、玩家、敌机生成器(WaveSpawner)、HUD、游戏结束画面(GameOver)、暂停菜单(PauseMenu)、屏幕震动相机(ShakeCamera)。
- `player.gd` — 玩家飞机：移动、空气墙、机身侧倾、主炮/副炮自动开火、血量与受伤无敌、闪避翻滚(Roll 动画)。
- `dust skimmer.gd` / `enemy.tscn` — **第一波**小兵：V 字进场、悬浮、受击闪烁、三炮口开火。
- `side_reaper.gd` / `side_reaper.tscn` — **第二波**精英敌机；`side_reaper_explosion.tscn` 是它的死亡爆炸。
- `mech_arm.gd` / `mech_arm.tscn` — **第二波**随场出现的机械臂电锯（场地危险物）。
- `wave_spawner.gd` — 编队管理：第一波 V 字杂兵 → 清光后第二波(Side Reaper + 机械臂)。含 `jump_to_wave(n)` 供作弊跳波。
- `enemy_bullet.gd` / `dust skimmer amo.tscn` — 敌方子弹（向下飞）。
- `player bullet.gd` / `bullet.tscn` — 玩家主炮子弹。
- `副炮子弹.tscn` — 玩家副炮子弹。
- `explosion.gd` / `explosion.tscn` — 通用爆炸动画。
- `hud.gd` — HUD：**顶部分数** + 左下角爱心血条（玩家扣血/加分时刷新）。
- `game_over.gd` — 游戏结束画面（显示本局分数，空格重开）。
- `pause.gd` — 暂停菜单（ESC 开关）；内含**开发者作弊**：密码框输入 `123456` 后出现"波数跳跃"，输入波数即可跳转。
- `camera_shake.gd` — 屏幕震动（ShakeCamera）。
- `background.gd` — 滚动背景（Parallax2D）。
- `scroller.gd` — 向下滚动的物体（AnimatableBody2D），滚出屏幕底部就循环回顶部。

## 分组(group)约定（用于查找/碰撞判定）
- 玩家子弹 → `"bullet"`
- 敌方子弹 → `"enemy_bullet"`
- 敌机 → `"enemy"`
- HUD（血条+分数）→ `"hud"`
- 编队生成器 → `"spawner"`
- 游戏结束画面 → `"game_over"`
- 暂停菜单 → `"pause_menu"`

## 调试 / 作弊
- 游戏中按 **ESC** 暂停 → 密码框输入 `123456` → 出现"波数跳跃" → 输入 **1**(杂兵编队) 或 **2**(Side Reaper) 跳到该波。

## 项目参数
- 视口分辨率：1152 × 648（见 `project.godot`）。

## 容易踩的坑
- **改了贴图(PNG)但游戏里没变**：Godot 缓存了旧图。把 `.godot/imported/` 里对应的 `.ctex` 和 `.md5` 用 `mv` 移到 `/tmp`，再让我回到 Godot 自动重新导入（或右键 PNG → Reimport）。
- **图片"假透明"**（看着是棋盘格背景，其实背景被烤进像素里）：需要用边缘洪水填充(flood-fill)抠图，把浅色低饱和的背景设为透明。
- **在物理回调里删除带碰撞的节点会报错**：改用 `call_deferred` 延后执行（例如死亡重载场景）。
- **节点 `_ready` 顺序**：树里靠后的节点(如 HUD)比靠前的(如 Player)更晚 `_ready`，所以 Player 在自己的 `_ready` 里找不到 HUD —— 要"用到时再找"（延迟查找）。
- **场景里存的值会"霸占"脚本里的 `@export` 默认值**：在脚本里改了默认值却不生效，多半是该节点的 Inspector 里手动填过值（被写进了 `.tscn`）。解决：在 Inspector 里点该属性旁的**回退箭头 ↩**恢复成"听脚本的"，或删掉 `.tscn` 里那一行。
- **Godot 开着的场景/脚本标签页会被存回硬盘**：想从外部 `mv`/删一个 `.tscn`，要**先在 Godot 里关掉它的标签页**（或退出 Godot），否则它会"复活"。同理，被移走文件的脚本标签会报 `File not found` —— 关掉那个标签即可，不影响游戏运行。

## 历史备注
- **Boss（巨型锯齿战车）做过两版后已撤除**：先试了"伪3D 分层"（效果差，弃用），又改"逐帧动画"，最后整套连同第三波一起删掉。
- 遗留的 AI 素材仍在项目里，留作以后重做：`boss待机/`、`boss待机2/`（待机帧）、`boss_sawtank.png`、`boss_sawtank_parts_batch1/`、`BOSS_待机帧_生成方案.md`。
- 旧的 boss 实现（`boss.gd`/`boss.tscn`/抠好的 `boss_idle_frames/` 等）已备份在 `/tmp/boss_*`。以后重做建议直接用 **AnimatedSprite2D 逐帧**（待机帧已抠好可复用）。
