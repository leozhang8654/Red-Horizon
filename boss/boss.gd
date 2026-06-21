extends Area2D
# 第三波 Boss：MANTIS-LUX 巨型母舰。
# 出场：从顶部压入(此期间无敌) → 顶部悬停并缓慢左右游移；四个炮台实时瞄准玩家。
# 分阶段击破：第一阶段主体碰撞关闭、打不到，只能逐个打爆四个炮台(各有血量)；
#   四炮台全爆 → 打开主体碰撞 → 第二阶段才能打主体掉血 → 血光打光后大爆炸消失。
# 攻击招式：第一阶段=环形弹幕 + 四炮台机枪；第二阶段=环形弹幕 + 中央横扫激光。

@export var max_hp := 300.0           # Boss 总血量（玩家子弹每发约扣 1）
@export var enter_speed := 230.0      # 从屏幕上方压入的速度（像素/秒）
@export var hover_y := 550.0          # 就位后机身中心悬停的高度
@export var drift_x := 650.0          # 左右游移幅度（离屏幕中线最多偏多少像素）
@export var drift_speed := 0.3        # 左右游移快慢（越大来回越快）
@export var center_speed := 350.0     # 核心爆后飞回屏幕中央的速度（像素/秒）
@export var score_value := 10000       # 击毁得分

# —— 受击闪烁 ——
@export var blink_persist := 0.06     # 每次中弹后白光持续多久
@export var blink_brightness := 1.6   # 白光亮度倍数

# —— 隐形盾（命中才显形）——
# 阶段1/2a 打 Boss 本体：不掉血，只在命中点冒一小片红色六边形冲击网格再淡出。
@export var shield_turret_skip := 130.0   # "通向炮台的弹道"横向半宽(像素)：子弹横向离活炮台小于它→放行不挡，让它去打炮台

# —— 炮台瞄准 ——
@export var turrets_aim := true        # 四个炮台是否实时瞄准玩家
@export var turret_aim_smooth := 6.0   # 炮台转向平滑度（越大锁得越快，越小越“迟钝”）

# —— 分阶段击破：先打四个炮台，全爆后才暴露中央核心 ——
@export var turret_hp := 50.0          # 每个炮台的血量
@export var turret_score := 800        # 打爆一个炮台的得分

# —— 阶段2a：中央核心（炮台全爆后暴露；打爆它才解全盾、开放本体血量）——
@export var core_hp := 200.0           # 核心血量（玩家子弹每发约扣 1）
@export var core_score := 1500         # 打爆核心的得分
@export var core_hit_skip := 150.0     # "通向核心的弹道"横向半宽(像素)：子弹横向离暴露的核心小于它→放行不挡，让它去打核心

# —— 招式①：环形弹幕（从核心 RingCore 向四周喷一整圈）——
@export var ring_attack := true        # 是否开启环形弹幕
@export var ring_count := 10           # 每圈几颗子弹（越少→缝隙越大越好躲；越多→越密越难）
@export var ring_bullet_speed := 1000.0 # 子弹飞行速度（像素/秒，越慢越好躲）
@export var ring_interval := 1.0       # 每隔几秒发一圈（越大越宽松）
@export var ring_spin_deg := 20.0      # 每圈整体多转多少度（让缝隙错开、不固定一条死缝）

# —— 招式②：炮台机枪弹幕（每个活着的炮台朝玩家连发条状子弹）——
@export var mg_attack := true          # 是否开启炮台机枪
@export var mg_bullet_speed := 650.0   # 子弹速度（像素/秒）
@export var mg_burst := 6              # 每轮每个炮台连发几颗
@export var mg_rate := 0.09            # 连发时每颗的间隔（秒，越小越密）
@export var mg_interval := 2.2         # 两轮之间的停顿（秒，越大越宽松）
@export var mg_spread_deg := 7.0       # 随机散布角度（越大越散、越好躲）

