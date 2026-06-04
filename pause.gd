extends CanvasLayer
# 暂停菜单：按 ESC 暂停并显示菜单，再按 ESC 继续；暂停时按 R 重新开始。
# 开发者作弊：在密码框输入正确密码后，出现“波数跳跃”，输入波数即可跳转。

const DEV_PASSWORD := "123456"

@onready var _pass_edit: LineEdit = $Center/VBox/PassEdit
@onready var _dev_panel: VBoxContainer = $Center/VBox/DevPanel
@onready var _wave_edit: LineEdit = $Center/VBox/DevPanel/Row/WaveEdit
@onready var _jump_btn: Button = $Center/VBox/DevPanel/Row/JumpBtn

func _ready():
	add_to_group("pause_menu")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时我也要能响应按键
	_dev_panel.visible = false
	_pass_edit.text_changed.connect(_on_pass_changed)   # 边输边检查密码
	_jump_btn.pressed.connect(_on_jump)                 # 点“跳转”

func _on_pass_changed(t: String):
	_dev_panel.visible = (t == DEV_PASSWORD)            # 密码正确才显示跳波面板

func _on_jump():
	var n := int(_wave_edit.text)
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.jump_to_wave(n):
		# 跳转成功 → 关闭暂停继续游戏
		get_tree().paused = false
		visible = false

func _unhandled_input(event):
	# 如果“游戏结束”画面正显示，暂停就别来插手（避免两个菜单打架）
	var go = get_tree().get_first_node_in_group("game_over")
	if go and go.visible:
		return

	# ESC：暂停 / 继续 来回切换
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

	# 暂停状态下，按 R 重新开始本局
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().paused = false                        # 先解除暂停，否则新一局也是冻住的
		get_tree().call_deferred("reload_current_scene")

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
