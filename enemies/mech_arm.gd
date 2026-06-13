extends Area2D
# 机甲手臂电锯：攻击前先在落点弹出“警告箱”闪烁预警(warn_time)，然后旋转电锯快速突刺进来再缩回。
# 每 attack_interval 秒一轮(含预警)。是“危险障碍”，不吃子弹；属 "enemy" 组 → 碰到玩家造成接触伤害。

@export var arm_scale := 2.0           # 机械臂整体大小
@export var saw_spin_speed := 100.0    # 锯片旋转速度（弧度/秒）
@export var thrust_speed := 5000.0     # 突刺速度（像素/秒，越快越“砸”）
@export var retract_speed := 3500.0    # 缩回速度
@export var hold_time := 0.2           # 突刺到位后停留
@export var reach_fraction := 0.62     # 突刺深入到屏幕宽度的比例
@export var saw_offset := Vector2(500.0, 20.0)   # 锯片中心相对机械臂图中心的偏移（对准末端红点）
@export var saw_scale := 1.0           # 锯片大小（越大锯齿露出越多）
@export var saw_hit_radius := 130.0    # 锯片伤害判定半径（图像像素，随 arm_scale 缩放）
@export var warn_time := 2.5           # 攻击前警告箱闪烁预警时长（秒）
@export var attack_interval := 5.0     # 两次攻击的间隔（含预警，秒）
@export var warn_blink_hz := 6.0       # 警告箱闪烁频率（每秒亮灭次数）

var _saw_off_x := 0.0
var _facing := 1.0
var _phase := "warn"    # warn 预警 / thrust 突刺 / hold 停留 / retract 缩回 / wait 等待
var _t := 0.0
var _cycle_t := 0.0     # 本轮(从预警开始)累计时间，用来卡 5 秒间隔
var _rest_x := 0.0      # 屏外起始 x
var _thrust_x := 0.0    # 突刺到位 x
var _swing_y := 0.0     # 本轮的高度
var _retiring := false      # 是否正在退场（Side Reaper 全清后）
var _seen_reapers := false  # 是否见过 Side Reaper（避免它们还没生成就误判退场）

@onready var _saw: Sprite2D = $Saw
@onready var _arm: Sprite2D = $ArmSprite
@onready var _warn: Sprite2D = $Warning
@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("enemy")
	# 锯片画面 + 伤害判定圈，全由脚本设置
	_saw.position = saw_offset
	_saw.scale = Vector2(saw_scale, saw_scale)
	_col.position = saw_offset
	if _col.shape is CircleShape2D:
		_col.shape.radius = saw_hit_radius
	_saw_off_x = saw_offset.x * arm_scale
	_begin_cycle()

func _begin_cycle():
	var vw: float = get_viewport_rect().size.x
	var vh: float = get_viewport_rect().size.y
	_facing = 1.0 if randf() < 0.5 else -1.0
	scale = Vector2(arm_scale * _facing, arm_scale)   # 负数=水平镜像，让锯朝向进入方向
	var ty: float = randf_range(vh * 0.5, vh - 80.0)  # 下半屏随机高度
	_swing_y = ty - saw_offset.y * arm_scale          # 让锯片中心落在 ty
	var saw_r: float = 143.0 * saw_scale * arm_scale
	var off: float = _saw_off_x + saw_r + 80.0        # 含锯片半径，保证缩回时藏到屏外
	if _facing > 0.0:                                  # 从左来，向右突刺
		_rest_x = -off
		_thrust_x = vw * reach_fraction - _saw_off_x
	else:                                              # 从右来，向左突刺
		_rest_x = vw + off
		_thrust_x = vw * (1.0 - reach_fraction) + _saw_off_x
	# 预警阶段：手臂先藏到屏外起点；警告箱(top_level)显示在“落点”(攻击到位时机械臂的位置)
	position = Vector2(_rest_x, _swing_y)
	_arm.visible = false
	_saw.visible = false
	_warn.global_position = Vector2(_thrust_x, _swing_y)
	_warn.scale = Vector2(0.94 * arm_scale, 1.06 * arm_scale)   # 与机械臂等大
	_warn.rotation = 0.0
	_warn.visible = true
	_phase = "warn"
	_cycle_t = 0.0

func _reapers_left() -> bool:
	return not get_tree().get_nodes_in_group("side_reaper").is_empty()

func _physics_process(delta):
	_cycle_t += delta
	_saw.rotation += saw_spin_speed * delta
	# Side Reaper 全部被击败后 → 停止攻击，缩回离场
	if _reapers_left():
		_seen_reapers = true
	elif _seen_reapers and not _retiring:
		_retiring = true
		_warn.visible = false
		_phase = "retract"     # 立即收手，缩回屏外后消失
	match _phase:
		"warn":
			_warn.visible = fmod(_cycle_t * warn_blink_hz, 1.0) < 0.5   # 闪烁
			if _cycle_t >= warn_time:
				_warn.visible = false
				_arm.visible = true
				_saw.visible = true
				_phase = "thrust"
		"thrust":
			position.x = move_toward(position.x, _thrust_x, thrust_speed * delta)
			if is_equal_approx(position.x, _thrust_x):
				_phase = "hold"
				_t = 0.0
		"hold":
			_t += delta
			if _t >= hold_time:
				_phase = "retract"
		"retract":
			position.x = move_toward(position.x, _rest_x, retract_speed * delta)
			if is_equal_approx(position.x, _rest_x):
				if _retiring:
					queue_free()   # 已退到屏外 → 离场消失
				else:
					_phase = "wait"
		"wait":
			if _cycle_t >= attack_interval:
				_begin_cycle()