# —— 招式③：中央横扫激光（仅第二阶段，主体暴露后启用）——
#   实现：整艘船绕中心侧倾，激光从机身正下方 CoreMuzzle 沿机身轴“垂直”射出；
#   船身从 -arc 摆到 +arc，激光(始终垂直机身)就跟着横扫过去 → 既垂直又横扫。
@export var laser_attack := true        # 是否开启横扫激光
@export var laser_warn_time := 1.6      # 预警时长（船身摆到起始角 + 红线闪烁，秒）
@export var laser_sweep_time := 5.5     # 横扫一趟时长（越大扫得越慢越好躲）；和 warn 之和≈音效长度
@export var laser_cooldown := 2.0       # 两趟横扫之间的间隔（秒，越大越宽松）
@export var laser_arc_deg := 45.0       # 横扫半张角（从正下方往两边各摆多少度）
@export var laser_bank_speed := 6.0     # 预警时船身摆到位的平滑速度
@export var laser_hit_width := 140.0    # 激光命中判定半宽（像素，越小越好躲）

var _bullet_scene := preload("res://boss/boss_bullet.tscn")   # Boss 核心子弹（环形弹幕）
var _turret_bullet_scene := preload("res://boss/boss_turret_bullet.tscn")   # 炮台机枪子弹
var _barrel_explosion_scene := preload("res://boss/barrel_explosion.tscn")   # 炮台专用爆炸
var _death_anim_scene := preload("res://boss/boss_death_anim.tscn")   # 死亡演出(5秒爆炸解体动画)
# —— 隐形护盾（shader 局部点亮：平时全透明，命中处就近点亮一块再淡掉）——
const SHIELD_MAX_HITS := 8
@export var shield_reveal_decay := 1.8   # 命中点亮后多快淡掉(越大灭得越快)
var _shield: Sprite2D = null
var _shield_mat: ShaderMaterial = null
var _shield_hits := PackedVector2Array()
var _shield_str := PackedFloat32Array()
var _shield_write := 0
var _hp := 0.0
var _dead := false
var _entered := false      # 是否已压入就位
var _t := 0.0              # 左右游移用的时间累计
var _center_x := 0.0       # 屏幕水平中线
var _blink_t := 0.0        # 受击闪烁剩余时间

@onready var _body: Sprite2D = $Body
@onready var _body_col: CollisionPolygon2D = $CollisionPolygon2D
@onready var _ring_core: Marker2D = $RingCore
@onready var _core_muzzle: Marker2D = $CoreMuzzle
@onready var _laser_warn: Line2D = $LaserWarn
@onready var _laser_beam: Sprite2D = $LaserBeam
@onready var _laser_sound: AudioStreamPlayer = $LaserSound
@onready var _ring_sound: AudioStreamPlayer = $RingSound
@onready var _mg_sound: AudioStreamPlayer = $MgSound

var _ring_t := 0.0          # 距离下一圈弹幕还差多久
var _ring_angle := 0.0      # 当前这圈的起始角度（每圈累加 ring_spin_deg，让缝隙错开）
var _mg_t := 1.5            # 机枪计时（初始等一会再开火）
var _mg_shots_left := 0     # 本轮连发还剩几颗
var _laser_phase := "idle"  # 激光阶段：idle 间隔 / warn 预警 / sweep 横扫
var _laser_t := 0.0         # 激光阶段计时
var _laser_dir := 1.0       # 本趟横扫方向（每趟交替）
var _laser_angle := 0.0     # 当前光束角度

var _turrets: Array = []        # 四个炮台，每个 {pivot, sprite, forward, hp, blink, dead}
var _turrets_alive := 0         # 还活着的炮台数
var _body_vulnerable := false   # 主体是否已可被攻击（核心打爆后才 true）

# 击破阶段："turrets"打炮台 → "core"打核心 → "body"打本体血量
var _stage := "turrets"
var _core: Node2D = null        # 中央核心（占位发光圆）
var _core_hp := 0.0
var _core_alive := false        # 核心是否处于"可被攻击"状态

