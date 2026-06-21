extends Area2D

# 敌人子弹向下飞的速度（像素/秒），由发射的敌机设置/可在 Inspector 调
@export var speed := 1000.0

func _ready():
	# 加入“敌人子弹”组，将来玩家靠这个识别它（和玩家子弹区分开）
	add_to_group("enemy_bullet")

func _physics_process(delta):
	# 向下移动（朝屏幕下方的玩家）
	position.y += speed * delta
	# 飞出屏幕底部就消失，避免越积越多
	if position.y > get_viewport_rect().size.y + 100.0:
		queue_free()
