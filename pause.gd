extends CanvasLayer
# 暂停菜单：按 ESC 暂停并显示菜单，再按 ESC 继续；暂停时按 R 重新开始。
# 开发者作弊：在密码框输入正确密码后，出现“波数跳跃”，输入波数即可跳转。

const DEV_PASSWORD := "123456"
const SETTINGS_PATH := "user://settings.cfg"   # 存设置(音量等)的文件

@onready var _pass_edit: LineEdit = $Center/VBox/PassEdit
@onready var _dev_panel: VBoxContainer = $Center/VBox/DevPanel
@onready var _wave_edit: LineEdit = $Center/VBox/DevPanel/Row/WaveEdit
@onready var _jump_btn: Button = $Center/VBox/DevPanel/Row/JumpBtn
@onready var _god_toggle: CheckButton = $Center/VBox/DevPanel/GodRow/GodToggle
@onready var _vol_slider: HSlider = $Center/VBox/VolumeRow/VolSlider

func _ready():
	add_to_group("pause_menu")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时我也要能响应按键
	_dev_panel.visible = false
	_pass_edit.text_changed.connect(_on_pass_changed)   # 边输边检查密码
	_jump_btn.pressed.connect(_on_jump)                 # 点“跳转”
	_god_toggle.toggled.connect(_on_god_toggled)        # 拨“开挂模式”开关
	# —— 总音量：读取上次设置 → 应用 → 让滑条联动 ——
	var v := _load_volume()
	_vol_slider.value = v
	_apply_volume(v)
	_vol_slider.value_changed.connect(_on_volume_changed)

# 拖动音量滑条：实时改主总线(Master)音量并存盘
func _on_volume_changed(v: float) -> void:
	_apply_volume(v)
	_save_volume(v)

func _apply_volume(v: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if v <= 0.001:
		AudioServer.set_bus_mute(idx, true)                   # 拉到 0 = 静音
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))   # 线性音量(0~1)转成分贝

func _load_volume() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return float(cfg.get_value("audio", "master", 1.0))
	return 1.0   # 没存过 → 默认最大

func _save_volume(v: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)                              # 先读旧的(没有也没关系)
	cfg.set_value("audio", "master", v)
	cfg.save(SETTINGS_PATH)

func _on_pass_changed(t: String):
	_dev_panel.visible = (t == DEV_PASSWORD)            # 密码正确才显示跳波面板

# 开挂模式开关：转告玩家开/关（免伤+攻击力翻倍，血条显示成 ♾️）
func _on_god_toggled(on: bool):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_god_mode"):
		player.set_god_mode(on)

func _on_jump():
	var n := int(_wave_edit.text)
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.jump_to_wave(n):
		# 跳转成功 → 关闭暂停继续游戏
		get_tree().paused = false
		visible = false

# 空格“继续”、R“重开”：都用 _input 优先拦截，确保即使焦点在密码框里也照样触发
func _input(event):
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()            # 吃掉空格，别让它输进密码框/当“闪避”
		get_tree().paused = false                        # 继续游戏
		visible = false
	elif event.keycode == KEY_R:
		get_viewport().set_input_as_handled()            # 吃掉 R，别让它输进密码框
		get_tree().paused = false                        # 先解除暂停，否则新一局也是冻住的
		get_tree().call_deferred("reload_current_scene") # 重新开始本局

func _unhandled_input(event):
	# 如果“游戏结束”画面正显示，暂停就别来插手（避免两个菜单打架）
	var go = get_tree().get_first_node_in_group("game_over")
	if go and go.visible:
		return
	# 标题页还开着时，ESC 也别来插手
	var ss = get_tree().get_first_node_in_group("start_screen")
	if ss and ss.visible:
		return

	# ESC：只负责“打开暂停”（继续游戏改用空格、重开用 R，都在 _input 里处理）
	if event.is_action_pressed("ui_cancel") and not visible:
		_toggle_pause()

func _toggle_pause():
	if get_tree().paused:
		get_tree().paused = false   # 当前已暂停 → 继续游戏
		visible = false             # 收起菜单
	else:
		get_tree().paused = true    # 冻住全场
		visible = true              # 弹出菜单
		_pass_edit.text = ""        # 清空密码框
		_dev_panel.visible = false  # 收起作弊面板（每次都要重新输密码）
		_pass_edit.grab_focus()     # 自动聚焦密码框，方便直接输入
