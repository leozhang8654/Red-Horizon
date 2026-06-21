extends Node2D
# 母舰内部 —— 平台跳跃关（第二关）。
# 目前是【空壳占位】：只有黑底 + 一行字，用来打通"飞机关→结算→切到这一关"的整条流程。
# 之后再往这里填真正的平台跳跃玩法（重力、跳跃、踩台子）。

func _ready():
	# 上一关结束时全场是冻结(paused)状态，切到新场景要解冻，否则这关也是僵的
	get_tree().paused = false

func _unhandled_input(event):
	# 临时方便：按 空格/回车 回到飞机关，免得跳进来出不去（正式玩法做好后会删掉）
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://main.tscn")
