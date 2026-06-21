# 一号游戏 —— 完整机制说明（交接给另一个 AI）

> 本文目的：让任何没接触过本项目的 AI 在不读源码的情况下，也能完整理解这款游戏的**所有玩法机制、系统设计、关键参数与设计意图**。
> 所有数值均来自当前代码（`@export` 默认值；注意 `.tscn` 里手填的值会覆盖脚本默认值——下文标“代码默认”）。
> 引擎：**Godot 4.6**，GDScript。系统：macOS。视口分辨率：**1152 × 648**。作者是游戏开发新手。

---

## 0. 一句话概括

这是一款**纵向卷轴飞机射击（弹幕 STG）**游戏：玩家操控一架飞机自下而上推进，自动开火，躲避敌人弹幕与近战危险物，依次打过**三波敌人**（杂兵编队 → 侧翼精英 + 机械臂 → Boss 母舰），击毁 Boss 即通关，进入带评级（S/A/B/C）的结算页。整局**只有一个关卡、一条命体系（护盾格 + 核心血）**，强调走位、闪避与无伤。

---

## 1. 工程结构与运行方式

- **单场景架构**：整局游戏只有一个主场景 `main.tscn`。标题页、暂停菜单、游戏结束、通关结算都是这个场景里的 **CanvasLayer 覆盖层**，靠 `visible` 切换，**不做场景切换**。重开 = `reload_current_scene()`（重载整个 main.tscn）。
- **运行**：编辑器里 F5/▶ 跑主游戏；F6 跑当前场景。
- `main.tscn` 节点构成：滚动背景、玩家(Player)、编队生成器(WaveSpawner)、HUD、游戏结束(GameOver)、暂停菜单(PauseMenu)、屏幕震动相机(ShakeCamera)、背景音乐(BGM)、标题画面(StartScreen)、通关结算(Victory)。

### 文件夹职责（按“角色”分）
| 文件夹 | 管什么 |
|---|---|
| 根目录 | `main.tscn` 主场景、`project.godot`、`default_bus_layout.tres`（音频总线，必须留根目录）、导出/发布配置、封面图 |
| `player/` | 玩家飞机、主炮/副炮子弹、死亡爆炸、翻滚帧 |
| `enemies/` | 三种杂兵：dust skimmer（第一波）、side_reaper（第二波精英）、mech_arm（第二波机械臂）、敌方子弹 |
| `boss/` | 第三波 Boss（MANTIS-LUX 母舰）、Boss 子弹、炮台爆炸、死亡演出 |
| `effects/` | 通用爆炸动画 |
| `ui/` | HUD、暂停菜单、游戏结束、标题页、通关结算、护盾格 |
| `world/` | 滚动背景、向下滚动物 |
| `systems/` | 编队管理器(wave_spawner)、屏幕震动相机 |
| `audio/` | 背景音乐 mp3 |

---

## 2. 分组（group）约定 —— 系统间靠它互相查找/判定碰撞

| 分组名 | 谁在里面 | 用途 |
|---|---|---|
| `"player"` | 玩家 | 敌人/炮台瞄准玩家、激光命中判定 |
| `"bullet"` | 玩家主炮+副炮子弹 | 敌人识别“被玩家子弹打中” |
| `"enemy_bullet"` | 所有敌方子弹（含 Boss 环形弹/机枪弹） | 玩家受伤判定、护盾挡弹 |
| `"enemy"` | 所有敌机（含 Boss、机械臂） | 玩家子弹识别敌人、玩家撞击判定 |
| `"boss"` | Boss 本体 | 单独标记 |
| `"boss_solid"` | Boss 的实体碰撞节点(Solid) | 玩家撞上去被挡+扣血 |
| `"side_reaper"` | 第二波 Side Reaper | 机械臂统计“还有没有 Reaper 活着”来决定退场 |
| `"hud"` | HUD | 加分/血条/计时 |
| `"spawner"` | 编队生成器 | 作弊跳波 |
| `"camera"` | 震动相机 | 各处触发震屏 |
| `"game_over"` / `"pause_menu"` / `"start_screen"` / `"victory"` | 各 UI 覆盖层 | 互相避让、流程控制 |

> 设计模式：大量用 `get_tree().get_first_node_in_group(...)` 做**松耦合查找**，节点之间不持有直接引用。

---

## 3. 游戏流程（状态时间线）

