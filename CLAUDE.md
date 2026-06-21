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
> **文件按"角色/职责"分到了各文件夹**。每个文件夹里：脚本(`.gd`)和场景(`.tscn`)直接放，图片在 `art/` 子文件夹，音效在 `sound/` 子文件夹。找文件时先想"它属于谁"。

**根目录（项目级文件，不要乱挪）**
- `main.tscn` — 主场景：背景、玩家、敌机生成器(WaveSpawner)、HUD、游戏结束(GameOver)、暂停菜单(PauseMenu)、屏幕震动相机(ShakeCamera)、背景音乐(BGM)、标题画面(StartScreen)、通关结算(Victory)。
- `project.godot` 项目配置 · `export_presets.cfg` 导出配置 · `icon.svg` 项目图标 · `publish.sh` 发布脚本 · `游戏封面*` 商店封面图。
- `default_bus_layout.tres` — 音频总线布局(Master/Music/SFX)。**必须留根目录**：Godot 靠固定默认路径 `res://default_bus_layout.tres` 自动加载它，一挪走自定义总线就失效。

**`player/` 玩家**
- `player.gd` — 玩家飞机：移动、空气墙、侧倾、主炮/副炮自动开火、血量与受伤无敌、闪避翻滚(Roll)、**开挂模式**(免伤+攻击力×3)。
- `player bullet.gd` / `bullet.tscn` 主炮子弹 · `副炮子弹.tscn` 副炮子弹。
- `art/` ship.png、子弹图、`dodge_frames/`(翻滚帧) · `sound/` 主炮/副炮音效。

**`boss/` 第三波 Boss(MANTIS-LUX 母舰)**
- `boss.gd` / `boss.tscn` — 出场无敌、悬停游移、四炮台瞄准、分阶段击破、三招(环形弹幕/炮台机枪/横扫激光)、实体阻挡。
- `boss_bullet.gd` — 通用子弹；`boss_bullet.tscn`=核心环形弹、`boss_turret_bullet.tscn`=炮台机枪弹。
- `barrel_explosion.tscn` 炮台爆炸(复用 `effects/explosion.gd`) · `boss_death_anim.gd`/`.tscn` Boss 死亡演出(5秒爆炸解体)。
- `art/` `boss_cut/`(主体/炮管/炮塔/弹/激光抠图)、`boss_death_frames/`(死亡动画帧)、炮台爆炸序列图 · `sound/` 激光/机关枪/圆环音效 · `raw/` `boss爆炸动画.mp4`(死亡动画源视频)。

**`enemies/` 杂兵**
- `dust skimmer.gd` / `enemy.tscn` — **第一波**小兵：V 字进场、悬浮、三炮口开火。
- `side_reaper.gd` / `side_reaper.tscn` — **第二波**精英；`side_reaper_explosion.tscn` 死亡爆炸。
- `mech_arm.gd` / `mech_arm.tscn` — **第二波**机械臂电锯(场地危险物)。
- `enemy_bullet.gd` / `dust skimmer amo.tscn` 敌方子弹(向下飞)。
- `art/` 各敌机贴图、`side_reaper/`、`side_reaper_boom/`(序列帧) · `sound/` 敌人攻击音效。

**`effects/` 通用特效**
- `explosion.gd` / `explosion.tscn` — 通用爆炸动画。`art/explosion_frames/` 帧图 · `sound/` 通用爆炸音效(`dust skimmer爆炸音效.wav`，名字带 dust 但其实是通用爆炸声)。

**`ui/` 界面**
- `hud.gd` — **顶部分数** + 左下角爱心血条；开挂时血条显示成 ♾️。
- `pause.gd` — 暂停菜单(ESC)：音量滑条；**开发者作弊**(密码 `123456` → 波数跳跃 + 开挂模式开关)。
- `game_over.gd` 游戏结束 · `start_screen.gd` 标题画面 · `victory.gd` 通关结算。
- `art/` 爱心、♾️、开关图、标题图 · `fonts/` 像素字体 + 分数字体(`.fnt` 用相对路径引图，三个字体文件必须同目录) · `sound/` 结算音效。