func _ready():
	_hp = max_hp
	add_to_group("enemy")        # 玩家子弹靠这个识别敌人
	add_to_group("boss")         # 单独标记，后续血条/波次管理用
	area_entered.connect(_on_area_entered)
	var solid = get_node_or_null("Solid")
	if solid:
		solid.add_to_group("boss_solid")   # 让玩家撞到时能识别这是 Boss 实体 → 扣血
	_setup_turrets()
	# 中央核心：接好它的受击判定，平时藏起来（炮台全爆后才暴露）
	_core = get_node_or_null("Core")
	if _core:
		_core.visible = false
		var core_hit = _core.get_node_or_null("Hit")
		if core_hit:
			core_hit.area_entered.connect(_on_core_area)
	# 隐形护盾：拿到 shader 材质，初始化命中缓冲(平时全透明，被打才就近点亮)
	_shield = get_node_or_null("Shield")
	if _shield and _shield.material is ShaderMaterial:
		_shield_mat = _shield.material
		_shield_hits.resize(SHIELD_MAX_HITS)
		_shield_str.resize(SHIELD_MAX_HITS)
		if _shield.texture:
			_shield_mat.set_shader_parameter("aspect", float(_shield.texture.get_width()) / float(_shield.texture.get_height()))
	# 从开局就打开本体子弹判定：阶段1还不能掉血(_body_vulnerable=false)，
	# 但要靠它侦测到"子弹打本体"，好显形隐形盾(六边形网格)。
	if _body_col:
		_body_col.disabled = false
	_center_x = get_viewport_rect().size.x / 2.0
	position = Vector2(_center_x, -400.0)   # 先藏在屏幕上方外面

func _physics_process(delta):
	if _dead:
		return
	if not _entered:
		# 压入阶段：匀速往下飞到悬停高度
		position.y += enter_speed * delta
		if position.y >= hover_y:
			position.y = hover_y
			_entered = true
	else:
		if _stage == "body":
			# 核心爆后：平滑飞回屏幕水平中央，到位后就停住不再游移
			position.x = move_toward(position.x, _center_x, center_speed * delta)
		else:
			# 就位后：用正弦曲线缓慢左右游移
			_t += delta * drift_speed
			position.x = _center_x + sin(_t) * drift_x
	if _entered:
		_update_ring(delta)
		_update_mg(delta)
		if _stage != "turrets":     # 第二阶段起（核心暴露后）才放横扫激光
			_update_laser(delta)
	_aim_turrets(delta)
	_update_turret_blink(delta)
	_update_blink(delta)
	_update_shield_reveal(delta)

# 招式①：每隔 ring_interval 秒，从核心向四周喷一圈子弹
func _update_ring(delta):
	if not ring_attack:
		return
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = ring_interval
		_fire_ring()

func _fire_ring():
	_ring_sound.play()   # 每喷一圈响一次（max_polyphony 允许叠音不被掐断）
	var origin: Vector2 = _ring_core.global_position
	var step: float = TAU / float(max(ring_count, 1))
	for i in range(ring_count):
		var ang: float = deg_to_rad(_ring_angle) + step * i
		var b = _bullet_scene.instantiate()
		b.direction = Vector2(cos(ang), sin(ang))   # 朝四周均匀发射
		b.speed = ring_bullet_speed
		get_parent().add_child(b)
		b.global_position = origin                  # 从核心位置冒出来
	_ring_angle += ring_spin_deg                    # 下一圈整体转一点，缝隙就错开了

# 招式②：炮台机枪——连发一阵 → 停顿 → 再连发，循环
func _update_mg(delta):
	if not mg_attack:
		return
	_mg_t -= delta
	if _mg_t > 0.0:
		return
	if _mg_shots_left <= 0:
		_mg_shots_left = mg_burst   # 开始新一轮连发
		_mg_t = mg_interval         # 先停顿一下
		return
	if _mg_shots_left == mg_burst and _turrets_alive > 0:
		_mg_sound.play()            # 本轮第一发：响一串机枪声（炮台全灭后不再响）
	_mg_fire_once()
	_mg_shots_left -= 1
	_mg_t = mg_rate
	if _mg_shots_left <= 0:
		_mg_sound.stop()            # 最后一发打完 → 机枪声立刻停，不拖余响

