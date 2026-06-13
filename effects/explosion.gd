extends AnimatedSprite2D
# 一次性爆炸动画：在敌人死的位置生成，播一遍就删掉自己。

@export var sound_volume_db := 0.0   # 爆炸音效音量（dB，负数变小、正数变大）

func _ready():
	$Sound.volume_db = sound_volume_db          # 应用脚本里设定的音量
	animation_finished.connect(_on_anim_done)   # 动画(非循环)播完后处理收尾
	play("default")                             # 开始播放
	# 触发屏幕震动：找到震动摄像机，让它抖一下
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(100.0)                        # 震动幅度（像素），越大越猛

func _on_anim_done():
	# 动画画面播完了，先隐身；若音效还在响，等它放完再删，避免声音被掐断
	hide()
	var snd: AudioStreamPlayer = $Sound
	if snd.playing:
		snd.finished.connect(queue_free)
	else:
		queue_free()
