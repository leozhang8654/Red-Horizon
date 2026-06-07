extends Area2D
# 第三波 Boss：MANTIS-LUX 巨型母舰。
# 出场：从顶部压入 → 顶部悬停并缓慢左右游移；四个炮台实时瞄准玩家。
# 分阶段击破：第一阶段主体碰撞关闭、打不到，只能逐个打爆四个炮台(各有血量)；
#   四炮台全爆 → 打开主体碰撞 → 第二阶段才能打主体掉血 → 血光打光后大爆炸消失。
# 三种攻击招式（机枪弹幕 / 中央激光 / 环形弹幕）后续步骤再加。

@export var max_hp := 800.0           # Boss 总血量（玩家子弹每发约扣 1）
@export var enter_speed := 220.0      # 从屏幕上方压入的速度（像素/秒）
@export var hover_y := 550.0          # 就位后机身中心悬停的高度
@export var drift_x := 650.0          # 左右游移幅度（离屏幕中线最多偏多少像素）
@export var drift_speed := 0.3        # 左右游移快慢（越大来回越快）
@export var score_value := 5000       # 击毁得分

# —— 受击闪烁 ——
@export var blink_persist := 0.06     # 每次中弹后白光持续多久
@export var blink_brightness := 1.6   # 白光亮度倍数

# —— 炮台瞄准 ——
@export var turrets_aim := true        # 四个炮台是否实时瞄准玩家
@export var turret_aim_smooth := 6.0   # 炮台转向平滑度（越大锁得越快，越小越“迟钝”）

# —— 分阶段击破：先打四个炮台，全爆后主体才可攻击 ——
@export var turret_hp := 80.0          # 每个炮台的血量
@export var turret_score := 600        # 打爆一个炮台的得分

# —— 招式①：环形弹幕（从核心 RingCore 向四周喷一整圈）——
@export var ring_attack := true        # 是否开启环形弹幕
@export var ring_count := 12           # 每圈几颗子弹（越少→缝隙越大越好躲；越多→越密越难）
@export var ring_bullet_speed := 300.0 # 子弹飞行速度（像素/秒，越慢越好躲）
@export var ring_interval := 1.8       # 每隔几秒发一圈（越大越宽松）
@export var ring_spin_deg := 13.0      # 每圈整体多转多少度（让缝隙错开、不固定一条死缝）

var _explosion_scene := preload("res://explosion.tscn")
var _bullet_scene := preload("res://boss_bullet.tscn")   # Boss 核心子弹
var _hp := 0.0
var _dead := false
var _entered := false      # 是否已压入就位
var _t := 0.0              # 左右游移用的时间累计
var _center_x := 0.0       # 屏幕水平中线
var _blink_t := 0.0        # 受击闪烁剩余时间

@onready var _body: Sprite2D = $Body
@onready var _body_col: CollisionPolygon2D = $CollisionPolygon2D
@onready var _ring_core: Marker2D = $RingCore

var _ring_t := 0.0          # 距离下一圈弹幕还差多久
var _ring_angle := 0.0      # 当前这圈的起始角度（每圈累加 ring_spin_deg，让缝隙错开）

var _turrets: Array = []        # 四个炮台，每个 {pivot, sprite, forward, hp, blink, dead}
var _turrets_alive := 0         # 还活着的炮台数
var _body_vulnerable := false   # 主体是否已可被攻击（四炮台全爆后才 true）

func _ready():
	_hp = max_hp
	add_to_group("enemy")        # 玩家子弹靠这个识别敌人
	add_to_group("boss")         # 单独标记，后续血条/波次管理用
	area_entered.connect(_on_area_entered)
	_setup_turrets()
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
		# 就位后：用正弦曲线缓慢左右游移
		_t += delta * drift_speed
		position.x = _center_x + sin(_t) * drift_x
	if _entered:
		_update_ring(delta)
	_aim_turrets(delta)
	_update_turret_blink(delta)
	_update_blink(delta)

# 招式①：每隔 ring_interval 秒，从核心向四周喷一圈子弹
func _update_ring(delta):
	if not ring_attack:
		return
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = ring_interval
		_fire_ring()

func _fire_ring():
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

# 启动时记下四个炮台的“支点节点”+图片+血量，并用各自的 Muzzle 确定“炮口正前方”
func _setup_turrets():
	for n in ["BarrelLeftPivot", "BarrelRightPivot", "DroneLeftPivot", "DroneRightPivot"]:
		var piv = get_node_or_null(n)
		if piv == null:
			continue
		var spr = piv.get_child(0)        # 支点下第一个子节点 = 炮台图片
		var fwd := 0.0
		var m = piv.find_child("Muzzle", true, false)   # 找到该炮台的炮口标记点
		if m:
			# 炮口相对“支点”的方向 = 这门炮在静止时的正前方
			fwd = piv.to_local(m.global_position).angle()
		var entry := {"pivot": piv, "sprite": spr, "forward": fwd, "hp": turret_hp, "blink": 0.0, "dead": false}
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
	var fx = _explosion_scene.instantiate()
	fx.global_position = entry["sprite"].global_position
	fx.scale = Vector2(0.45, 0.45)
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
		_enter_body_phase()

# 四个炮台全部被毁 → 打开主体碰撞，主体进入可攻击阶段
func _enter_body_phase():
	_body_vulnerable = true
	if _body_col:
		_body_col.set_deferred("disabled", false)   # 延后打开，避开物理回调内改碰撞的限制

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
	if not _body_vulnerable:       # 四个炮台没打完前，主体打不动
		return
	if area.is_in_group("bullet"):
		_hp -= area.damage
		area.queue_free()
		_blink_t = blink_persist
		if _hp <= 0.0:
			_dead = true
			_die()

func _die():
	# Boss 很大 → 在机身多个位置接连放爆炸，做出“连环炸开”的效果
	var offsets := [
		Vector2(0, 0), Vector2(-220, -40), Vector2(220, -40),
		Vector2(-120, 120), Vector2(120, 120), Vector2(0, -160),
	]
	for off in offsets:
		var fx = _explosion_scene.instantiate()
		fx.global_position = global_position + off
		fx.scale = Vector2(0.6, 0.6)   # 比普通爆炸大一些
		get_parent().add_child(fx)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_score(score_value)
	# 屏幕狠狠震一下
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(800.0)
	queue_free()
