extends Node2D
# Boss 中央核心：用 boss核心.png 显示，叠加受击闪白 + 越伤越红（不做大小浮动）。
# 行为由 boss.gd 调度（flash/set_damage）；图片节点是 $Sprite。

@export var flash_brightness := 1.4   # 受击闪白的亮度(1=不提亮,越大越白)。调小=更柔

@onready var _spr: Sprite2D = $Sprite
@onready var _boom: AnimatedSprite2D = $Boom
var _flash := 0.0     # 受击白光剩余秒数
var _damage := 0.0    # 损伤程度 0→1
var _exploded := false

func _ready():
	z_index = 10

func _process(delta):
	if _exploded:
		return                 # 已爆：停在废墟最后一帧，不再做受击染色
	if _flash > 0.0:
		_flash -= delta
	if _spr:
		# 平时原色不变；受击瞬间轻微提亮一下（不发红、不缩放）
		if _flash > 0.0:
			_spr.modulate = Color(flash_brightness, flash_brightness, flash_brightness, 1)
		else:
			_spr.modulate = Color(1, 1, 1, 1)

# boss.gd 每次受击后告诉当前损伤比例(0=满血,1=快爆)
func set_damage(ratio: float) -> void:
	_damage = clampf(ratio, 0.0, 1.0)

# boss.gd 每次命中时调一下：闪一下白光
func flash() -> void:
	_flash = 0.08

# 核心被打爆：藏起完整核心，播爆炸动画(不循环→停在最后一帧=废墟，永久留场)
func explode() -> void:
	_exploded = true
	if _spr:
		_spr.visible = false
	if _boom:
		_boom.visible = true
		_boom.play("default")
