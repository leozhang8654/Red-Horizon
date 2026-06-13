extends Area2D

# 小兵血量（被打中会扣，归零就被击溃）
@export var max_hp := 50.0
# 进场时从上方飞入的速度（像素/秒）
@export var entry_speed := 350.0
# 悬浮时上下轻微浮动的幅度（像素）
@export var bob_amplitude := 50.0
# 悬浮浮动的快慢
@export var bob_speed := 1.0
# 悬浮时左右摆动的幅度（像素），0 = 不左右摆
@export var sway_amplitude := 180.0
# 左右摆动的快慢（越大晃得越急）
@export var sway_speed := 1.7
# 到位后摆幅从 0 涨到满值需要几秒（从静到动的加速过程）
@export var sway_ramp_time := 2.0

# —— 俯冲相关（被编队管理器抽中后朝玩家冲一波）——
@export var dive_speed := 2000.0     # 冲刺速度（像素/秒）
@export var return_speed := 1200.0    # 冲完飞回队伍的速度（要比冲刺慢）
@export var aim_time := 0.5          # 冲刺前机头转向玩家用几秒（也是给玩家的预警时间）
@export var dive_overshoot := 180.0  # 冲过玩家身位多少像素才掉头返航
@export var turn_back_speed := 4.0   # 返航途中机头转回原朝向的快慢
# 受击闪烁频率（每秒亮灭多少次，越大闪得越快）
@export var blink_hz := 8.0
# 停止挨打后多久停止闪烁、恢复原色（秒）
@export var blink_persist := 0.15
# 闪烁时变亮的程度（1=不变，越大越白越亮）
@export var blink_brightness := 1.5

# —— 开火相关 ——
@export var can_shoot := true            # 是否会开火
@export var fire_rate := 1.5           # 每隔几秒打一轮（越小越快）
@export var bullet_speed := 1500.0        # 子弹向下飞的速度（像素/秒）
@export var shoot_volume_db := -30.0     # 开火音效音量（dB，负数变小、正数变大）
# 三个炮口相对敌机中心的位置（敌机本地坐标，y 正方向=朝玩家那侧）
@export var muzzle_left := Vector2(-50, 36)
@export var muzzle_center := Vector2(0, 124)
@export var muzzle_right := Vector2(50, 36)
var _bullet_scene := preload("res://enemies/dust skimmer amo.tscn")
var _explosion_scene := preload("res://effects/explosion.tscn")   # 死亡爆炸动画
var _fire_cd := 0.0

# 悬浮停留的高度（由编队管理器在生成时设置）
var target_y := 130.0
# 摆动的起始相位（由编队管理器设置，每架错开一点 → 整队呈波浪）
var sway_phase := 0.0

# 状态标签：我现在处于哪个动作阶段
enum State { ENTRY, HOVER, AIM, DIVE, RETURN }   # 进场/悬浮/瞄准/俯冲/返航

var _hp := 0.0
var _state := State.ENTRY   # 当前状态（从“进场”开始）
var _base_y := 0.0      # 悬浮中心高度
var _base_x := 0.0      # 悬浮中心横坐标（左右摆动绕着它晃）
var _time := 0.0        # 用于浮动的计时
var _aim_t := 0.0           # 瞄准阶段已经转了多久
var _dive_dir := Vector2.DOWN   # 俯冲方向（瞄准结束时定死，冲刺走直线）
var _dive_target := Vector2.ZERO   # 冲到哪算冲过头（玩家身后 overshoot 处）

@onready var _sprite: Sprite2D = $Sprite2D   # 受击闪烁只改贴图颜色
@onready var _shoot_sound: AudioStreamPlayer = $ShootSound   # 开火音效
var _blink_timer := 0.0   # 还要继续闪烁多久（>0 时就在闪）
var _blink_phase := 0.0   # 控制亮灭交替的相位

