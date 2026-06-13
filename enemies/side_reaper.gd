extends Area2D
# Side Reaper：瘦小、快速的侧翼敌机。
# 行为：从屏幕一侧斜线飞到另一侧(飞出屏幕外) → 等一会 → 换一条不同斜线飞回来，往复。
#       机头(尖端)始终朝向飞行方向；炮管在机身上独立旋转，始终瞄准玩家。
# 活动区域限制在屏幕“上 2/5”。（激光攻击第 2 步再加）

@export var max_hp := 25.0
@export var move_speed := 1600.0       # 斜线穿梭速度（要够慢以容纳约1秒的攻击，否则激光来不及发射）
@export var respawn_delay := 3      # 飞出屏幕后，过几秒再飞回来
@export var top_fraction := 0.45      # 活动区域 = 屏幕上 2/3
@export var top_margin := 60.0        # 离屏幕顶部至少留多少
@export var off_margin := 1000.0       # 出生/飞出在屏幕外多少像素
@export var aim_smooth := 8.0         # 炮管转向平滑度（越大锁得越快）
@export var score_value := 500.0        # 击毁得分

# —— 激光攻击 ——
@export var lock_time := 0.1         # 红线追踪锁定玩家多久（秒）
@export var windup_time := 0.5        # 锁定后预警时长（=音效蓄力到爆发的时间，对准发射）
@export var beam_time := 0.42         # 激光持续时间（=音效爆发后的余响长度）
@export var hit_width := 90.0         # 激光命中判定的半宽（像素）
@export var attack_volume_db := 0.0   # 攻击(激光)音效音量（dB）

# 受击闪烁
@export var blink_persist := 0.15
@export var blink_brightness := 1.5
@export var blink_hz := 8.0

var _explosion_scene := preload("res://enemies/side_reaper_explosion.tscn")   # Side Reaper 专属死亡爆炸
var _hp := 0.0
var _dead := false
var _blink_timer := 0.0
var _blink_phase := 0.0

# 穿梭状态
var _to := Vector2.ZERO
var _vel := Vector2.ZERO
var _waiting := false
var _wait_t := 0.0
var _side := 1.0      # 下次从哪侧进入（-1 左 / 1 右，每趟交替）

@onready var _body: Sprite2D = $Body
@onready var _barrel: Sprite2D = $Barrel
@onready var _muzzle: Marker2D = $Barrel/Muzzle   # 炮口位置
@onready var _aim_line: Line2D = $AimLine          # 红色瞄准线（top_level，按世界坐标驱动）
@onready var _laser: Sprite2D = $Laser             # 激光束（top_level）
@onready var _attack_sound: AudioStreamPlayer = $AttackSound   # 蓄力+发射 攻击音效

var _phase := "idle"            # 攻击阶段：idle / aiming / firing / done
var _t := 0.0                   # 阶段计时
var _locked_target := Vector2.ZERO # 锁定瞬间玩家所在的方位（世界坐标，固定不动）

func _ready():
	_hp = max_hp
	add_to_group("enemy")
	add_to_group("side_reaper")   # 让机械臂能统计"还有没有 Side Reaper 活着"
	_attack_sound.volume_db = attack_volume_db   # 应用脚本里设定的音量
	area_entered.connect(_on_area_entered)
	_side = 1.0 if randf() < 0.5 else -1.0   # 随机初始进入方向
	_start_run()

func _start_run():
	# 选一条新的斜线：从一侧屏外进入，飞到对侧屏外
	var vw: float = get_viewport_rect().size.x
	var vh: float = get_viewport_rect().size.y
	var y_lo: float = top_margin
	var y_hi: float = vh * top_fraction          # 上 2/5 的下边界
	_side = -_side                                # 交替进入方向
	var from_x: float
	var to_x: float
	if _side < 0:
		from_x = -off_margin                      # 从左进
		to_x = vw + off_margin                    # 向右飞出
	else:
		from_x = vw + off_margin                  # 从右进
		to_x = -off_margin                        # 向左飞出
	# 进出点高度各自随机（不同高度 → 不同斜率的斜线）
	var from_y: float = randf_range(y_lo, y_hi)
	var to_y: float = randf_range(y_lo, y_hi)
	position = Vector2(from_x, from_y)
	_to = Vector2(to_x, to_y)
	_vel = (_to - position).normalized() * move_speed
	rotation = _vel.angle() + PI / 2.0            # 机头(尖端)朝飞行方向
	_waiting = false
	_phase = "idle"
	_aim_line.visible = false
	_laser.visible = false

func _physics_process(delta):
	if _waiting:
		_wait_t -= delta
		if _wait_t <= 0.0:
			_start_run()
	else:
		position += _vel * delta
		# 越过终点(已飞出屏幕) → 进入等待，下趟换条斜线
		if (position - _to).dot(_vel) >= 0.0:
			_waiting = true
			_wait_t = respawn_delay
	_update_attack(delta)
	_update_blink(delta)

func _is_on_screen() -> bool:
	var s: Vector2 = get_viewport_rect().size
	return position.x >= 0.0 and position.x <= s.x