**`world/` 场景环境**
- `background.gd` 滚动背景(Parallax2D) · `scroller.gd` 向下滚动物(滚出底部循环回顶) · `art/` bg_top/bottom。

**`systems/` 系统**
- `wave_spawner.gd` — 编队管理：第一波杂兵 → 第二波(Reaper+机械臂) → **第三波 Boss**。含 `jump_to_wave(n)` 作弊跳波。
- `camera_shake.gd` — 屏幕震动(ShakeCamera)。

**`audio/` 全局音乐**
- `Skylark - Dancing Colours [ctI87ykv9UI].mp3` — 背景音乐(main.tscn 的 BGM 节点)。

> ⚠️ **要移动/重命名文件，务必连同它的 `.import`(图片/音频)或 `.uid`(脚本)小尾巴一起动**，并更新所有引用它的 `res://` 路径；最好直接在 Godot 的 FileSystem 面板里拖动(它会自动改引用)。

## 分组(group)约定（用于查找/碰撞判定）
- 玩家子弹 → `"bullet"`
- 敌方子弹 → `"enemy_bullet"`
- 敌机 → `"enemy"`
- HUD（血条+分数）→ `"hud"`
- 编队生成器 → `"spawner"`
- 游戏结束画面 → `"game_over"`
- 暂停菜单 → `"pause_menu"`

## 调试 / 作弊
- 游戏中按 **ESC** 暂停 → 密码框输入 `123456` → 出现"波数跳跃" → 输入 **1**(杂兵编队) / **2**(Side Reaper) / **3**(Boss) 跳到该波。
- 暂停菜单里还有**音乐/音效**两条音量滑条（分别控制 Music / SFX 总线，存到 `user://settings.cfg`；总线布局在 `default_bus_layout.tres`，背景音乐节点是 main.tscn 里的 BGM）。暂停时按**空格**继续游戏、按 **R** 重开。

## 音频（音乐/音效怎么管）
- 声音走两条总线(bus)：背景音乐 → **Music**，所有音效 → **SFX**（布局在 `default_bus_layout.tres`）。**新加任何 AudioStreamPlayer 都要在 Inspector 里把 Bus 设成 SFX**（音乐才用 Music），否则两条滑条管不到它。
- 背景音乐 = main.tscn 里的 **BGM** 节点（Skylark - Dancing Colours）：自动播放、循环（loop 开在 `.mp3.import` 里）、暂停时继续放（process_mode=Always）。
- **音乐响度天花板烤在 BGM 节点的 Volume dB**（现为 `-21.4`）：滑条满格=这个响度。想整体调高/调低音乐上限就调它，别动滑条逻辑。
- 滑条默认值：`pause.gd` 里的 `DEFAULT_MUSIC_VOLUME`（音乐，现为 1.0）；音效默认 1.0。
- 玩家的实际设置存在 `user://settings.cfg`（macOS 实际路径 `~/Library/Application Support/Godot/app_userdata/一号游戏/settings.cfg`），键：`audio/music`、`audio/sfx`。**存档优先于默认值**。

## 项目参数
- 视口分辨率：1152 × 648（见 `project.godot`）。

## 屏幕适配铁律（⚠️ 反复踩坑，动 UI/新场景前必读）
本游戏是**"窗口多大、画面就画多大"的自适应设计**（窗口=画布，按真实物理像素算视口；Retina 屏的真实绘制区域比看上去大很多）。这条是全局前提，违反它就会出现"画面只占左上角一块"或"主游戏整体错位/溢出裁切"。

