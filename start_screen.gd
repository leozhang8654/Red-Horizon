extends CanvasLayer
# 开始页面（标题页）：游戏一启动就冻住全场并显示；按【空格】开始 → 收起页面、解冻、开打。
# 和"游戏结束""暂停"一样是 main.tscn 里的覆盖层，不切换场景。

var _t := 0.0
@onready var _prompt: Label = $Center/VBox/Prompt

func _ready():
	add_to_group("start_screen")            # 让暂停菜单知道"标题页正开着"，别来抢 ESC
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时我也要能闪烁、能收按键
	visible = true
	get_tree().paused = true                 # 冻住全场，等玩家开始

func _process(delta):
	# "按 空格 开始"呼吸闪烁
	_t += delta
	_prompt.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 4.0))

func _input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()   # 吃掉这次空格，别让它跑去当"闪避"
		_start_game()

func _start_game():
	visible = false
	get_tree().paused = false                # 解冻 → 第一波开始倒计时
	# 喊一声 HUD：游戏开始了，把血条慢慢显示出来
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.reveal_hearts()
