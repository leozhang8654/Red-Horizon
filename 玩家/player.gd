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
var _bullet_scene := preload("res://玩家/bullet.tscn")
var _side_scene := preload("res://玩家/副炮子弹.tscn")
var _death_scene := preload("res://玩家/player_death.tscn")   # 死亡爆炸特效
var _dying := false                                            # 已经在播死亡演出了？（防重复触发）
var _main_cooldown := 0.0
var _side_cooldown := 0.0

# —— 血量相关 ——
@export var max_hearts := 5           # 护盾格数（左下角显示几格血）
@export var last_stand := true        # 护盾打光后是否还有 1 滴“核心血”保命：true=能再扛最后一下（总血量=护盾格+1）
@export var invincible_time := 1.0     # 受伤后短暂无敌的秒数（避免一下被扣光）
@export var hit_shake_strength := 500.0 # 受伤时屏幕震动强度（越大越剧烈）
var _hearts := 0
var _core_intact := true   # 核心血还在吗（护盾打光后这滴保命血没用掉前为 true）
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

# —— 闪避冷却条（横条；位置由飞机下的 DodgeBarAnchor 锚点决定，可在编辑器里拖）——
# 想挪位置：在 Godot 里选中 Player ▸ DodgeBarAnchor，直接拖它，条就居中跟到哪
@onready var _dodge_anchor: Marker2D = $DodgeBarAnchor   # 条的中心锚点
@export var dodge_bar_width := 120.0      # 横条的长度（像素）
@export var dodge_bar_height := 14.0      # 横条的粗细（像素）
@export var dodge_bar_bg_color := Color(0, 0, 0, 0.45)     # 底槽颜色（半透明黑）
@export var dodge_bar_fill_color := Color(1, 1, 1, 0.95)   # 填充色（白）
@export var dodge_bar_fade_speed := 6.0   # 渐显/渐隐速度（越大=出现和消失越快）
var _dodge_bar_alpha := 0.0   # 冷却条当前的整体透明度（0=完全藏起，1=完全显示）

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

# —— 受伤护盾（受击方向亮起一张弧形能量盾贴图，无敌期间闪烁并抵挡这一侧的敌弹）——
@export var shield_radius := 200.0      # 护盾贴图多大/离飞机中心多远（像素）。调大=护盾更大、挡得更远
@export var shield_arc_deg := 120.0     # 挡弹的扇形范围有多宽（度）。只管挡弹判定，贴图形状不随它变
@export var shield_color := Color(1, 1, 1, 1)   # 给护盾贴图染色（白=原图淡蓝霓虹；想偏红就调成淡红）
@export var shield_blink_hz := 9.0      # 护盾每秒闪几次。调大=闪得更急促
@export var shield_dim_alpha := 0.2     # 闪烁"暗"那一下的亮度（0=完全灭、1=几乎不闪）
@export var shield_block_margin := 24.0 # 挡子弹的距离容差（把子弹算多厚）。调大=更早把弹挡下
const SHIELD_TEX_PATH := "res://玩家/art/玩家护盾.png"
const SHIELD_TEX_CENTER := Vector2(620, 720)   # 贴图里弧的"圆心"像素坐标（让它对齐飞机中心）
const SHIELD_TEX_RADIUS := 460.0               # 贴图里弧的半径（像素），用来换算缩放
var _shield_sprite: Sprite2D                   # 护盾贴图节点（代码里创建，平时隐藏）
var _shield_angle := 0.0   # 当前护盾朝向（弧度，指向攻击来的方向）
var _shield_alpha := 0.0   # 护盾当前亮度（每帧由闪烁算出）
var _shield_timer := 0.0   # 护盾剩余持续时间（受击时=无敌时间，期间闪烁+挡弹）