```
启动 → 标题页(StartScreen)：全场 paused，"按空格开始"呼吸闪烁
   │  按空格
   ▼
解冻 → HUD 血条渐显(1.2s) + 计时器开始走
   │  spawn_delay = 5s 后
   ▼
第一波：5 架 dust skimmer V 字编队（每 5s 抽一架俯冲玩家）
   │  全灭后 reaper_delay = 5s
   ▼
第二波：3 架 Side Reaper（间隔 0.5s 登场）+ 1 条机械臂电锯（同场）
   │  Side Reaper 全灭后（机械臂随之退场）boss_delay = 2.5s
   ▼
第三波：Boss 母舰（MANTIS-LUX）
   │
   ├─ 玩家死亡 ──► 慢动作演出(1.2s) → "任务失败" → 冻结 → 空格重开
   │
   └─ Boss 击毁 ──► 死亡演出(~5s) → 玩家飞机"谢幕冲刺"飞出屏幕 → 通关结算页（评级 S/A/B/C）→ 空格重开
```

**关键：暂停/标题/结束/结算时全场 `get_tree().paused = true`。** 这些 UI 节点都设 `process_mode = ALWAYS`，所以冻结时它们自己还能动（动画、收按键）。HUD 也是 ALWAYS，所以暂停时分数滚动能继续，但它自己判断 `if not get_tree().paused` 来停掉计时。

---

## 4. 玩家系统（`player/player.gd`，CharacterBody2D）

### 4.1 移动
- **输入**：方向键 + WASD（两套叠加，`limit_length(1.0)`，斜向不会更快）。
- `speed = 1500`（像素/秒）。
- **空气墙**：飞机中心被 `clamp` 在屏幕内，离边至少 `edge_margin = 20`。
- **开局位置**：水平居中，高度 = `start_height_ratio = 0.78`（0=贴顶、1=贴底，0.78=偏下）。
- **侧倾(banking)**：左右移动时**只旋转贴图**（不动碰撞箱、不改发射方向），最大 `max_tilt_deg = 15°`，平滑速度 `tilt_speed = 3`。

### 4.2 自动开火（两门炮独立计时）
- **主炮**：从飞机正中向前发射，`main_fire_rate = 0.17s/发`，枪口偏移 `muzzle_offset = 260`。子弹 = `bullet.tscn`。
- **副炮**：左右各一门，`side_fire_rate = 0.11s/发`，左右偏移 `side_offset_x = 55`、前移 `side_offset_y = 150`。子弹 = `副炮子弹.tscn`。
- 子弹都加到**父节点**（不随飞机移动/缩放）。
- 音效：主炮 `main_volume_db = -30`，副炮 `side_volume_db = -25`（允许多发叠响）。

### 4.3 子弹（`player bullet.gd`，Area2D）
- 主炮/副炮子弹**共用同一脚本**（场景不同，参数不同）。
- 向上飞 `speed = 3000`，`damage = 1.0`（每发扣 1 点血）。飞出屏幕顶 100px 自毁。

### 4.4 血量体系：护盾格 + 核心血 + 受伤无敌
- `max_hearts = 5`：左下角显示 5 格**护盾**（不是爱心了，是盾牌图，见 `shield_pip.gd`）。
- `last_stand = true`：护盾打光后还有 **1 滴隐形“核心血”** 保命（总可承受 = 5 + 1 = 6 下）。
- **扣血逻辑**（`_take_damage`）：
  - 还有护盾格 → 扣 1 格，并在**受击方向**亮起弧形能量盾（见下）。
  - 护盾为 0 但核心血还在 → 核心血顶掉这一下（不死、**不亮护盾**）。
  - 护盾 0 且核心血用掉 → `_die()` 真正阵亡。
- **受伤无敌** `invincible_time = 1.0s`：受击后短暂无敌（防一下被扣光）。无敌期间飞机本体不闪，改由**护盾闪烁**提示。
- **受击惩罚**：每扣第 n 滴血扣 `50 + 50*n` 分（第1次 -100、第2次 -150、第3次 -200…越往后越痛），并震屏 `hit_shake_strength = 500`。

