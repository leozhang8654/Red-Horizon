extends Area2D
# Boss 环形弹幕的子弹：沿发射时设定的方向匀速直飞，飞出屏幕外就自毁。
# 属 "enemy_bullet" 组 → 玩家的受伤判定靠这个识别它。

@export var speed := 300.0          # 飞行速度（像素/秒），由 Boss 发射时设定
var direction := Vector2.DOWN       # 单位方向向量，由 Boss 发射时设定

func _ready():
	add_to_group("enemy_bullet")

func _physics_process(delta):
	position += direction * speed * delta
	# 飞到屏幕外（留 150 像素余量）就删掉，避免越积越多
	var vp: Vector2 = get_viewport_rect().size
	if position.x < -150.0 or position.x > vp.x + 150.0 or position.y < -150.0 or position.y > vp.y + 150.0:
		queue_free()
