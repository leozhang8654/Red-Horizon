extends AnimatableBody2D

# 向下滚动速度（像素/秒）。建议和背景 background.gd 里的 scroll_speed 保持一致。
@export var scroll_speed := 150.0

var _bottom: float   # 屏幕底部的 y 坐标
var _wrap: float     # 循环高度：滚出底部后，往上跳这么多，重新从顶部进场

func _ready():
	_bottom = get_viewport_rect().size.y
	_wrap = _bottom + 200.0   # +200 留点余量，保证整块完全离开屏幕后再循环

func _physics_process(delta):
	position.y += scroll_speed * delta
	if position.y > _bottom:
		position.y -= _wrap
