extends Parallax2D

# 背景向下滚动的速度（像素/秒）。想快/慢就改这个数。
@export var scroll_speed := 60.0

func _ready():
	_fit_to_screen()
	# 窗口尺寸变化时重新铺一次，保证始终盖满
	# （网页版开场时窗口是开局后才被浏览器撑大的，不重算就会两边露灰）
	get_viewport().size_changed.connect(_fit_to_screen)
	# 自动向下滚动
	autoscroll = Vector2(0, scroll_speed)

func _fit_to_screen():
	var top: Sprite2D = $Top
	var bottom: Sprite2D = $Bottom
	var tex_size: Vector2 = top.texture.get_size()      # 单段原始尺寸 (1024, 15360)
	var view_width: float = get_viewport_rect().size.x   # 当前窗口宽度

	# 1) 放大每一段，让宽度刚好盖满窗口（高度等比例放大，不变形）
	var s: float = view_width / tex_size.x
	top.scale = Vector2(s, s)
	bottom.scale = Vector2(s, s)

	# 2) 上下两段拼接：上段在顶部，下段紧接其下
	var seg_h: float = tex_size.y * s     # 放大后单段高度
	top.position = Vector2(0, 0)
	bottom.position = Vector2(0, seg_h)

	# 3) 告诉 Parallax2D：每隔“两段合起来的总高度”就无缝重复一次 → 无限
	repeat_size = Vector2(0, seg_h * 2.0)