# 每个还活着的炮台，从它的每个炮口都朝玩家方向发一颗（带随机散布）
func _mg_fire_once():
	var p = get_tree().get_first_node_in_group("player")
	for t in _turrets:
		if t["dead"]:
			continue
		for m in t["muzzles"]:
			if m == null or not is_instance_valid(m):
				continue
			var origin: Vector2 = m.global_position
			var dir: Vector2 = Vector2.DOWN
			if p:
				dir = (p.global_position - origin).normalized()
			dir = dir.rotated(deg_to_rad(randf_range(-mg_spread_deg, mg_spread_deg)))
			var b = _turret_bullet_scene.instantiate()
			b.direction = dir
			b.speed = mg_bullet_speed
			get_parent().add_child(b)
			b.global_position = origin

# 招式③：中央激光——间隔 → 预警(红线) → 缓慢横扫(贯穿光束) → 间隔，循环
func _update_laser(delta):
	if not laser_attack:
		rotation = lerp_angle(rotation, 0.0, laser_bank_speed * delta)
		return
	var down := PI / 2.0                 # 正下方（屏幕里 y 向下）
	var arc := deg_to_rad(laser_arc_deg)
	match _laser_phase:
		"idle":
			rotation = lerp_angle(rotation, 0.0, laser_bank_speed * delta)   # 没在放激光 → 船身回正
			_laser_t += delta
			if _laser_t >= laser_cooldown:
				_laser_t = 0.0
				_laser_dir = 1.0 if randf() < 0.5 else -1.0   # 每趟随机：左→右 或 右→左
				_laser_phase = "warn"
		"warn":
			_laser_angle = down - _laser_dir * arc          # 这趟横扫的起点角
			# 船身侧倾到“与激光垂直”：机身正下方(+Y)对准激光方向，平滑摆到起点角
			rotation = lerp_angle(rotation, _laser_angle - down, laser_bank_speed * delta)
			_show_laser_warn(_laser_angle)
			_laser_t += delta
			if _laser_t >= laser_warn_time:
				_laser_t = 0.0
				_laser_warn.visible = false
				_laser_phase = "sweep"
				# 激光音效只在“真正发射”时响：用 pitch 让它正好卡满横扫时长
				if _laser_sound.stream and laser_sweep_time > 0.0:
					_laser_sound.pitch_scale = _laser_sound.stream.get_length() / laser_sweep_time
				_laser_sound.play()
		"sweep":
			var f: float = clamp(_laser_t / laser_sweep_time, 0.0, 1.0)
			_laser_angle = (down - _laser_dir * arc) + _laser_dir * (2.0 * arc) * f
			rotation = _laser_angle - down                   # 船身始终与激光垂直，跟着横扫一起转
			_show_laser_beam(_laser_angle)
			_check_laser_hit(_laser_angle)
			_laser_t += delta
			if _laser_t >= laser_sweep_time:
				_laser_t = 0.0
				_laser_beam.visible = false
				_laser_phase = "idle"

func _show_laser_warn(angle):
	var origin: Vector2 = _core_muzzle.global_position
	var dir := Vector2(cos(angle), sin(angle))
	_laser_warn.global_position = origin
	_laser_warn.rotation = dir.angle()
	_laser_warn.points = PackedVector2Array([Vector2.ZERO, Vector2(3000.0, 0.0)])
	_laser_warn.visible = fmod(_laser_t * 12.0, 1.0) < 0.5   # 闪烁预警

func _show_laser_beam(angle):
	var origin: Vector2 = _core_muzzle.global_position
	var dir := Vector2(cos(angle), sin(angle))
	_laser_beam.visible = true
	_laser_beam.global_position = origin
	_laser_beam.rotation = dir.angle() + PI / 2.0           # 让光束贴图沿方向延伸

func _check_laser_hit(angle):
	# 几何判定：玩家到光束中轴的垂直距离 < hit_width 且在炮口前方 → 命中
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var origin: Vector2 = _core_muzzle.global_position
	var dir := Vector2(cos(angle), sin(angle))
	var to_p: Vector2 = p.global_position - origin
	var along: float = to_p.dot(dir)
	if along < 0.0:
		return
	var perp: float = (to_p - dir * along).length()
	if perp <= laser_hit_width and p.has_method("hit_by_enemy"):
		p.hit_by_enemy()

