extends Area2D

# 子弹向上飞的速度（像素/秒）
@export var speed := 3000.0
# 子弹攻击力（打中敌人扣多少血）
@export var damage := 1.0

func _ready():
	# 加入“子弹”组，敌人靠这个识别它
	add_to_group("bullet")

func _physics_process(delta):
	# 向上移动（屏幕里 y 减小 = 往上）
	position.y -= speed * delta
	# 飞出屏幕顶部（留 100 像素余量）就把自己释放掉，避免越积越多
	if position.y < -100.0:
		queue_free()
