extends CharacterBody2D

@export var speed := 1500.0
@export var edge_margin := 20.0       # 空气墙：飞机中心离屏幕边至少这么多像素（约半架飞机宽，保证整机在屏幕内）

# 侧倾(banking)相关
@export var max_tilt_deg := 15.0       # 左右移动时机身最大倾斜角度（度）
@export var tilt_speed := 3.0          # 倾斜/回正的平滑速度（越大越快）
@onready var _sprite: Sprite2D = $Sprite2D   # 只旋转贴图，不动碰撞箱和发射方向

# 开火相关
@export var main_fire_rate := 0.17    # 主炮：每隔多少秒发一颗（越小越快）
@export var side_fire_rate := 0.11     # 副炮：每隔多少秒发一颗（越小越快）
@export var muzzle_offset := 260.0     # 主炮子弹从飞机中心往前(上)多少像素冒出来
@export var side_offset_x := 55.0      # 两门副炮离飞机中心左右各多远
@export var side_offset_y := 150.0      # 副炮口往前(上)多少像素
var _bullet_scene := preload("res://bullet.tscn")
var _side_scene := preload("res://副炮子弹.tscn")
var _main_cooldown := 0.0
var _side_cooldown := 0.0

# —— 血量相关 ——
@export var max_hearts := 3            # 总共几颗爱心
@export var invincible_time := 1.0     # 受伤后短暂无敌的秒数（避免一下被扣光）
@export var hit_shake_strength := 500.0 # 受伤时屏幕震动强度（越大越剧烈）
var _hearts := 0
var _invincible := 0.0
@onready var _hurtbox: Area2D = $Hurtbox   # 玩家受伤判定区
@onready var _main_sound: AudioStreamPlayer = $MainSound   # 主炮开火音效
@onready var _side_sound: AudioStreamPlayer = $SideSound   # 副炮开火音效
@export var main_volume_db := -30.0   # 主炮音效音量（dB，负数变小、正数变大）
@export var side_volume_db := -25.0   # 副炮音效音量（dB）
@onready var _roll: AnimatedSprite2D = $Roll   # 闪避翻滚动画（平时隐藏）

# —— 闪避(翻滚)相关 ——
@export var dodge_invincible := 0.55   # 闪避无敌持续秒数
@export var dodge_cooldown := 2.0      # 闪避冷却秒数（两次闪避的最短间隔）
var _dodge_cd := 0.0                   # 当前剩余冷却
var _dodging := false                  # 是否正在翻滚

func _ready():
	add_to_group("player")   # 让敌人(如 Side Reaper 的炮管)能找到我来瞄准
	# 游戏一开始，把飞机放到当前窗口的正中央
	position = get_viewport_rect().size / 2
	# 初始化血量（开局 3 颗爱心由 HUD 默认显示，不用在这里设）
	_hearts = max_hearts
	# 被敌方子弹或敌机碰到时触发
	_hurtbox.area_entered.connect(_on_hurt_area)
	# 翻滚动画播完 → 结束闪避，换回普通飞机
	_roll.animation_finished.connect(_end_dodge)
	# 应用脚本里设定的音效音量
	_main_sound.volume_db = main_volume_db
	_side_sound.volume_db = side_volume_db