# 启动时记下四个炮台的“支点节点”+图片+血量，并用各自的 Muzzle 确定“炮口正前方”
func _setup_turrets():
	for n in ["BarrelLeftPivot", "BarrelRightPivot", "DroneLeftPivot", "DroneRightPivot"]:
		var piv = get_node_or_null(n)
		if piv == null:
			continue
		var spr = piv.get_child(0)        # 支点下第一个子节点 = 炮台图片
		# 收集这个炮台下的所有炮口标记点（含嵌套的）
		var muzzles = piv.find_children("Muzzle", "Marker2D", true, false)
		var fwd := 0.0
		if not muzzles.is_empty():
			# 用第一个炮口相对“支点”的方向 = 这门炮在静止时的正前方
			fwd = piv.to_local(muzzles[0].global_position).angle()
		var entry := {"pivot": piv, "sprite": spr, "forward": fwd, "hp": turret_hp, "blink": 0.0, "dead": false, "muzzles": muzzles}
		var hit = spr.get_node_or_null("Hit")
		if hit:
			hit.area_entered.connect(_on_turret_area.bind(entry))   # 这个炮台被子弹打中
		_turrets.append(entry)
	_turrets_alive = _turrets.size()

# 每帧让每个(还活着的)炮台平滑转动，使“炮口正前方”对准玩家
func _aim_turrets(delta):
	if not turrets_aim:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	for t in _turrets:
		if t["dead"]:
			continue
		var node: Node2D = t["pivot"]
		var to_p: Vector2 = p.global_position - node.global_position
		var desired: float = to_p.angle() - t["forward"]
		node.rotation = lerp_angle(node.rotation, desired, turret_aim_smooth * delta)

# 炮台受击白光
func _update_turret_blink(delta):
	for t in _turrets:
		if t["dead"] or t["blink"] <= 0.0:
			continue
		t["blink"] -= delta
		var spr: Sprite2D = t["sprite"]
		if t["blink"] <= 0.0:
			spr.modulate = Color(1, 1, 1)
		else:
			spr.modulate = Color(blink_brightness, blink_brightness, blink_brightness)

# 子弹打中某个炮台
func _on_turret_area(area, entry):
	if entry["dead"]:
		return
	if not _entered:        # 进场(压入)期间无敌，子弹无效
		return
	if not area.is_in_group("bullet"):
		return
	entry["hp"] -= area.damage
	area.queue_free()
	entry["blink"] = blink_persist
	if entry["hp"] <= 0.0:
		_destroy_turret(entry)

# 炮台被打爆：原地爆炸 + 整个移除 + 计数；四个全爆则开放主体
func _destroy_turret(entry):
	entry["dead"] = true
	var fx = _barrel_explosion_scene.instantiate()
	fx.global_position = entry["sprite"].global_position
	# 爆炸序列图“正前方=右”，对齐到这门炮的真实炮口方向(sprite朝向 + 该炮forward)
	fx.global_rotation = entry["sprite"].global_rotation + entry["forward"]
	get_parent().add_child(fx)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(turret_score)
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(250.0)
	entry["pivot"].queue_free()       # 移除整个炮台(支点/图片/炮口/碰撞)
	_turrets_alive -= 1
	if _turrets_alive <= 0:
		_enter_core_phase()

# 四个炮台全部被毁 → 暴露中央核心，进入"打核心"阶段(2a)。
# 此时本体仍是隐形盾(打了只冒六边形不掉血)，激光开始登场；核心可被攻击。
func _enter_core_phase():
	_stage = "core"
	_core_hp = core_hp
	_core_alive = true
	if _core:
		_core.visible = true
		if _core.has_method("set_damage"):
			_core.set_damage(0.0)

# 子弹打中暴露的核心
func _on_core_area(area):
	if not _core_alive:
		return
	if not _entered:
		return
	if not area.is_in_group("bullet"):
		return
	_core_hp -= area.damage
	area.queue_free()
	if _core:
		if _core.has_method("flash"):
			_core.flash()
		if _core.has_method("set_damage"):
			_core.set_damage(1.0 - _core_hp / core_hp)
	if _core_hp <= 0.0:
		_destroy_core()