func _ready():
	add_to_group("player")   # 让敌人(如 Side Reaper 的炮管)能找到我来瞄准
	# 游戏一开始，把飞机放到屏幕水平居中、偏下的位置（高度由 start_height_ratio 决定）
	var vp := get_viewport_rect().size
	position = Vector2(vp.x / 2, vp.y * start_height_ratio)
	# 初始化血量
	_hearts = max_hearts
	_core_intact = last_stand   # 重置核心血（开启保命时这局有 1 滴隐形血）
	# 开局让血条按 max_hearts 自动生成对应数量的爱心（HUD 比玩家晚就绪，延后一步再设）
	call_deferred("_init_hud_hearts")
	# 被敌方子弹或敌机碰到时触发
	_hurtbox.area_entered.connect(_on_hurt_area)
	# 翻滚动画播完 → 结束闪避，换回普通飞机
	_roll.animation_finished.connect(_end_dodge)
	# 应用脚本里设定的音效音量
	_main_sound.volume_db = main_volume_db
	_side_sound.volume_db = side_volume_db
	# 创建护盾贴图节点：画在飞机上方、平时隐藏；受击时亮出并转向受击方向
	_shield_sprite = Sprite2D.new()
	_shield_sprite.texture = load(SHIELD_TEX_PATH)
	_shield_sprite.centered = false
	_shield_sprite.offset = -SHIELD_TEX_CENTER   # 让贴图里弧的圆心对齐飞机中心
	_shield_sprite.z_index = 5                   # 盖在飞机上面
	_shield_sprite.visible = false
	add_child(_shield_sprite)

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
			var cp := get_slide_collision(i).get_position()   # 撞击接触点
			hit_by_enemy(global_position.direction_to(cp))
			break

	# —— 空气墙：把飞机限制在屏幕范围内，飞不出去 ——
	var view: Vector2 = get_viewport_rect().size
	position.x = clamp(position.x, edge_margin, view.x - edge_margin)
	position.y = clamp(position.y, edge_margin, view.y - edge_margin)

	# —— 闪避：只做冷却倒计时；触发挪到 _unhandled_input（避免"暂停→空格继续"那下被当成闪避）——
	_dodge_cd -= delta
	# 冷却条只在"还在冷却"时显示：在冷却→渐显到1，冷却好了→渐隐回0
	var bar_target := 1.0 if _dodge_cd > 0.0 else 0.0
	_dodge_bar_alpha = move_toward(_dodge_bar_alpha, bar_target, dodge_bar_fade_speed * delta)
	queue_redraw()   # 冷却条每帧重画，才能看到它平滑地涨起来/淡出

	# —— 机身侧倾：向右移右倾、向左移左倾、松手平滑回正（翻滚时不做侧倾）——
	if not _dodging:
		var target_tilt := deg_to_rad(max_tilt_deg) * direction.x
		_sprite.rotation = lerp_angle(_sprite.rotation, target_tilt, tilt_speed * delta)

	# —— 无敌时间：受伤后短暂无敌（飞机本体不再闪烁，改由护盾来闪）——
	if _invincible > 0.0:
		_invincible -= delta

	# —— 受伤护盾：无敌期间持续闪烁，并挡掉打向这一侧的敌弹 ——
	if _shield_timer > 0.0:
		_shield_timer -= delta
		# 方波闪烁：在"亮"和"暗"之间快速跳动
		var phase := fmod(_shield_timer * shield_blink_hz, 1.0)
		_shield_alpha = 1.0 if phase < 0.5 else shield_dim_alpha
		if _shield_sprite:
			_shield_sprite.modulate = Color(shield_color.r, shield_color.g, shield_color.b, _shield_alpha)
		_block_bullets_with_shield()
		if _shield_timer <= 0.0:
			_shield_alpha = 0.0
			if _shield_sprite:
				_shield_sprite.visible = false

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

# 闪避触发：用"接住按键事件"而非每帧轮询。暂停菜单"继续"会先把空格事件吃掉
# (set_input_as_handled)，所以从暂停恢复时按的那下空格到不了这里，不会误触发闪避。
func _unhandled_input(event):
	if _finale:
		return   # 谢幕演出中交出操控，不响应闪避
	if event.is_action_pressed("ui_accept") and _dodge_cd <= 0.0 and not _dodging:
		_start_dodge()

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

# 画一条横向"闪避冷却条"，中心对齐 DodgeBarAnchor 锚点（可在编辑器拖动）：
# 剩余冷却越少 → 填充越长（向右涨）；填满 = 现在就能再闪避。
# 画在玩家根节点上，根节点不旋转（侧倾只动贴图），所以条始终保持水平、并自动跟着飞机走。
func _draw():
	_draw_dodge_bar()

# 受击时亮出护盾贴图：转到受击方向、按 shield_radius 缩放。
# 贴图原图拱顶朝正上方(-90°)，所以旋转量 = 受击角度 + 90°，让拱顶正对攻击来向。
func _show_shield_sprite():
	if _shield_sprite == null:
		return
	_shield_sprite.rotation = _shield_angle + PI / 2.0
	_shield_sprite.scale = Vector2.ONE * (shield_radius / SHIELD_TEX_RADIUS)
	_shield_sprite.visible = true