### 4.5 受击弧形护盾（视觉 + 挡弹）
- 受击瞬间在**攻击来向**亮出一张弧形能量盾贴图（`玩家护盾.png`），持续整个无敌时间。
- 参数：`shield_radius = 200`（大小/距离）、`shield_arc_deg = 120°`（挡弹扇形宽度）、`shield_blink_hz = 9`（每秒闪几次）、`shield_dim_alpha = 0.2`（闪到最暗的亮度）、`shield_block_margin = 24`（挡弹距离容差）。
- **挡弹机制**：无敌期间，落在护盾扇形（同朝向、`shield_arc_deg/2` 半角内、距离 < `shield_radius + margin`）的敌弹被 `queue_free()` 消掉。即“受击后短时间内，朝你这一侧打来的子弹会被盾挡下”。

### 4.6 闪避翻滚（Roll）
- 按 **空格（ui_accept）** 触发（注意：触发写在 `_unhandled_input`，避免“暂停→空格继续”那一下被误当成闪避——因为暂停菜单会先 `set_input_as_handled()` 把空格吃掉）。
- `dodge_invincible = 0.55s`（翻滚无敌，复用受伤无敌机制）、`dodge_cooldown = 2.0s`（冷却）。
- 翻滚时隐藏普通飞机贴图、播放翻滚动画(`$Roll`)，动画播完自动结束。
- **冷却条**：飞机下方一条横条（位置由 `DodgeBarAnchor` 锚点决定，可编辑器拖动），只在冷却中显示，冷却走完渐隐。宽 120、高 14，渐显速度 6。

### 4.7 撞击 Boss 实体
- 玩家是 CharacterBody2D，`move_and_slide()` 后检查碰撞：撞到 `boss_solid` 组 → 被挡住 + 调 `hit_by_enemy()` 扣血（无敌期间自动忽略）。

### 4.8 死亡演出（`_die`）
- 在飞机位置生成 `player_death.tscn` 爆炸（自带音效），藏飞机、停物理/开火/受伤判定。
- 等 **1.3s**（9 帧 ÷ 7fps）后弹出“游戏结束”画面。
- `_dying` 标志防重复触发。

### 4.9 通关谢幕冲刺（`start_finale`，由 victory.gd 调用）
两段式变速演出，玩家**交出操控**、**完全无敌**、**直接改坐标不走碰撞**（免得被 Boss 残骸挡住）：
1. **阶段0**：用正常速度飞回开局出生点（途中自然侧倾）。
2. **阶段1 蓄力**：`finale_ramp_time = 1.0s` 内小加速度 `finale_slow_accel = 350` 缓缓飘起；whoosh 音效提前 `whoosh_climax = 0.85s` 起播（高潮压在爆发瞬间）。
3. **阶段1 爆发**：加速度猛增到 `finale_burst_accel = 9000`，一瞬间窜出屏幕顶，爆发瞬间震屏 `finale_burst_shake = 300`。

### 4.10 开挂模式（开发者作弊）
- `set_god_mode(true)`：**完全免伤**（`_take_damage` 直接 return，不扣血/不罚分/不震屏）+ **攻击力 ×`god_damage_mult`(=3)**（主副炮 damage 都乘 3）。
- HUD 血条显示成 **♾️**（`set_infinite_hearts`）。
- 在暂停菜单作弊面板里开关（见 §8.2）。

### 玩家关键参数速查
| 参数 | 默认值 | 作用 |
|---|---|---|
| speed | 1500 | 移动速度 |
| main_fire_rate / side_fire_rate | 0.17 / 0.11 | 开火间隔(秒) |
| max_hearts | 5 | 护盾格数 |
| last_stand | true | 是否有核心血保命 |
| invincible_time | 1.0 | 受伤无敌时长 |
| dodge_invincible / dodge_cooldown | 0.55 / 2.0 | 闪避无敌 / 冷却 |
| god_damage_mult | 3.0 | 开挂攻击倍率 |

---

## 5. 敌人系统

### 5.1 第一波：Dust Skimmer 杂兵（`enemies/dust skimmer.gd`，Area2D）
状态机：**ENTRY 进场 → HOVER 悬浮 → AIM 瞄准 → DIVE 俯冲 → RETURN 返航 → 回 HOVER**。

