extends Control

# 一格护盾（用贴图显示），顶替原来的爱心。
# lit=true  → 有血：亮青盾牌
# lit=false → 掉了：暗壳盾牌（直接熄灭，格子还在原位）
# warning=true 且 lit → 在亮青盾上叠加红盾、淡入淡出脉动（剩最后一格的警告）

const TEX_FULL := preload("res://界面/art/界面护盾格满.png")    # 有血（亮青）
const TEX_EMPTY := preload("res://界面/art/界面护盾格空.png")  # 掉了（暗壳）
const TEX_WARN := preload("res://界面/art/界面护盾格警.png")    # 警告（红，叠在亮青上闪）

@export var warn_speed := 8.0   # 残血闪红的快慢，调大=闪得更急

var lit := true: set = set_lit          # 这格有没有血
var warning := false: set = set_warning  # 这格要不要闪红
var _t := 0.0   # 闪红用的相位计时

func _ready() -> void:
	set_process(false)            # 平时不用每帧跑，只有闪红时才开
	resized.connect(queue_redraw)  # 容器改变大小时重画，保证盾牌跟着缩放

func set_lit(v: bool) -> void:
	lit = v
	queue_redraw()

func set_warning(v: bool) -> void:
	if warning == v:
		return
	warning = v
	_t = 0.0
	set_process(v)   # 开始/停止闪红动画
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var base := TEX_FULL if lit else TEX_EMPTY
	var r := _fit_rect(base.get_size())
	draw_texture_rect(base, r, false)
	if lit and warning:
		# 红盾透明度 0↔1 来回脉动，叠在亮青盾上 → 看起来在闪红
		var k := 0.5 + 0.5 * sin(_t * warn_speed)
		draw_texture_rect(TEX_WARN, r, false, Color(1, 1, 1, k))

# 把贴图按比例缩放、居中塞进当前控件大小里（保持盾牌不变形）
func _fit_rect(tex_size: Vector2) -> Rect2:
	var s := size
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or s.x <= 0.0 or s.y <= 0.0:
		return Rect2(Vector2.ZERO, s)
	var scale := minf(s.x / tex_size.x, s.y / tex_size.y)
	var draw_size := tex_size * scale
	return Rect2((s - draw_size) * 0.5, draw_size)
