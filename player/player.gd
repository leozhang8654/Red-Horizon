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
var _bullet_scene := preload("res://player/bullet.tscn")
var _side_scene := preload("res://player/副炮子弹.tscn")
var _main_cooldown := 0.0
var _side_cooldown := 0.0

# —— 血量相关 ——
@export var max_hearts := 5           # 总共几颗爱心
@export var invincible_time := 1.0     # 受伤后短暂无敌的秒数（避免一下被扣光）
@export var hit_shake_strength := 500.0 # 受伤时屏幕震动强度（越大越剧烈）
var _hearts := 0
var _invincible := 0.0
var _god_mode := false   # 开发者作弊：开挂模式（暂停菜单作弊面板里开关）
@export var god_damage_mult := 3.0   # 开挂模式的攻击力倍数（主副炮都乘这个数）
@onready var _hurtbox: Area2D = $Hurtbox   # 玩家受伤判定区
@onready var _main_sound: AudioStreamPlayer = $MainSound   # 主炮开火音效
@onready var _side_sound: AudioStreamPlayer = $SideSound   # 副炮开火音效
@export var main_volume_db := -30.0   # 主炮音效音量（dB，负数变小、正数变大）
@export var side_volume_db := -25.0   # 副炮音效音量（dB）
@onready var _roll: AnimatedSprite2D = $Roll   # 闪避翻滚动画（平时隐藏）

# —— 闪避(翻滚)相关 ——
@export var dodge_invincible := 0.55   # 闪避无敌持续秒数
@export var dodge_cooldown := 2.0      # 闪避冷却秒数（两次闪避的最短间隔）

# 开局时飞机在屏幕里的"高度位置"：0=贴屏幕顶、0.5=正中、1=贴屏幕底。调大=飞机更靠下
@export var start_height_ratio := 0.78
var _dodge_cd := 0.0                   # 当前剩余冷却
var _dodging := false                  # 是否正在翻滚

# —— 通关谢幕演出（两段式变速：先蓄力缓加速 → 突然爆发猛加速）——
@export var finale_ramp_time := 1.0    # 蓄力阶段时长(秒)：缓缓抬升、憋足推力。调大=憋得更久
@export var finale_slow_accel := 350.0   # 蓄力阶段加速度(像素/秒²)：小，慢慢飘起来
@export var finale_burst_accel := 9000.0 # 爆发阶段加速度(像素/秒²)：大，一瞬间窜出屏幕
@export var finale_burst_shake := 300.0  # 爆发瞬间的震屏强度（点火的冲击感）
@export var whoosh_climax := 0.85        # whoosh 音效的高潮在第几秒(分析波形得出)，用来对齐爆发瞬间
var _whoosh_played := false              # whoosh 只播一次
var _finale := false                   # 谢幕中：玩家交出操控，飞机自动冲出屏幕顶
var _finale_phase := 0                 # 谢幕阶段：0=先飞回开局位置，1=蓄力+爆发
var _finale_target := Vector2.ZERO     # 回位目标点（开局时的出生位置）
var _finale_speed := 0.0               # 谢幕当前上冲速度（越冲越快）
var _finale_t := 0.0                   # 蓄力/爆发已进行秒数
var _finale_burst_done := false        # 爆发震屏只来一次

func _ready():
	add_to_group("player")   # 让敌人(如 Side Reaper 的炮管)能找到我来瞄准
	# 游戏一开始，把飞机放到屏幕水平居中、偏下的位置（高度由 start_height_ratio 决定）
	var vp := get_viewport_rect().size
	position = Vector2(vp.x / 2, vp.y * start_height_ratio)
	# 初始化血量
	_hearts = max_hearts
	# 开局让血条按 max_hearts 自动生成对应数量的爱心（HUD 比玩家晚就绪，延后一步再设）
	call_deferred("_init_hud_hearts")
	# 被敌方子弹或敌机碰到时触发
	_hurtbox.area_entered.connect(_on_hurt_area)
	# 翻滚动画播完 → 结束闪避，换回普通飞机
	_roll.animation_finished.connect(_end_dodge)
	# 应用脚本里设定的音效音量
	_main_sound.volume_db = main_volume_db
	_side_sound.volume_db = side_volume_db