- **🚫 绝对不准给 `project.godot` 加 `window/stretch/*` 设置**（mode / aspect 都不行）。用户已**明确否决过**；加了会让主游戏按"固定 1152×648 小画布再整体放大"渲染，导致写死像素的元素（如血条 192px）比例全错、标题溢出，还会炸编辑器运行。**改了发现主游戏错位，第一件事就是检查是不是混进了 stretch，有就删掉。**
- **🚫 不要用写死的固定像素铺满**（如 `offset_right = 1152`、`size = Vector2(1152, 648)` 当背景/底板）。在 Retina/最大化的大窗口里它只会盖住左上角一小块。
- **✅ 满铺背景/底板**：用满铺锚点——`anchors_preset = 15`、`anchor_right = 1.0`、`anchor_bottom = 1.0`、`grow_horizontal = 2`、`grow_vertical = 2`，让它四边贴窗口、跟着窗口长。
- **✅ 居中元素**（标题/提示）：锚到窗口中心——`anchor_left = 0.0 / anchor_right = 1.0`（横向占满好居中）+ `anchor_top = anchor_bottom = 0.5`，再用 `offset_top/bottom` 相对中心上下微调；配 `horizontal_alignment = 1`、`vertical_alignment = 1`。
- **✅ 代码里要用尺寸**：一律用 `get_viewport_rect().size`**运行时实时取真实窗口大小**，别把 1152/648 写死进逻辑（玩家活动范围、生成位置等都照此）。
- 背景滚动等需随窗口变化的，监听 `size_changed` 重新布局（`background.gd` 已是这么做的）。

## 容易踩的坑
- **改了贴图(PNG)但游戏里没变**：Godot 缓存了旧图。把 `.godot/imported/` 里对应的 `.ctex` 和 `.md5` 用 `mv` 移到 `/tmp`，再让我回到 Godot 自动重新导入（或右键 PNG → Reimport）。
- **图片"假透明"**（看着是棋盘格背景，其实背景被烤进像素里）：需要用边缘洪水填充(flood-fill)抠图，把浅色低饱和的背景设为透明。
- **在物理回调里删除带碰撞的节点会报错**：改用 `call_deferred` 延后执行（例如死亡重载场景）。
- **节点 `_ready` 顺序**：树里靠后的节点(如 HUD)比靠前的(如 Player)更晚 `_ready`，所以 Player 在自己的 `_ready` 里找不到 HUD —— 要"用到时再找"（延迟查找）。
- **场景里存的值会"霸占"脚本里的 `@export` 默认值**：在脚本里改了默认值却不生效，多半是该节点的 Inspector 里手动填过值（被写进了 `.tscn`）。解决：在 Inspector 里点该属性旁的**回退箭头 ↩**恢复成"听脚本的"，或删掉 `.tscn` 里那一行。
- **脚本会在 `_ready` 里覆盖子节点的 Inspector 值**：例如 side_reaper.gd 会把根节点导出的 `attack_volume_db` 写进 AttackSound——这时在 AttackSound 的 Inspector 里调音量没用，要调**根节点**上的导出变量。
- **玩家存档会"压住"代码里的默认值**：音量等设置存在 `user://settings.cfg`，改了脚本里的默认值却没效果，多半是存档里还躺着旧值——把存档里那一项改掉或删掉才能看到新默认值。
- **Godot 开着的场景/脚本标签页会被存回硬盘**：想从外部 `mv`/删一个 `.tscn`，要**先在 Godot 里关掉它的标签页**（或退出 Godot），否则它会"复活"。同理，被移走文件的脚本标签会报 `File not found` —— 关掉那个标签即可，不影响游戏运行。

## 历史备注
- **第三波 Boss = MANTIS-LUX 紫色蝠鲼母舰**（现行版本）：`boss.tscn` / `boss.gd`。出场期间无敌 → 顶部悬停左右游移；四个炮台用支点节点实时瞄准玩家。**分阶段击破**：先逐个打爆四个炮台（各有血量/贴合碰撞/受击闪烁/爆炸），全爆后才打开主体碰撞、进入主体可攻击阶段。**三招**：①核心环形弹幕 ②四炮台机枪散射 ③第二阶段中央横扫激光（整船侧倾、激光始终垂直机身）。Boss 是**实体**，玩家撞上去会被挡住并扣血。
- **旧 Boss（巨型锯齿战车 boss_sawtank）已彻底废弃删除**：当年试过"伪3D 分层"和"逐帧动画"两版均不理想，连同整批 AI 素材（`boss待机/`、`boss待机2/`、`boss_sawtank*`、`BOSS_待机帧_生成方案.md` 等）已在一次项目整理中**全部删除，不再保留**。
- **整理过项目**：清掉了所有没被场景/脚本引用的旧素材（源图、抠图中间图、被切过的源序列图、备份、生成动画的网页等）。现在根目录只保留在用文件。