- `max_hp = 50`（被玩家子弹打中扣 `damage`，归零爆炸）。死亡爆炸用 `effects/explosion.tscn`，**击杀 +200 分**。
- **进场**：从屏幕上方匀速飞入 `entry_speed = 350`，到 `target_y`（由编队设定）停下。
- **悬浮**：上下浮动（`bob_amplitude=50, bob_speed=1`）+ 左右摆动（`sway_amplitude=180, sway_speed=1.7`）；`sway_ramp_time=2s` 起摆缓冲（从静到动）；每架相位错开 → 整队呈波浪。
- **开火**（仅悬浮时）：三炮口齐射，`fire_rate=1.5s/轮`，子弹向下 `bullet_speed=1500`。子弹 = `dust skimmer amo.tscn`。
- **俯冲**：被编队抽中后，`aim_time=0.5s` 内机头转向玩家（也是预警），然后锁定方向以 `dive_speed=2000` 直线冲，冲过玩家身后 `dive_overshoot=180` 掉头，以 `return_speed=1200` 返航归位。
- 受击白光闪烁：`blink_hz=8, blink_persist=0.15, blink_brightness=1.5`。

### 5.2 第二波：Side Reaper 侧翼精英（`enemies/side_reaper.gd`，Area2D）
行为：**从屏幕一侧斜线飞到对侧屏外 → 等 `respawn_delay=3s` → 换一条不同斜线飞回**，往复穿梭。活动区限制在屏幕**上 45%**（`top_fraction=0.45`，离顶至少 `top_margin=60`）。

- `max_hp = 25`，`move_speed = 1600`（注释：要够慢以容纳约 1 秒的激光攻击）。**击杀 +500 分**。死亡爆炸 = `side_reaper_explosion.tscn`。
- 机头始终朝飞行方向；**炮管独立旋转始终瞄准玩家**（`aim_smooth=8`）。
- **激光攻击**（只在屏幕内时）状态机：`aiming 追踪锁定 → locked 固定预警(红线闪) → firing 发射激光 → done`。
  - `lock_time=0.1`（追踪锁定）→ 锁定瞬间记下玩家**当下方位**（固定不动）+ 播蓄力音效 → `windup_time=0.5`（红线闪烁预警）→ `beam_time=0.42`（激光持续）。
  - **命中判定**：玩家到激光中轴垂直距离 < `hit_width=90` 且在炮口前方 → 调 `hit_by_enemy()`。
  - 激光打的是**锁定瞬间的方位**，不是实时追踪——玩家走位可躲。

### 5.3 第二波：Mech Arm 机械臂电锯（`enemies/mech_arm.gd`，Area2D）
**危险障碍物**：不吃子弹（无血量），属 `enemy` 组 → 撞到玩家造成接触伤害。
状态机：**warn 预警 → thrust 突刺 → hold 停留 → retract 缩回 → wait 等待 → 循环**。

- 每轮先在**落点**弹出警告箱闪烁 `warn_time=2.5s`（`warn_blink_hz=6`），然后旋转电锯（`saw_spin_speed=100`）以 `thrust_speed=5000` 快速突刺进屏（深入到屏宽 `reach_fraction=0.62`），停留 `hold_time=0.2`，再以 `retract_speed=3500` 缩回。每 `attack_interval=5s` 一轮。
- 整体大小 `arm_scale=2.0`；锯片伤害判定半径 `saw_hit_radius=130`（随缩放）。
- 每次随机从左/右进入（负 scale 水平镜像），随机下半屏高度。
- **退场逻辑**：监测 `side_reaper` 组——Side Reaper 全部死亡后立即收手、缩回屏外消失（`_seen_reapers` 防止 Reaper 还没生成就误判）。

### 5.4 敌方子弹（`enemies/enemy_bullet.gd`，Area2D）
- 杂兵子弹：只向下飞 `speed=1000`（可被发射者覆盖），飞出屏幕底自毁。属 `enemy_bullet` 组。

---

## 6. 第三波 Boss：MANTIS-LUX 紫色蝠鲼母舰（`boss/boss.gd`，Area2D）

### 6.1 出场与移动
- 开局藏在屏幕上方外，匀速压入 `enter_speed=230`，到 `hover_y=550` 悬停。**压入期间完全无敌**（炮台和主体都打不动）。
- 就位后**正弦左右游移**：幅度 `drift_x=650`，速度 `drift_speed=0.3`。

### 6.2 分阶段击破（核心设计）
- `max_hp = 300`（玩家子弹每发约扣 1）。
- **第一阶段**：主体碰撞**关闭**，本体打不动；只能**逐个打爆四个炮台**。
  - 四个炮台：`BarrelLeftPivot / BarrelRightPivot / DroneLeftPivot / DroneRightPivot`（支点节点 + 炮台图 + 炮口 Muzzle + Hit 碰撞）。
  - 每个炮台 `turret_hp=50`，打爆 **+`turret_score=800` 分**，原地爆炸（`barrel_explosion.tscn`）+ 震屏 250。
  - 炮台**实时瞄准玩家**（`turret_aim=true`，`turret_aim_smooth=6`）。
