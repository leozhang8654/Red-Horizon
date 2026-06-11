extends CanvasLayer

# 屏幕左下角的爱心血条。玩家扣血时调用 set_hearts() 更新显示。

const HEART_TEX := preload("res://health icon.png")   # 爱心图标

@onready var _score_label: Label = $Score   # 左上角的分数文字
@onready var _hearts_box: Control = $Hearts  # 爱心容器（整体闪烁用）
var _hearts: Array = []                      # 当前所有爱心图标节点（动态生成）
var _score := 0                              # 当前分数（真实值，加分时立刻到位）
var _display_score := 0.0                     # 屏幕上正在显示的分数（一点点往上追真实值）
var _heart_flash_t := 0.0                    # 爱心闪烁还剩多久

# 滚动追分时长：不管一次加/减多少分，都用这么多秒滚完。调小=更快滚完。
@export var score_roll_duration := 1.5

var _roll_speed := 0.0   # 当前这轮滚动的速度(每秒多少分)，每次加减分时按差距现算
# 减分时分数显示的颜色（默认红色），调这里换颜色
@export var score_lose_color := Color.RED

var _score_normal_color := Color.WHITE   # 分数平时的颜色（_ready 里记下来）

func _ready():
	add_to_group("hud")   # 让玩家、敌人都能用分组找到我
	process_mode = Node.PROCESS_MODE_ALWAYS   # 游戏暂停/结束冻结全场时，分数滚动动画也要继续跑完，否则显示会停在半路、和结算分数对不上
	_score_normal_color = _score_label.get_theme_color("font_color")  # 记住原本的颜色
	# 收集场景里已经摆好的爱心作为初始（之后由玩家的 max_hearts 自动补齐/删减）
	for c in _hearts_box.get_children():
		_hearts.append(c)
	_update_score_label()

# 玩家开局会调用：告诉 HUD 一共几颗心 → 自动补齐或删多余，血条数量永远和 max_hearts 一致
func set_max_hearts(n: int) -> void:
	while _hearts.size() < n:
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(192, 192)
		heart.texture = HEART_TEX
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts_box.add_child(heart)
		_hearts.append(heart)
	while _hearts.size() > n:
		var heart = _hearts.pop_back()
		heart.queue_free()
	set_hearts(n)

func _process(delta):
	# 让显示的分数一点点追真实分数（街机滚动记分牌效果，加分往上滚、减分往下滚）
	if _display_score < _score:
		# 往上滚（加分）：负数仍显示红色，到 0 以上才用平时的颜色
		_display_score = min(_display_score + _roll_speed * delta, float(_score))
		var col = score_lose_color if _display_score < 0 else _score_normal_color
		_score_label.add_theme_color_override("font_color", col)
		_update_score_label()
	elif _display_score > _score:
		# 往下滚（减分）：过程中显示红色
		_display_score = max(_display_score - _roll_speed * delta, float(_score))
		_score_label.add_theme_color_override("font_color", score_lose_color)
		_update_score_label()
		if _display_score == float(_score):
			# 减完了：如果分数是负的就保持红色，否则恢复正常
			var col = score_lose_color if _score < 0 else _score_normal_color
			_score_label.add_theme_color_override("font_color", col)

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
	_score += points   # 真实分数立刻到位，显示的数字由 _process 慢慢追上来
	# 按"剩余差距 ÷ 固定时长"现算滚动速度：不管差多少分，都恰好用 score_roll_duration 秒滚完
	_roll_speed = abs(float(_score) - _display_score) / score_roll_duration

# 把当前显示的分数刷到屏幕左上角
func _update_score_label() -> void:
	# 用显示值（取整、去掉负号）来画；负数靠红色表示，不显示负号
	_score_label.text = "%06d" % int(abs(_display_score))   # 6 位前导零，街机记分牌风格，如 000100

# 让显示立刻追上真实分数，不再滚动（游戏结束瞬间调用，保证和结算分数一致）
func snap_score() -> void:
	_display_score = float(_score)
	var col = score_lose_color if _score < 0 else _score_normal_color
	_score_label.add_theme_color_override("font_color", col)
	_update_score_label()

# 把当前分数报出去（游戏结束画面会来问）
func get_score() -> int:
	return _score