func _ready():
	_hp = max_hp
	add_to_group("enemy")
	_shoot_sound.volume_db = shoot_volume_db   # 应用脚本里设定的音量
	# 当有别的区域(子弹)碰到我时，调用 _on_area_entered
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	match _state:
		State.ENTRY:
			# —— 进场：从上方匀速飞下来，到达目标高度就停 ——
			position.y += entry_speed * delta
			if position.y >= target_y:
				position.y = target_y
				_base_y = target_y
				_base_x = position.x
				_state = State.HOVER
		State.HOVER:
			# —— 悬浮：上下轻浮动 + 左右摆动（相位错开 → 整队像波浪）——
			_time += delta
			# 起摆缓冲：头 sway_ramp_time 秒摆幅从 0 平滑涨到满值（从静到动）
			var ramp := clampf(_time / sway_ramp_time, 0.0, 1.0)
			ramp = ramp * ramp * (3.0 - 2.0 * ramp)   # 平滑曲线：起步柔、收尾柔
			position.y = _base_y + sin(_time * bob_speed + sway_phase) * bob_amplitude * ramp
			position.x = _base_x + sin(_time * sway_speed + sway_phase) * sway_amplitude * ramp
		State.AIM:
			# —— 瞄准：原地停摆，机头在 aim_time 秒内转向玩家 ——
			_aim_t += delta
			var p = get_tree().get_first_node_in_group("player")
			if p == null:
				_state = State.RETURN   # 玩家没了(死亡等) → 直接返航
			else:
				# 机头原本朝下(本地 +y)，所以目标角度要减去 90°
				var want: float = (p.global_position - global_position).angle() - PI / 2.0
				rotation = lerp_angle(0.0, want, clampf(_aim_t / aim_time, 0.0, 1.0))
				if _aim_t >= aim_time:
					# 瞄准结束：锁定方向，冲刺目标=玩家身后 dive_overshoot 处
					_dive_dir = (p.global_position - global_position).normalized()
					_dive_target = p.global_position + _dive_dir * dive_overshoot
					_state = State.DIVE
		State.DIVE:
			# —— 俯冲：沿锁定方向直线冲刺，冲过目标点就掉头 ——
			global_position += _dive_dir * dive_speed * delta
			if (_dive_target - global_position).dot(_dive_dir) <= 0.0:
				_state = State.RETURN
		State.RETURN:
			# —— 返航：以更慢的速度飞回队伍空位，机头边飞边转回来 ——
			var home := Vector2(_base_x, _base_y)
			rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-turn_back_speed * delta))
			var to_home := home - position
			if to_home.length() <= return_speed * delta:
				# 到家了：摆正机头，重新“从静到动”起摆（复用起摆缓冲）
				position = home
				rotation = 0.0
				_time = 0.0
				_state = State.HOVER
			else:
				position += to_home.normalized() * return_speed * delta

	# —— 受击闪烁：只要还在挨打就按频率亮灭，移开后停止 ——
	_update_blink(delta)

	# —— 开火：只在悬浮时开火（瞄准/俯冲/返航期间不打枪）——
	if _state == State.HOVER and can_shoot:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = fire_rate
			_fire()

# —— 俯冲对外接口：编队管理器抽中我时调用 ——
func can_dive() -> bool:
	return _state == State.HOVER and not _dead   # 只有安稳悬浮着的才能被抽中

func start_dive():
	if not can_dive():
		return
	_aim_t = 0.0
	_state = State.AIM

var _dead := false   # 是否已死亡（防止同一帧被多发子弹重复结算）

func _on_area_entered(area):
	if _dead:
		return   # 已经死了，后续子弹一律忽略，不再扣血/加分
	# 只对“子弹”组的东西反应
	if area.is_in_group("bullet"):
		_hp -= area.damage     # 扣血
		area.queue_free()      # 子弹打中后消失
		_blink_timer = blink_persist   # 中弹：刷新闪烁计时，让它继续闪
		if _hp <= 0.0:
			_dead = true       # 先标记死亡，确保下面的 _die() 只会执行一次
			_die()

func _update_blink(delta):
	if _blink_timer <= 0.0:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		# 一段时间没再挨打 → 停止闪烁，恢复原色
		_sprite.modulate = Color(1, 1, 1)
		_blink_phase = 0.0
		return
	# 按频率亮灭交替：前半个周期发白，后半个周期正常
	_blink_phase += delta * blink_hz
	if fmod(_blink_phase, 1.0) < 0.5:
		_sprite.modulate = Color(blink_brightness, blink_brightness, blink_brightness)
	else:
		_sprite.modulate = Color(1, 1, 1)

func _fire():
	_shoot_sound.play()   # 开火音效（一轮三发只响一次）
	# 从三个炮口各打一发子弹，加到上层场景里（不随敌机一起缩放/移动）
	for off in [muzzle_left, muzzle_center, muzzle_right]:
		var b := _bullet_scene.instantiate()
		b.speed = bullet_speed
		get_parent().add_child(b)
		b.global_position = to_global(off)   # 炮口本地坐标 → 世界坐标(含敌机缩放)

func _die():
	# 爆炸动画：在我死的位置生成一个，挂到上层场景（我消失了它还能播完）
	var fx = _explosion_scene.instantiate()
	fx.global_position = global_position
	get_parent().add_child(fx)
	# 加分：找到 HUD，告诉它加 100 分
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(200)
	# 然后消失（以后这里还能加掉落等）
	queue_free()
