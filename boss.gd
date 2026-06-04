extends Area2D

# Boss「锯齿战车」第三波 —— 逐帧动画版。
# 现在：从上方开进场→停住、播放待机动画、挨打闪烁、血量归零爆炸。
# （开炮/受击/死亡等动画，等对应帧到齐后再加。）

# —— 进场 ——
@export var entry_speed := 220.0          # 从上方开进来的速度（像素/秒）
@export var target_y := 430.0             # 开到这个高度就停下（实际由 WaveSpawner 覆盖）

# —— 战斗 ——
@export var max_hp := 1200.0
@export var blink_hz := 8.0
@export var blink_persist := 0.12
@export var blink_brightness := 1.6
@export var score_reward := 1000

var _explosion_scene := preload("res://explosion.tscn")
@onready var _anim: AnimatedSprite2D = $Anim

var _hp := 0.0
var _dead := false
var _arrived := false
var _blink_timer := 0.0
var _blink_phase := 0.0

func _ready():
	add_to_group("enemy")
	_hp = max_hp
	area_entered.connect(_on_area_entered)
	# 播放待机循环（帧由 boss.tscn 的 SpriteFrames 提供）
	if _anim and _anim.sprite_frames and _anim.sprite_frames.has_animation("idle"):
		_anim.play("idle")

func _physics_process(delta):
	# 进场：从上方匀速开下来，到达目标高度就停
	if not _arrived:
		position.y += entry_speed * delta
		if position.y >= target_y:
			position.y = target_y
			_arrived = true

func _process(delta):
	_update_blink(delta)

# —— 被玩家子弹击中 ——
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

# —— 受击闪白 ——
func _update_blink(delta):
	if _blink_timer <= 0.0:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_anim.modulate = Color(1, 1, 1)
		_blink_phase = 0.0
		return
	_blink_phase += delta * blink_hz
	if fmod(_blink_phase, 1.0) < 0.5:
		_anim.modulate = Color(blink_brightness, blink_brightness, blink_brightness)
	else:
		_anim.modulate = Color(1, 1, 1)

# —— 死亡：放大爆炸 + 加分 + 消失 ——
func _die():
	var fx = _explosion_scene.instantiate()
	fx.global_position = global_position
	fx.scale = Vector2(5, 5)
	get_parent().add_child(fx)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(score_reward)
	queue_free()