# 护盾亮着时：把飞进护盾扇形（同一朝向、同一角度范围）的敌弹消掉，表现为被挡。
func _block_bullets_with_shield():
	var half := deg_to_rad(shield_arc_deg) / 2.0
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		if not is_instance_valid(b):
			continue
		var to_b: Vector2 = b.global_position - global_position
		var d := to_b.length()
		if d > shield_radius + shield_block_margin:
			continue   # 还没飞到护盾这一圈，先放过
		if absf(angle_difference(to_b.angle(), _shield_angle)) <= half:
			b.queue_free()   # 落在护盾扇形内 → 被挡掉、消失

func _draw_dodge_bar():
	if _dodge_bar_alpha <= 0.0:
		return   # 平时（没在冷却）完全藏起来，一点都不画
	var ratio := clampf(1.0 - _dodge_cd / dodge_cooldown, 0.0, 1.0)
	# 以锚点为中心：左端 = 锚点x - 半个宽，顶边 = 锚点y - 半个高
	var center := _dodge_anchor.position
	var x := center.x - dodge_bar_width / 2.0
	var y := center.y - dodge_bar_height / 2.0
	# 底槽和填充都乘上当前透明度，实现整体渐显/渐隐
	var bg := dodge_bar_bg_color
	bg.a *= _dodge_bar_alpha
	draw_rect(Rect2(x, y, dodge_bar_width, dodge_bar_height), bg)
	if ratio > 0.0:
		var col := dodge_bar_fill_color
		col.a *= _dodge_bar_alpha
		draw_rect(Rect2(x, y, dodge_bar_width * ratio, dodge_bar_height), col)

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
		# 算出"攻击从哪来"：玩家指向这颗子弹/这架敌机的方向
		var dir := global_position.direction_to(area.global_position)
		_take_damage(dir if dir != Vector2.ZERO else Vector2.UP)

func hit_by_enemy(from_dir := Vector2.UP) -> void:
	# 供敌人(如 Side Reaper 激光)调用：无敌中则忽略，否则扣血
	# from_dir = 攻击来的方向（玩家→攻击源）；没传就默认从正上方来
	if _finale:
		return   # 谢幕演出中完全无敌
	if _invincible > 0.0:
		return
	_take_damage(from_dir)

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

func _take_damage(from_dir := Vector2.UP):
	if _god_mode:
		return   # 开挂模式中：不扣血、不罚分、不震屏
	# 在受击方向亮起弧形护盾（持续整个无敌时间，期间闪烁并抵挡这一侧的敌弹）
	# 扣血：护盾还有就扣一格护盾、并亮起弧形能量盾；护盾空了就用掉隐形“核心血”、且不亮护盾
	if _hearts > 0:
		_shield_angle = from_dir.angle()
		_shield_timer = invincible_time   # 亮起受击方向的弧形能量盾
		_show_shield_sprite()
		_hearts -= 1
	elif _core_intact:
		_core_intact = false   # 护盾打光后被打中：核心血顶掉这一下，不死，也不亮护盾
	# 扣血时再去找 HUD（此时一切都已就绪）并刷新护盾显示 + 闪烁提醒
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_hearts(_hearts)
		hud.flash_hearts(invincible_time)   # 护盾闪烁，持续整个无敌时间
		# 扣第 n 滴血罚 50+50*n 分：第1次-100、第2次-150、第3次-200……越往后越痛
		var n = max_hearts - _hearts
		hud.add_score(-(50 + 50 * n))
	# 屏幕剧烈震动
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(hit_shake_strength)
	_invincible = invincible_time   # 进入短暂无敌
	# 护盾为 0 且核心血也用掉了 → 真正阵亡
	if _hearts <= 0 and not _core_intact:
		_die()

func _die():
	# 血量归零：先在飞机位置炸一下（约1.3秒），飞机本体消失，爆炸放完再弹出“游戏结束”画面
	if _dying:
		return            # 已经在死亡演出里了，别再触发第二次
	_dying = true
	# 在飞机当前位置生成死亡爆炸（自带 dust skimmer 爆炸音效，播完自己删除）
	var boom = _death_scene.instantiate()
	boom.global_position = global_position
	get_parent().add_child(boom)
	# 飞机“没了”：藏起贴图、停掉移动/开火/受伤判定（爆炸是独立节点，照样继续放）
	_sprite.visible = false
	_roll.visible = false
	set_physics_process(false)
	_hurtbox.set_deferred("monitoring", false)
	# 等爆炸放完再弹结束画面（9帧 ÷ 7fps ≈ 1.3 秒）
	await get_tree().create_timer(1.3).timeout
	var go = get_tree().get_first_node_in_group("game_over")
	if go:
		go.show_game_over()
