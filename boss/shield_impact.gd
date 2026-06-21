extends AnimatedSprite2D
# Boss 隐形盾命中特效：在命中点冒出一个六边形能量盾涟漪，播一遍(不循环)后自删。
# 由 boss.gd 在每个被本体挡下的命中点 spawn 一个。

func _ready():
	z_index = 50                                # 盖在船体/子弹上面
	animation_finished.connect(queue_free)      # 播完(非循环)自己消失
	play("default")