func _physics_process(delta):
	# —— 移动：方向键 + WASD 都能用 ——
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
		int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	)
	direction = (direction + wasd).limit_length(1.0)   # 两种输入叠加，并限制最大不超过 1（斜向不会更快）
	velocity = direction * speed
	move_and_slide()

	# —— 空气墙：把飞机限制在屏幕范围内，飞不出去 ——
	var view: Vector2 = get_viewport_rect().size
	position.x = clamp(position.x, edge_margin, view.x - edge_margin)
	position.y = clamp(position.y, edge_margin, view.y - edge_margin)

	# —— 闪避：冷却倒计时 + 按空格触发 ——
	_dodge_cd -= delta
	if Input.is_action_just_pressed("ui_accept") and _dodge_cd <= 0.0 and not _dodging:
		_start_dodge()

	# —— 机身侧倾：向右移右倾、向左移左倾、松手平滑回正（翻滚时不做侧倾）——
	if not _dodging:
		var target_tilt := deg_to_rad(max_tilt_deg) * direction.x
		_sprite.rotation = lerp_angle(_sprite.rotation, target_tilt, tilt_speed * delta)

	# —— 无敌时间：受伤后短暂无敌，并让飞机闪烁提示 ——
	if _invincible > 0.0:
		_invincible -= delta
		# 半透明闪烁
		_sprite.modulate.a = 0.35 if fmod(_invincible * 10.0, 1.0) < 0.5 else 1.0
		if _invincible <= 0.0:
			_sprite.modulate.a = 1.0

	# —— 主炮自动开火（独立计时器）——
	_main_cooldown -= delta
	if _main_cooldown <= 0.0:
		_main_cooldown = main_fire_rate
		_shoot_main()

	# —— 副炮自动开火（独立计时器）——
	_side_cooldown -= delta
	if _side_cooldown <= 0.0:
		_side_cooldown = side_fire_rate
		_shoot_side()

func _start_dodge():
	_dodging = true
	_dodge_cd = dodge_cooldown          # 开始冷却
	_invincible = dodge_invincible      # 闪避期间无敌（复用受伤无敌机制）
	# 藏起普通飞机，显示并从头播放翻滚动画
	_sprite.visible = false
	_roll.rotation = _sprite.rotation   # 接着当前朝向开始，避免画面跳变
	_roll.visible = true
	_roll.frame = 0
	_roll.play("roll")

func _end_dodge():
	# 翻滚播完：换回普通飞机（无敌可能还剩一点，会继续闪烁提示）
	_dodging = false
	_roll.stop()
	_roll.visible = false
	_sprite.visible = true
	_sprite.modulate.a = 1.0

func _shoot_main():
	_main_sound.play()   # 播放主炮音效（max_polyphony 允许多发叠响，不会被掐断）
	# 主炮：从飞机正中间发射
	var bullet := _bullet_scene.instantiate()
	bullet.position = position + Vector2(0, -muzzle_offset)
	get_parent().add_child(bullet)

func _shoot_side():
	_side_sound.play()   # 播放副炮音效
	var parent := get_parent()

	# 左副炮
	var left := _side_scene.instantiate()
	left.position = position + Vector2(-side_offset_x, -side_offset_y)
	parent.add_child(left)

	# 右副炮
	var right := _side_scene.instantiate()
	right.position = position + Vector2(side_offset_x, -side_offset_y)
	parent.add_child(right)

func _on_hurt_area(area):
	# 无敌中不再扣血
	if _invincible > 0.0:
		return
	var hit := false
	if area.is_in_group("enemy_bullet"):
		area.queue_free()   # 敌弹打中后消失
		hit = true
	elif area.is_in_group("enemy"):
		hit = true          # 撞到敌机（敌机不消失）
	if hit:
		_take_damage()

func hit_by_enemy() -> void:
	# 供敌人(如 Side Reaper 激光)调用：无敌中则忽略，否则扣血
	if _invincible > 0.0:
		return
	_take_damage()

func _take_damage():
	_hearts -= 1
	# 扣血时再去找 HUD（此时一切都已就绪）并刷新爱心显示 + 闪烁提醒
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_hearts(_hearts)
		hud.flash_hearts(invincible_time)   # 爱心闪烁，持续整个无敌时间
	# 屏幕剧烈震动
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(hit_shake_strength)
	_invincible = invincible_time   # 进入短暂无敌
	if _hearts <= 0:
		_die()

func _die():
	# 血量归零：找到“游戏结束”画面，让它显示出来并冻住全场
	var go = get_tree().get_first_node_in_group("game_over")
	if go:
		go.show_game_over()
