extends CanvasLayer
# 游戏结束画面：平时藏起来，玩家死了才显示，并把整个游戏“冻住”(暂停)。

func _ready():
	add_to_group("game_over")                 # 加入分组，方便玩家脚本用分组名找到我
	visible = false                           # 一开始藏起来，别挡住游戏
	process_mode = Node.PROCESS_MODE_ALWAYS   # 即使游戏暂停了我也能工作（为下一步“按键重来”铺路）

func show_game_over():
	# 死亡瞬间 HUD 还在，去把当前分数读出来，写到结束画面上
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		$Center/VBox/Final.text = "本局得分：%d" % hud.get_score()
	visible = true                # 把“游戏结束”画面显示出来
	get_tree().paused = true      # 暂停整个游戏树：敌人、子弹、玩家全部冻住

func _unhandled_input(event):
	# 只有在“游戏结束”画面显示时才理会按键
	if not visible:
		return
	# ui_accept 默认就绑定了空格键（也包括回车）
	if event.is_action_pressed("ui_accept"):
		get_tree().paused = false                        # ★先解除暂停，否则新的一局也是冻住的
		get_tree().call_deferred("reload_current_scene") # 重新加载场景＝从头开始一局