- **四炮台全爆 → `_enter_body_phase()`**：打开主体碰撞（延后执行避开物理回调限制），进入**第二阶段**，主体才可被攻击掉血。
- 主体血量打光 → `_die()`：播 5 秒死亡演出、加 `score_value=10000` 分、通知 victory。
- 受击白光：`blink_persist=0.06, blink_brightness=1.6`。

### 6.3 三招攻击
1. **环形弹幕**（`ring_attack`，全程）：从核心 RingCore 每 `ring_interval=1.0s` 向四周喷一圈，`ring_count=10` 颗，速度 `ring_bullet_speed=1000`，每圈整体转 `ring_spin_deg=20°`（让缝隙错开、不留死缝）。子弹 = `boss_bullet.tscn`。
2. **四炮台机枪散射**（`mg_attack`，第一阶段为主）：每个活着的炮台从炮口朝玩家连发——每轮 `mg_burst=6` 颗、每颗间隔 `mg_rate=0.09`、两轮停顿 `mg_interval=2.2`、随机散布 `mg_spread_deg=7°`，速度 `mg_bullet_speed=650`。子弹 = `boss_turret_bullet.tscn`。炮台全灭后不再响机枪声。
3. **中央横扫激光**（`laser_attack`，**仅第二阶段**主体暴露后）：
   - 实现巧思：**整艘船绕中心侧倾**，激光从机身正下方 CoreMuzzle 沿机身轴“垂直”射出；船身从 `-laser_arc_deg` 摆到 `+laser_arc_deg`（=45°），激光跟着横扫 → 既垂直机身又横扫全屏。
   - 阶段：`idle 间隔(laser_cooldown=2s) → warn 预警(laser_warn_time=1.6s，船身摆到起始角+红线闪) → sweep 横扫(laser_sweep_time=5.5s)`。每趟随机左→右或右→左。
   - 命中判定半宽 `laser_hit_width=140`；激光音效用 pitch 拉伸正好卡满横扫时长。

### 6.4 Boss 死亡演出（`boss/boss_death_anim.gd`，AnimatedSprite2D）
- 播 `boss_death_frames/` 的 **76 帧**爆炸解体动画（15fps，约 5 秒），按真机身显示宽度缩放（动画里 Boss 宽 543px 为基准），继承当下侧倾角。
- 期间持续震屏 + 连环爆炸音；第 `burst_frame=9` 帧解体瞬间来一记大震 `burst_shake=800`；周期性小震 `shake_strength=220`（间隔 0.45s）；第 `quiet_frame=45` 帧起收尾安静；音效音调 `sound_pitch=0.7`（低沉）。播完自删。

---

## 7. 编队管理器（`systems/wave_spawner.gd`，Node2D）

负责三波生成与衔接，靠“记录生成的敌人 + 每帧检查是否全灭”推进。

- **第一波**：`spawn_delay=5s` 后生成 `count=5` 架 V 字编队（`spacing_x=500` 水平间距、`spacing_y=230` 每层上抬、`apex_y=700` 最前那架高度）。每 `dive_interval=5s` 从“安稳悬浮”的小兵里**随机抽一架俯冲**。
- **第一→二波**：杂兵全灭 → `reaper_delay=5s` → 生成 `reaper_count=3` 架 Side Reaper（间隔 `reaper_interval=0.5s`）+ `mech_arm_count=1` 条机械臂。
- **第二→三波**：Side Reaper 全灭 → `boss_delay=2.5s` → 生成 Boss。
- **跳波作弊** `jump_to_wave(n)`：n=1 杂兵 / 2 Reaper / 3 Boss。用 `_gen` “代次计数”作废所有进行中的延时定时器，清场后重建该波（且后续波次仍会按流程接上）。

---

## 8. UI 系统（`ui/`）