# 攻击状态机：在屏幕内时 锁定追踪(aiming)→固定预警(locked)→发射(firing)→打完(done)；飞出屏幕重置
func _update_attack(delta):
	if not _is_on_screen():
		_phase = "idle"
		_aim_line.visible = false
		_laser.visible = false
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	match _phase:
		"idle":
			_phase = "aiming"
			_t = 0.0
			_laser.visible = false
		"aiming":
			_aim_barrel_at(p)        # 炮管跟踪玩家
			_show_aim_line(p)        # 红色瞄准线（跟踪）
			_t += delta
			if _t >= lock_time:
				_locked_target = p.global_position   # 锁定玩家此刻所在的方位（世界坐标，固定）
				_attack_sound.play()                 # 蓄力音效开始（约0.5s后爆发，正好对上激光发射）
				_phase = "locked"
				_t = 0.0
		"locked":
			_aim_barrel_at_point(_locked_target)   # 炮口持续瞄准锁定方位
			_show_locked_line()      # 红线指向锁定方位 + 闪烁预警
			_t += delta
			if _t >= windup_time:
				_phase = "firing"
				_t = 0.0
				_aim_line.visible = false
		"firing":
			_aim_barrel_at_point(_locked_target)   # 炮口保持瞄准锁定方位
			_show_laser()            # 激光射向锁定方位
			_check_laser_hit(p)
			_t += delta
			if _t >= beam_time:
				_phase = "done"
				_laser.visible = false
		"done":
			pass                     # 本趟已打完，飞出屏幕后重置为 idle

func _aim_barrel_at(p):
	# 炮管世界朝向对准玩家；炮管是机身子节点，要减去机身自身旋转
	var dir: Vector2 = p.global_position - _barrel.global_position
	_barrel.rotation = (dir.angle() + PI / 2.0) - rotation

func _aim_barrel_at_point(pt: Vector2):
	# 炮管瞄准一个固定的世界点（锁定方位）
	var dir: Vector2 = pt - _barrel.global_position
	_barrel.rotation = (dir.angle() + PI / 2.0) - rotation

func _show_aim_line(p):
	var muzzle_w: Vector2 = _muzzle.global_position
	var dir: Vector2 = muzzle_w - _barrel.global_position
	if dir.length() < 1.0:
		return
	var dist: float = (p.global_position - muzzle_w).length()  # 只画到玩家中心
	_aim_line.visible = true
	_aim_line.global_position = muzzle_w
	_aim_line.rotation = dir.angle()
	_aim_line.points = PackedVector2Array([Vector2.ZERO, Vector2(dist, 0.0)])

func _show_locked_line():
	# 方向已锁定(不追踪)，红线贯穿屏幕，并快速闪烁提示“即将开火”
	var muzzle_w: Vector2 = _muzzle.global_position
	var dir: Vector2 = (_locked_target - muzzle_w).normalized()   # 始终指向锁定方位
	_aim_line.global_position = muzzle_w
	_aim_line.rotation = dir.angle()
	_aim_line.points = PackedVector2Array([Vector2.ZERO, Vector2(3000.0, 0.0)])
	_aim_line.visible = (fmod(_t * 12.0, 1.0) < 0.5)    # 闪烁预警

func _show_laser():
	var muzzle_w: Vector2 = _muzzle.global_position
	var dir: Vector2 = (_locked_target - muzzle_w).normalized()
	_laser.visible = true
	_laser.global_position = muzzle_w                   # 起点跟着炮口走
	_laser.rotation = dir.angle() + PI / 2.0            # 射向锁定方位

func _check_laser_hit(p):
	# 几何判定：玩家到激光中轴的垂直距离 < hit_width 且在炮口前方 → 命中
	var muzzle_w: Vector2 = _muzzle.global_position
	var dir: Vector2 = (_locked_target - muzzle_w).normalized()
	var to_p: Vector2 = p.global_position - muzzle_w
	var along: float = to_p.dot(dir)
	if along < 0.0:
		return
	var perp: float = (to_p - dir * along).length()
	if perp <= hit_width and p.has_method("hit_by_enemy"):
		p.hit_by_enemy()

func _update_blink(delta):
	if _blink_timer <= 0.0:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		modulate = Color(1, 1, 1)
		_blink_phase = 0.0
		return
	_blink_phase += delta * blink_hz
	if fmod(_blink_phase, 1.0) < 0.5:
		modulate = Color(blink_brightness, blink_brightness, blink_brightness)
	else:
		modulate = Color(1, 1, 1)

func _on_area_entered(area):
	if _dead:
		return
	if area.is_in_group("bullet"):
		_hp -= area.damage
		area.queue_free()
		_blink_timer = blink_persist
		if _hp <= 0.0:
			_dead = true
			_die()

func _die():
	var fx = _explosion_scene.instantiate()
	fx.global_position = global_position
	get_parent().add_child(fx)
	fx.global_rotation = global_rotation   # 让爆炸朝向与机身飞行方向一致
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(score_value)
	queue_free()
