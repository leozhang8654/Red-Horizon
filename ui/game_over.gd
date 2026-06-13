extends CanvasLayer
# 游戏结束画面：玩家死亡后不再瞬间冻结，而是一段"慢动作演出"——
# 世界越来越慢，"任务失败"字幕从小推到最大，推满的那一刻全场才彻底冻结。

# —— 演出参数（想调手感就改这里）——
@export var slowmo_duration := 1.2    # 演出总时长(真实秒)。调大=慢动作更久
@export var min_time_scale := 0.05    # 世界最慢能慢到几倍速(0.05=5%速度)。调小=更接近静止
@export var title_start_scale := 0.2  # 字幕起始大小(相对最终大小)。调小=从更小开始推

var _animating := false   # 演出进行中？
var _anim_t := 0.0         # 演出进度 0→1

func _ready():
	add_to_group("game_over")                 # 加入分组，方便玩家脚本用分组名找到我
	visible = false                           # 一开始藏起来，别挡住游戏
	process_mode = Node.PROCESS_MODE_ALWAYS   # 即使游戏暂停了我也能工作（演出和"按键重来"都靠它）

func show_game_over():
	if visible:
		return   # 已经在演了，别重复触发
	# 死亡瞬间 HUD 还在，去把当前分数读出来，写到结束画面上
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.snap_score()   # 顶部分数立刻定格成最终值（保证和结算分数一致）
		$Center/VBox/Final.text = "本局得分：%d" % hud.get_score()
	visible = true
	_anim_t = 0.0
	_animating = true
	_apply_anim(0.0)   # 先摆好第一帧（字幕最小、世界还是全速），避免闪一下大字

func _process(delta):
	if not _animating:
		return
	# Engine.time_scale 变慢时 delta 也会跟着缩水，除回去才是真实流逝的时间
	var real_delta = delta / max(Engine.time_scale, 0.0001)
	_anim_t = min(_anim_t + real_delta / slowmo_duration, 1.0)
	_apply_anim(_anim_t)
	if _anim_t >= 1.0:
		_animating = false
		Engine.time_scale = 1.0      # 恢复正常倍速（冻结交给 paused，别让慢动作漏到下一局）
		get_tree().paused = true     # 字幕推到最大 → 全场彻底冻结

# 按进度 t(0→1) 摆出当前这一帧：世界变慢 + 字幕推近 + 黑幕渐深
func _apply_anim(t: float) -> void:
	Engine.time_scale = max(lerp(1.0, 0.0, t), min_time_scale)   # 世界越来越慢
	var ease_t = 1.0 - (1.0 - t) * (1.0 - t)                     # 缓出：开头推得快，快到最大时变柔
	var s = lerp(title_start_scale, 1.0, ease_t)
	$Center.pivot_offset = $Center.size / 2.0   # 以屏幕中心为缩放支点
	$Center.scale = Vector2(s, s)
	$Bg.modulate.a = t                          # 半透明黑幕跟着渐渐变深

func _unhandled_input(event):
	# 演出没放完/画面没显示时，不理会按键
	if not visible or _animating:
		return
	# ui_accept 默认就绑定了空格键（也包括回车）
	if event.is_action_pressed("ui_accept"):
		Engine.time_scale = 1.0                          # 保险：把倍速恢复正常
		get_tree().paused = false                        # ★先解除暂停，否则新的一局也是冻住的
		get_tree().call_deferred("reload_current_scene") # 重新加载场景＝从头开始一局