### 8.1 HUD（`hud.gd`，CanvasLayer）
- **左上角分数**：6 位前导零街机记分牌（`%06d`）。分数滚动追分：不管加减多少，都用 `score_roll_duration=1.5s` 滚完；加分白色往上滚、减分红色往下滚；负分显示红色无负号。
- **左上角计时器**：`分:秒` 格式（`01:23`），只在游戏开始后走、暂停不走、Boss 死亡瞬间停表。
- **左下角护盾血条**：动态生成 `max_hearts` 格护盾（`shield_pip.gd`），受伤闪烁提醒（`flash_hearts`），剩最后 1 格闪红警告。开挂时藏护盾、显示 ♾️。标题页期间血条藏起，开局渐显 `hearts_fade_in_duration=1.2s`。
- 对外接口：`add_score / set_hearts / set_max_hearts / flash_hearts / set_infinite_hearts / stop_timer / snap_score / get_score / get_time / get_time_text`。

#### 护盾格（`shield_pip.gd`，Control）
- 三态贴图：`shield_full`（有血亮青）、`shield_empty`（掉了暗壳，**直接熄灭不隐藏，格子留原位**）、`shield_warn`（红，剩最后一格时叠在亮青盾上脉动闪，`warn_speed=8`）。

### 8.2 暂停菜单（`pause.gd`，CanvasLayer）
- **ESC** 开暂停（冻全场）；**空格**继续；**R** 重开（先解冻再 `reload_current_scene`）。这两键用 `_input` 优先拦截，即使焦点在密码框也生效，并 `set_input_as_handled()` 防止漏给“闪避”。
- ESC 开暂停时会避让：游戏结束/标题/结算页正显示时不插手。
- **音量**：两条滑条分管 **Music / SFX** 总线，实时改 `set_bus_volume_db(linear_to_db(v))`，拉到 0 静音；存到 `user://settings.cfg`（键 `audio/music`、`audio/sfx`，**存档优先于默认值**）。音乐默认 `DEFAULT_MUSIC_VOLUME=1.0`。
- **开发者作弊**：密码框输入 **`123456`** → 出现作弊面板：
  - **波数跳跃**：输 1/2/3 跳到对应波。
  - **开挂模式开关**：转告玩家 `set_god_mode()`（免伤 + 攻击 ×3 + ♾️）。

### 8.3 游戏结束（`game_over.gd`，CanvasLayer）
- 玩家死亡触发**慢动作演出**：`Engine.time_scale` 从 1 渐降到 `min_time_scale=0.05`（世界越来越慢，持续 `slowmo_duration=1.2s` 真实秒），“任务失败”字幕从 `title_start_scale=0.2` 缓出推到最大，黑幕渐深。推满那刻 `Engine.time_scale=1.0` 复位 + 全场 `paused=true` 冻结。
- 显示本局得分（`hud.snap_score()` 定格）。空格/回车重开。

### 8.4 标题页（`start_screen.gd`，CanvasLayer）
- 启动即冻全场，“按空格开始”呼吸闪烁（`sin(_t*4)`）。空格 → 收起 + 解冻 + 通知 HUD 渐显血条。

### 8.5 通关结算（`victory.gd`，CanvasLayer）—— 计分与评级核心
Boss 死亡瞬间 `boss_defeated()` 被 boss.gd 调用，时间线：
1. 立刻 `hud.stop_timer()` 停表（用时只算到击杀那刻）。
2. 等 `finale_delay=3.5s`（爆炸转入碎片飞散）→ 让玩家飞机 `start_finale()` 谢幕冲刺。
3. 再等到 `show_delay=7.0s` 总时点 → 亮结算页。
4. 保险：若玩家在爆炸那几秒被流弹打死，按“任务失败”算，结算页不出。

**计分公式**：
```
时间分 = round((time_par_seconds - 实际秒数) * time_points_per_sec)
最终得分 = 击破得分(含所有击杀+炮台+Boss) + 时间分
```
- `time_par_seconds = 145`（2:25 基准线），`time_points_per_sec = 20`（每快/慢 1 秒 ±20 分）。

**评级线**（与基准线配套校准，锚点 S=无伤+1:35）：
| 评级 | 门槛 | 含义 |
|---|---|---|
| S | ≥ `rank_s` = 16700 | 无伤 + 1:35 的精确得分 |
| A | ≥ `rank_a` = 15900 | 掉 1 心 + 2:10 |
| B | ≥ `rank_b` = 14700 | 掉 2 心 + 3:00 附近 |
| C | 低于 B | —— |

> ⚠️ 若改了 `time_par_seconds`，三条评级线要重新校准。

