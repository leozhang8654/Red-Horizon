extends Node2D

# 编队管理器：开局放一波 V 字 dust skimmer；等它们全部被消灭后，再放出 Side Reaper。

@export var enemy_scene: PackedScene         # 小兵场景(enemy.tscn)
@export var side_reaper_scene: PackedScene   # 清场后登场的精英敌机(side_reaper.tscn)
@export var count := 5                 # 一波几架(单数才有正中的尖)
@export var spacing_x := 500.0         # 左右每架的水平间距
@export var spacing_y := 230.0          # V 形每往外一层，向上抬多少
@export var apex_y := 700.0            # 最前(正中)那架悬浮的高度
@export var enemy_scale := 1.0       # 敌机大小(在原 0.33 基础上放大 2.5 倍)
@export var spawn_delay := 5.0       # 游戏开始后等几秒再放出这波敌人
@export var reaper_delay := 5.0      # 小兵全灭后，等几秒再放出 Side Reaper
@export var reaper_count := 3        # 一共放出几架 Side Reaper
@export var reaper_interval := 0.5  # 每架之间的出现间隔（秒）
@export var mech_arm_scene: PackedScene   # 机械臂电锯（第二波同场出现）
@export var mech_arm_count := 1           # 第二波放几条机械臂
@export var boss_scene: PackedScene       # 第三波 Boss（MANTIS-LUX 母舰）
@export var boss_delay := 2.5             # 第二波清光后，等几秒再放出 Boss

var _enemies: Array = []        # 记录这波生成的小兵
var _reapers: Array = []        # 记录第二波生成的 Side Reaper（用来判断是否全灭）
var _wave_done := false         # 是否已放出第一波
var _reaper_spawned := false    # Side Reaper 是否已登场
var _reapers_listed := false    # 第二波是否“全部”已生成（生成中途别误判全灭）
var _boss_spawned := false      # 第三波 Boss 是否已登场
var _gen := 0                   # “代次”计数：每次跳波 +1，用来作废残留的延时定时器

func _ready():
	add_to_group("spawner")     # 让暂停菜单的作弊功能能找到我
	# 先等 spawn_delay 秒，再生成这波敌机
	var g := _gen
	await get_tree().create_timer(spawn_delay, false).timeout
	if g != _gen:
		return                  # 期间发生了跳波 → 这次作废
	if not _wave_done:
		_spawn_wave()

func _spawn_wave():
	if enemy_scene == null:
		return
	var cx := get_viewport_rect().size.x / 2.0   # 屏幕水平中点
	var m := (count - 1) / 2.0                    # 中间那架的序号
	for i in range(count):
		var offset: float = i - m                # 离中心第几位(…-1,0,1…)
		var e := enemy_scene.instantiate()
		var tx: float = cx + offset * spacing_x
		# 越往两边，悬浮高度越靠上 → 正中最低、指向玩家，形成 ∨ 形
		var ty: float = apex_y - abs(offset) * spacing_y
		e.scale = Vector2(enemy_scale, enemy_scale)
		e.position = Vector2(tx, ty - 500.0)     # 先放在屏幕上方外面
		e.target_y = ty                          # 告诉它飞到哪悬停
		add_child(e)
		_enemies.append(e)                       # 记下来，用于判断是否全灭
	_wave_done = true

func _process(_delta):
	# —— 第一波 → 第二波：杂兵全灭后放出 Side Reaper ——
	if _wave_done and not _reaper_spawned:
		for e in _enemies:
			if is_instance_valid(e):
				return
		_reaper_spawned = true          # 先上锁，避免下一帧重复触发
		_spawn_reaper_after_delay()
		return
	# —— 第二波 → 第三波：Side Reaper 全灭后放出 Boss ——
	if _reapers_listed and not _boss_spawned:
		for r in _reapers:
			if is_instance_valid(r):
				return
		_boss_spawned = true            # 上锁
		_spawn_boss_after_delay()

func _spawn_reaper_after_delay():
	var g := _gen
	await get_tree().create_timer(reaper_delay, false).timeout
	if g != _gen:
		return                          # 期间发生了跳波 → 作废
	_spawn_reapers()

func _spawn_reapers():
	# 第二波同时放出机械臂电锯
	if mech_arm_scene != null:
		for i in range(mech_arm_count):
			add_child(mech_arm_scene.instantiate())
	if side_reaper_scene == null:
		_reapers_listed = true     # 没有 Reaper 场景也算“已全部生成”，好让 Boss 能接上
		return
	var g := _gen
	for i in range(reaper_count):
		if i > 0:
			await get_tree().create_timer(reaper_interval, false).timeout
			if g != _gen:
				return            # 期间跳波/重置 → 停止继续生成
		var r = side_reaper_scene.instantiate()
		add_child(r)
		_reapers.append(r)        # 记下来，用于判断第二波是否全灭
	_reapers_listed = true        # 全部生成完毕 → 之后才允许检测“全灭→出 Boss”

# —— 第三波：Boss 登场 ——
func _spawn_boss_after_delay():
	var g := _gen
	await get_tree().create_timer(boss_delay, false).timeout
	if g != _gen:
		return                    # 期间跳波/重置 → 作废
	_spawn_boss()

func _spawn_boss():
	if boss_scene == null:
		return
	add_child(boss_scene.instantiate())

# —— 开发者作弊：跳到第 n 波（1=杂兵编队, 2=Side Reaper, 3=Boss）。返回是否有效 ——
func jump_to_wave(n: int) -> bool:
	if n < 1 or n > 3:
		return false                    # 只有 1、2、3 波，其它无效
	_gen += 1                           # 作废所有进行中的延时定时器
	# 清掉当前所有敌人与敌弹
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		b.queue_free()
	_enemies.clear()
	_reapers.clear()
	if n == 1:
		_wave_done = false
		_reaper_spawned = false
		_reapers_listed = false
		_boss_spawned = false
		_spawn_wave()                   # 重新放杂兵波（死光后仍会按流程出 Reaper→Boss）
	elif n == 2:
		_wave_done = true
		_reaper_spawned = true          # 锁住，避免 _process 再次自动放 Reaper
		_reapers_listed = false         # 生成完会置 true，Reaper 死光后接 Boss
		_boss_spawned = false
		_spawn_reapers()
	else:
		_wave_done = true
		_reaper_spawned = true
		_reapers_listed = true          # 跳过第二波检测
		_boss_spawned = true            # 锁住，避免 _process 再次自动放 Boss
		_spawn_boss()
	return true
