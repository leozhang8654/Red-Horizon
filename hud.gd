extends CanvasLayer

# 屏幕左下角的爱心血条。玩家扣血时调用 set_hearts() 更新显示。

const HEART_TEX := preload("res://health icon.png")   # 爱心图标
const INFINITY_TEX := preload("res://infinity icon.png")   # ♾️ 图标(无限血量作弊时显示)

@onready var _score_label: Label = $Score   # 左上角的分数文字
@onready var _time_label: Label = $TimeLabel  # 左上角的计时器文字
@onready var _hearts_box: Control = $Hearts  # 爱心容器（整体闪烁用）

var _time := 0.0            # 本局已经玩了多少秒（真实游戏时间，不含标题页/暂停）
var _timer_running := false  # 计时器在走吗？（按空格开始后 true，死亡瞬间 false）
var _hearts: Array = []                      # 当前所有爱心图标节点（动态生成）
var _infinity_icon: TextureRect = null       # ♾️ 图标节点（第一次用到时才创建）
var _infinite := false                       # 当前是否处于“无限血量”显示状态
var _score := 0                              # 当前分数（真实值，加分时立刻到位）
var _display_score := 0.0                     # 屏幕上正在显示的分数（一点点往上追真实值）
var _heart_flash_t := 0.0                    # 爱心闪烁还剩多久

# 滚动追分时长：不管一次加/减多少分，都用这么多秒滚完。调小=更快滚完。
@export var score_roll_duration := 1.5

# 血条渐显时长（秒）：标题页按空格开始后，爱心从透明慢慢浮现要花多久。调大=浮现更慢
@export var hearts_fade_in_duration := 1.2
var _hearts_revealed := false   # 血条是否已经渐显过（防止重复触发）

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
	_hearts_box.modulate.a = 0.0   # 标题页期间血条先藏起来，等游戏开始再渐显
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
	# 计时器走表：游戏开始后才走；HUD 是 PROCESS_MODE_ALWAYS（暂停时也在跑），
	# 所以要自己判断"全场暂停时不计时"，否则开着暂停菜单时间也在涨
	if _timer_running and not get_tree().paused:
		_time += delta
		_update_time_label()

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

# 血条渐显：标题页按空格开始游戏时，开始画面会调用这里
func reveal_hearts() -> void:
	if _hearts_revealed:
		return
	_hearts_revealed = true
	_timer_running = true   # 玩家按空格正式开局 → 计时器开始走
	var tw := create_tween()   # tween = 引擎自带的"补间动画"，让数值在一段时间内平滑变化
	tw.tween_property(_hearts_box, "modulate:a", 1.0, hearts_fade_in_duration)

# 显示 n 个爱心（其余隐藏）；无限血量模式下爱心始终隐藏，由 ♾️ 顶替
func set_hearts(n: int) -> void:
	for i in range(_hearts.size()):
		_hearts[i].visible = (i < n) and not _infinite

# 无限血量作弊的显示开关：开 = 藏起所有爱心、亮出 ♾️；关 = 收起 ♾️
# （关掉后玩家脚本会再调一次 set_hearts() 恢复真实血量显示）
func set_infinite_hearts(on: bool) -> void:
	_infinite = on
	if on and _infinity_icon == null:
		# 第一次开启时创建 ♾️ 图标，规格和爱心一致(高192)，宽按图片比例约2:1
		_infinity_icon = TextureRect.new()
		_infinity_icon.texture = INFINITY_TEX
		_infinity_icon.custom_minimum_size = Vector2(384, 192)
		_infinity_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_infinity_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts_box.add_child(_infinity_icon)
	if _infinity_icon:
		_infinity_icon.visible = on
	if on:
		for h in _hearts:
			h.visible = false

# 加分：敌人死的时候会调用它
func add_score(points: int) -> void:
	_score += points   # 真实分数立刻到位，显示的数字由 _process 慢慢追上来
	# 按"剩余差距 ÷ 固定时长"现算滚动速度：不管差多少分，都恰好用 score_roll_duration 秒滚完
	_roll_speed = abs(float(_score) - _display_score) / score_roll_duration

# 把当前显示的分数刷到屏幕左上角
func _update_score_label() -> void:
	# 用显示值（取整、去掉负号）来画；负数靠红色表示，不显示负号
	_score_label.text = "%06d" % int(abs(_display_score))   # 6 位前导零，街机记分牌风格，如 000100

# 把秒数刷成"分:秒"画到屏幕上，比如 83 秒 → 01:23
# （冒号是后来用 Python 画进分数字体图里的，和数字同款像素风）
func _update_time_label() -> void:
	var total := int(_time)
	_time_label.text = "%02d:%02d" % [total / 60, total % 60]

# 把当前用时报出去（游戏结束画面会来问），格式同屏幕显示
func get_time_text() -> String:
	var total := int(_time)
	return "%02d:%02d" % [total / 60, total % 60]

# 把通关用时按"秒数"报出去（通关结算画面拿它算时间分）
func get_time() -> float:
	return _time

# 停表（Boss 被击毁那一刻，通关结算画面会来调用，免得爆炸演出那几秒也被算进用时）
func stop_timer() -> void:
	_timer_running = false

# 让显示立刻追上真实分数，不再滚动（游戏结束瞬间调用，保证和结算分数一致）
func snap_score() -> void:
	_timer_running = false   # 玩家阵亡瞬间停表，慢动作演出期间时间不再涨
	_display_score = float(_score)
	var col = score_lose_color if _score < 0 else _score_normal_color
	_score_label.add_theme_color_override("font_color", col)
	_update_score_label()

# 把当前分数报出去（游戏结束画面会来问）
func get_score() -> int:
	return _score