# 核心被打爆 → 解全盾、停环形弹、开放本体血量(进入阶段2b)
func _destroy_core():
	_core_alive = false
	_stage = "body"
	ring_attack = false             # 环形弹的源头(核心)没了 → 停发
	laser_attack = false            # 核心没了 → 横扫激光也停
	_laser_warn.visible = false     # 清掉可能正在显示的预警红线
	_laser_beam.visible = false     # 清掉可能正在扫的光束
	_laser_phase = "idle"
	_body_vulnerable = true         # 现在打本体开始真正掉血
	# 核心爆掉的表现：播爆炸序列动画，放完停在最后一帧(废墟)永久留在原地
	if _core and _core.has_method("explode"):
		_core.explode()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(core_score)
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(300.0)

func _update_blink(delta):
	if _blink_t <= 0.0:
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_body.modulate = Color(1, 1, 1)
	else:
		_body.modulate = Color(blink_brightness, blink_brightness, blink_brightness)

func _on_area_entered(area):
	if _dead:
		return
	if not area.is_in_group("bullet"):
		return
	if not _entered:
		# 出场(压入)期间：全身无敌，子弹一律被护盾挡下并就近显形护盾
		_register_shield_hit(area.global_position)
		area.queue_free()
		return
	if _body_vulnerable:
		# 主体可攻击阶段：正常掉血
		_hp -= area.damage
		area.queue_free()
		_blink_t = blink_persist
		if _hp <= 0.0:
			_dead = true
			_die()
	else:
		# 隐形盾阶段：挡住子弹并在命中点冒护盾涟漪，本体不掉血。
		# 例外——玩家子弹竖直上飞，若它所在的"竖直弹道"(按横向 x 判断)上有活着的炮台
		# 或暴露的核心，就放它过去打它们(否则后排炮台/核心永远打不到)。
		for t in _turrets:
			if not t["dead"] and is_instance_valid(t["sprite"]) \
					and abs(area.global_position.x - t["sprite"].global_position.x) < shield_turret_skip:
				return
		if _core_alive and is_instance_valid(_core) \
				and abs(area.global_position.x - _core.global_position.x) < core_hit_skip:
			return
		# 其余子弹：被盾挡下(消失) + 在命中处就近点亮隐形护盾
		_register_shield_hit(area.global_position)
		area.queue_free()

# 把一次命中登记到隐形护盾：换算成贴图UV，写进命中缓冲(强度1)，shader 就会就近点亮一块。
func _register_shield_hit(world_pos: Vector2):
	if _shield == null or _shield_mat == null or _shield.texture == null:
		return
	var local: Vector2 = _shield.to_local(world_pos)
	var ts: Vector2 = _shield.texture.get_size()
	var uv := Vector2(local.x / ts.x + 0.5, local.y / ts.y + 0.5)
	_shield_hits[_shield_write] = uv
	_shield_str[_shield_write] = 1.0
	_shield_write = (_shield_write + 1) % SHIELD_MAX_HITS

# 每帧：各命中点亮度逐渐衰减，并把最新数组喂给 shader(平时全 0 → 护盾全透明)
func _update_shield_reveal(delta: float):
	if _shield_mat == null:
		return
	for i in SHIELD_MAX_HITS:
		if _shield_str[i] > 0.0:
			_shield_str[i] = max(_shield_str[i] - shield_reveal_decay * delta, 0.0)
	_shield_mat.set_shader_parameter("hits", _shield_hits)
	_shield_mat.set_shader_parameter("strengths", _shield_str)

func _die():
	# 播放 5 秒的死亡演出动画(boss_death_anim.tscn)：起火→大爆炸→解体→碎片四散。
	# 动画里的 Boss 宽 543 像素 → 按真机身的显示宽度自动缩放，大小就能对上。
	var anim = _death_anim_scene.instantiate()
	var body_width: float = $Body.texture.get_width() * $Body.global_scale.x
	var s := body_width / 543.0
	anim.scale = Vector2(s, s)
	anim.rotation = global_rotation                # 继承当下的侧倾角(激光横扫中被打死也不跳变)
	get_parent().add_child(anim)
	anim.global_position = $Body.global_position   # 对准机身中心(动画自带偏移校正)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(score_value)
	# 通知通关结算画面：Boss 已被击毁（它会先停表，等死亡演出放完再亮"任务完成"）
	var victory = get_tree().get_first_node_in_group("victory")
	if victory:
		victory.boss_defeated()
	queue_free()
