extends CanvasLayer

# 屏幕左下角的爱心血条。玩家扣血时调用 set_hearts() 更新显示。

@onready var _hearts: Array = [
	$Hearts/H1,
	$Hearts/H2,
	$Hearts/H3,
]
@onready var _score_label: Label = $Score   # 左上角的分数文字
@onready var _hearts_box: Control = $Hearts  # 爱心容器（整体闪烁用）
var _score := 0                              # 当前分数
var _heart_flash_t := 0.0                    # 爱心闪烁还剩多久

func _ready():
	add_to_group("hud")   # 让玩家、敌人都能用分组找到我
	_update_score_label()

func _process(delta):
	if _heart_flash_t > 0.0:
		_heart_flash_t -= delta
		# 快速闪烁：透明度在 0.25 和 1 之间交替
		_hearts_box.modulate.a = 0.25 if fmod(_heart_flash_t * 12.0, 1.0) < 0.5 else 1.0
		if _heart_flash_t <= 0.0:
			_hearts_box.modulate.a = 1.0   # 恢复

# 让爱心闪烁 duration 秒（玩家受伤时调用，作为受击提醒）
func flash_hearts(duration: float) -> void:
	_heart_flash_t = duration

# 显示 n 个爱心（其余隐藏）
func set_hearts(n: int) -> void:
	for i in range(_hearts.size()):
		_hearts[i].visible = i < n

# 加分：敌人死的时候会调用它
func add_score(points: int) -> void:
	_score += points
	_update_score_label()

# 把当前分数刷到屏幕左上角
func _update_score_label() -> void:
	_score_label.text = "%06d" % _score   # 6 位前导零，街机记分牌风格，如 000100

# 把当前分数报出去（游戏结束画面会来问）
func get_score() -> int:
	return _score
