extends Area2D

# 小兵血量（被打中会扣，归零就被击溃）
@export var max_hp := 50.0
# 进场时从上方飞入的速度（像素/秒）
@export var entry_speed := 350.0
# 悬浮时上下轻微浮动的幅度（像素）
@export var bob_amplitude := 50.0
# 悬浮浮动的快慢
@export var bob_speed := 1.0
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
var _bullet_scene := preload("res://dust skimmer amo.tscn")
var _explosion_scene := preload("res://explosion.tscn")   # 死亡爆炸动画
var _fire_cd := 0.0

# 悬浮停留的高度（由编队管理器在生成时设置）
var target_y := 130.0

var _hp := 0.0
var _arrived := false   # 是否已飞到悬浮位置
var _base_y := 0.0      # 悬浮中心高度
var _time := 0.0        # 用于浮动的计时

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
	if not _arrived:
		# —— 进场：从上方匀速飞下来，到达目标高度就停 ——
		position.y += entry_speed * delta
		if position.y >= target_y:
			position.y = target_y
			_base_y = target_y
			_arrived = true
	else:
		# —— 悬浮：在目标高度附近轻微上下浮动 ——
		_time += delta
		position.y = _base_y + sin(_time * bob_speed) * bob_amplitude

	# —— 受击闪烁：只要还在挨打就按频率亮灭，移开后停止 ——
	_update_blink(delta)

	# —— 开火：飞到悬浮位置后，按频率从三个炮口发射 ——
	if _arrived and can_shoot:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = fire_rate
			_fire()

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
		hud.add_score(100)
	# 然后消失（以后这里还能加掉落等）
	queue_free()