**演出**：标题推近(`push_duration=0.6`) → 结算清单逐行弹出(`row_interval=0.45`，每行一声“叮”) → 最终得分从 0 滚到位(`final_roll_duration=1.0`) → 评级章“砸”下来(`stamp_*`，带震页) → 历史最高/新纪录 → 提示语呼吸闪烁。
- **无伤判定**：`player.took_no_damage()`（`_hearts >= max_hearts`）→ 显示 PERFECT。
- **历史最高分**：存 `user://records.cfg`（`record/best_score`），破纪录显示金色“新纪录！”。
- 空格/回车再来一局。

---

## 9. 音频系统

- **两条总线**：背景音乐 → **Music**，所有音效 → **SFX**（布局在 `default_bus_layout.tres`，必须留根目录，Godot 靠固定路径自动加载）。
- **新加任何 AudioStreamPlayer 都要在 Inspector 把 Bus 设成 SFX**（音乐才用 Music），否则两条滑条管不到它。
- **背景音乐** = main.tscn 的 BGM 节点（Skylark - Dancing Colours）：自动播放、循环、暂停时继续放（process_mode=Always）。**响度上限烤在 BGM 节点的 Volume dB（现 -21.4）**，滑条满格=这个响度。
- 玩家设置存 `user://settings.cfg`，**存档优先于代码默认值**。

---

## 10. 特效与表现层

- **通用爆炸**（`effects/explosion.gd`）：一次性 AnimatedSprite2D，播一遍删自己，触发震屏 100；若音效还在响等放完再删（防掐断）。dust skimmer 和 Side Reaper 死亡、玩家死亡、炮台爆炸都基于它或其变体。
- **屏幕震动相机**（`systems/camera_shake.gd`，Camera2D）：固定屏幕中心，`shake(strength)` 取较大值（连环爆炸叠加不抵消），**只上下抖**，`decay=12` 衰减平息。
- **滚动背景**（`world/background.gd`，Parallax2D）：上下两段无缝循环向下滚 `scroll_speed=60`，按窗口宽度自适应缩放（含网页版窗口被浏览器撑大后重铺）。
- **向下滚动物**（`world/scroller.gd`，AnimatableBody2D）：滚出底部后跳回顶部循环，`scroll_speed=150`。

---

## 11. 关键技术约定与“坑”（接手必读）

- **`.tscn` 里手填的值会覆盖脚本 `@export` 默认值**：改脚本默认值不生效，多半是 Inspector 里填过——点属性旁回退箭头 ↩ 或删 `.tscn` 那行。
- **脚本会在 `_ready` 覆盖子节点 Inspector 值**：如 side_reaper 把根节点的 `attack_volume_db` 写进 AttackSound——调音量要调**根节点**导出变量。
- **存档压住默认值**：音量/最高分存在 `user://`，改代码默认值没效果就是存档里有旧值。
- **物理回调里删带碰撞节点会报错**：用 `call_deferred` / `set_deferred`（Boss 开主体碰撞、死亡重载都这么做）。
- **节点 `_ready` 顺序**：树里靠后的（HUD）比靠前的（Player）晚 ready，所以查找 HUD 要“用到时再找”或 `call_deferred`。
- **改 PNG 没变**：Godot 缓存了旧图，删 `.godot/imported/` 对应 `.ctex`/`.md5` 重新导入。
- **改文件名/移动文件**：在 Godot 的 FileSystem 面板里操作（会自动改引用），且要连 `.import`/`.uid` 小尾巴一起动。
- **暂停恢复时的空格**：暂停菜单 `set_input_as_handled()` 吃掉空格，所以闪避触发放在 `_unhandled_input` 而非每帧轮询，避免“继续游戏”那下误触发闪避。

---

## 12. 历史背景

- **当前 Boss = MANTIS-LUX 紫色蝠鲼母舰**（`boss.tscn`/`boss.gd`）。
- **旧 Boss（巨型锯齿战车 boss_sawtank）已彻底废弃删除**：试过“伪 3D 分层”和“逐帧动画”两版均不理想，连同整批素材已删除。
- 项目已整理：清掉所有未被引用的旧素材，根目录只留在用文件。
- 已发布到 itch.io（leo8654.itch.io，名为 Red Horizon），`publish.sh` 一键发布。

---

*文档生成时间：2026-06-15。数值以仓库当前 `.gd` 脚本的 `@export` 默认值为准；运行时实际值可能被 `.tscn` Inspector 或 `user://` 存档覆盖。*
