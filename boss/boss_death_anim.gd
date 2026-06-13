extends AnimatedSprite2D
# Boss 死亡演出：播放 boss_death_frames/ 里的 76 帧爆炸解体动画(15帧/秒,约5秒)。
# 期间持续震屏 + 连环爆炸音；解体瞬间来一记大震；播完自动删除自己。

@export var shake_interval := 0.45    # 每隔几秒小震一下屏（越小震得越频繁）
@export var shake_strength := 220.0   # 每次小震的强度（像素，越大越猛）
@export var burst_frame := 9          # 第几帧算“解体瞬间”（此刻来一记大震）
@export var burst_shake := 800.0      # 解体瞬间的大震强度
@export var quiet_frame := 45         # 从第几帧开始收尾（碎片飞远，停止震动和音效）
@export var sound_interval := 0.65    # 爆炸音效每隔几秒补一声
@export var sound_pitch := 0.7        # 音效音调（<1 更低沉，听着像大爆炸）

var _shake_t := 0.0
var _snd_t := 0.0
var _burst_done := false

func _ready():
	animation_finished.connect(queue_free)   # 播完一遍就删掉自己
	$Sound.pitch_scale = sound_pitch
	$Sound.play()                            # 开场先来一声
	play("default")

func _process(delta):
	if frame >= quiet_frame:
		return                               # 收尾阶段：碎片安静地飞出画面
	# 解体瞬间的大震（只触发一次）
	if not _burst_done and frame >= burst_frame:
		_burst_done = true
		_shake(burst_shake)
		$Sound.play()
	# 周期性小震 + 补爆炸音，营造“还在持续殉爆”的感觉
	_shake_t += delta
	if _shake_t >= shake_interval:
		_shake_t = 0.0
		_shake(shake_strength)
	_snd_t += delta
	if _snd_t >= sound_interval:
		_snd_t = 0.0
		$Sound.pitch_scale = sound_pitch * randf_range(0.85, 1.15)   # 每声音调略有不同
		$Sound.play()

func _shake(strength: float):
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.shake(strength)
