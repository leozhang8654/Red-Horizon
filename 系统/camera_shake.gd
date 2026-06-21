extends Camera2D
# 屏幕震动摄像机：固定在屏幕中心不动；别的脚本调用 shake() 就抖一下，然后自己迅速平息。

@export var decay := 12.0     # 平息速度，越大停得越快
var _strength := 0.0          # 当前抖动强度(像素)

func _ready():
	add_to_group("camera")                          # 让别的脚本能用分组找到我
	position = get_viewport_rect().size / 2         # 对准“实际窗口”的正中心（窗口最大化也不会偏）
	make_current()                                  # 把自己设为当前生效的摄像机

func shake(strength: float) -> void:
	# 取较大值：连续爆炸时不会互相抵消，而是叠加成更强的一震
	_strength = max(_strength, strength)

func _process(delta):
	if _strength <= 0.1:
		_strength = 0.0
		offset = Vector2.ZERO     # 完全停下，归位
		return
	# 强度随时间衰减（越来越小）
	_strength = lerp(_strength, 0.0, clamp(decay * delta, 0.0, 1.0))
	# 每帧把镜头随机偏移一点点，制造抖动（只上下抖，左右固定为 0）
	offset = Vector2(0, randf_range(-_strength, _strength))