func _physics_process(delta):
	# —— 通关谢幕：接管一切操控——先飞回开局位置，再蓄力、爆发冲出屏幕顶 ——
	if _finale:
		# 阶段 0：用正常飞行速度回到开局出生点（途中机身按移动方向自然侧倾）
		if _finale_phase == 0:
			var to_target := _finale_target - position
			if to_target.length() <= speed * delta:
				position = _finale_target      # 到位：对齐目标点，进入蓄力
				_finale_phase = 1
			else:
				var dir := to_target.normalized()
				position += dir * speed * delta
				var tilt := deg_to_rad(max_tilt_deg) * dir.x
				_sprite.rotation = lerp_angle(_sprite.rotation, tilt, tilt_speed * delta)
			return
		# 阶段 1：蓄力 → 爆发
		_finale_t += delta
		# whoosh 提前 whoosh_climax 秒起播：渐强铺在蓄力期，最响那一下正好压在爆发瞬间
		if not _whoosh_played and _finale_t >= max(finale_ramp_time - whoosh_climax, 0.0):
			_whoosh_played = true
			$Whoosh.play()
		if _finale_t < finale_ramp_time:
			# 蓄力阶段：小加速度，缓缓飘起来（憋着劲）
			_finale_speed += finale_slow_accel * delta
		else:
			# 爆发阶段：加速度猛增，一瞬间窜出去
			if not _finale_burst_done:
				_finale_burst_done = true
				var cam = get_tree().get_first_node_in_group("camera")
				if cam:
					cam.shake(finale_burst_shake)   # 点火瞬间震一下，强化冲击感
			_finale_speed += finale_burst_accel * delta
		position.y -= _finale_speed * delta   # 直接改坐标，不走碰撞（免得被 Boss 残骸挡住）
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, tilt_speed * delta)
		return

	# —— 移动：方向键 + WASD 都能用 ——
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
		int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	)
	direction = (direction + wasd).limit_length(1.0)   # 两种输入叠加，并限制最大不超过 1（斜向不会更快）
	velocity = direction * speed
	move_and_slide()

	# —— 撞到 Boss 实体就扣血（无敌期间 hit_by_enemy 会自动忽略，不会一下扣光）——
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col and col.is_in_group("boss_solid"):
			hit_by_enemy()
			break

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
	if _god_mode:
		bullet.damage *= god_damage_mult   # 开挂模式：攻击力翻倍
	get_parent().add_child(bullet)

func _shoot_side():
	_side_sound.play()   # 播放副炮音效
	var parent := get_parent()

	# 左副炮
	var left := _side_scene.instantiate()
	left.position = position + Vector2(-side_offset_x, -side_offset_y)
	# 右副炮
	var right := _side_scene.instantiate()
	right.position = position + Vector2(side_offset_x, -side_offset_y)
	if _god_mode:
		left.damage *= god_damage_mult    # 开挂模式：攻击力翻倍
		right.damage *= god_damage_mult
	parent.add_child(left)
	parent.add_child(right)

func _on_hurt_area(area):
	# 谢幕演出中完全无敌（防残留流弹搅局）
	if _finale:
		return
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
	if _finale:
		return   # 谢幕演出中完全无敌
	if _invincible > 0.0:
		return
	_take_damage()

# 这局是否一滴血没掉（结算页的 PERFECT 标记用）
func took_no_damage() -> bool:
	return _hearts >= max_hearts

# 通关谢幕：由结算画面(victory.gd)调用——先飞回开局位置，再蓄力爆发冲出屏幕顶
func start_finale() -> void:
	_finale = true
	_finale_phase = 0
	# 回位目标 = 开局出生点（屏幕水平居中、高度按 start_height_ratio）
	var vp := get_viewport_rect().size
	_finale_target = Vector2(vp.x / 2, vp.y * start_height_ratio)
	_invincible = 0.0
	_sprite.modulate.a = 1.0   # 清掉可能残留的受伤闪烁，干干净净地谢幕

func _init_hud_hearts():
	# 把血条上的爱心数量补齐到 max_hearts（多退少补）
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_max_hearts"):
		hud.set_max_hearts(max_hearts)

func set_god_mode(on: bool) -> void:
	# 开发者作弊：开挂模式。开着时完全免伤 + 攻击力×god_damage_mult；血条显示成 ♾️
	_god_mode = on
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_infinite_hearts"):
		hud.set_infinite_hearts(on)
		if not on:
			hud.set_hearts(_hearts)   # 关掉作弊 → 恢复显示真实血量

func _take_damage():
	if _god_mode:
		return   # 开挂模式中：不扣血、不罚分、不震屏
	_hearts -= 1
	# 扣血时再去找 HUD（此时一切都已就绪）并刷新爱心显示 + 闪烁提醒
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_hearts(_hearts)
		hud.flash_hearts(invincible_time)   # 爱心闪烁，持续整个无敌时间
		# 扣第 n 滴血罚 50+50*n 分：第1次-100、第2次-150、第3次-200……越往后越痛
		var n = max_hearts - _hearts
		hud.add_score(-(50 + 50 * n))
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
