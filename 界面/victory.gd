extends CanvasLayer
# 通关结算画面：Boss 被击毁后，等死亡爆炸演出放完，亮出"任务完成"结算页。
# 目前是"骨架版"：静态显示 击破得分/通关用时/时间分/最终得分/评级，按空格再来一局。
# 后续步骤再加演出（标题推近、逐行弹出、分数滚动、盖章震屏等）。

# —— 计分规则（都能在 Inspector 里调）——
@export var time_par_seconds := 145.0   # 时间基准线(秒)。145=2:25；比它快每秒加分、慢每秒减分
@export var time_points_per_sec := 20   # 每快/慢 1 秒，加/减多少分
# 评级线和基准线是配套校准的（锚点：S=无伤+1:35）。动了基准线要喊 Claude 重新算这三条
@export var rank_s := 16700             # S 评级线（最终得分 ≥ 这个数拿 S）＝无伤+1:35 的精确得分
@export var rank_a := 15900             # A 评级线 ＝掉1心+2:10
@export var rank_b := 14700             # B 评级线 ＝掉2心+3:00 附近（再低就是 C）
@export var show_delay := 7.0           # Boss 爆炸后等几秒再亮结算页（留给死亡演出+谢幕回位）
@export var finale_delay := 3.5         # Boss 爆炸后等几秒让玩家飞机开始谢幕冲刺
@export var push_duration := 0.6        # 结算页"从小推到大"的动画时长(秒)。调大=推得更慢
@export var row_interval := 0.45        # 结算清单每行之间的弹出间隔(秒)。调小=节奏更快
@export var pop_duration := 0.15        # 每个元素淡入的时长(秒)
@export var final_roll_duration := 1.0  # 最终得分从 0 滚到位要几秒
@export var stamp_start_scale := 3.0    # 评级章开砸时是原大的几倍。调大=从更高处砸下
@export var stamp_duration := 0.25      # 砸下来用几秒。调小=更干脆
@export var stamp_shake := 40.0         # 砸落瞬间结算页抖动的幅度(像素)。调大=震得更狠
@export var stamp_sound_lead := 0.08    # 盖章音效比画面落地提前几秒响。调大=声音更早

var _hint_blink := false                # 演出收尾后，提示语开始呼吸闪烁
var _blink_t := 0.0

const RECORD_PATH := "user://records.cfg"   # 历史最高分存档文件（和音量设置同款机制）
var _best_score := 0                        # 读出来的历史最高分

func _ready():
	add_to_group("victory")                   # 加入分组，boss.gd / pause.gd 用分组名找到我
	visible = false                           # 平时藏着
	process_mode = Node.PROCESS_MODE_ALWAYS   # 结算时全场冻结，我自己还要能收"空格进入母舰"

# Boss 死亡瞬间由 boss.gd 调用：立刻停表（用时只算到击杀那一刻），
# 然后按时间线推进：爆炸演出 → 飞机谢幕冲出屏幕 → 结算页推近登场
func boss_defeated():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.stop_timer()
	# 等爆炸转入"碎片飞散"阶段，让玩家飞机开始谢幕冲刺
	# （第二个参数 false = 游戏暂停时计时器也暂停，免得 ESC 暂停期间结算页硬闯进来）
	await get_tree().create_timer(finale_delay, false).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("start_finale"):
		player.start_finale()
	# 再等到爆炸演出彻底放完，亮结算页
	await get_tree().create_timer(max(show_delay - finale_delay, 0.1), false).timeout
	_show_victory()

func _show_victory():
	if visible:
		return
	# 保险：如果玩家在爆炸演出那几秒被流弹打死了，按"任务失败"算，结算页不再出来
	var go = get_tree().get_first_node_in_group("game_over")
	if go and go.visible:
		return
	var kill_score := 0
	var seconds := 0.0
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.snap_score()              # 分数立刻定格（含 Boss 的击杀分），保证显示和结算一致
		kill_score = hud.get_score()
		seconds = hud.get_time()
	# —— 计分公式：最终得分 = 击破得分 + 时间分（比基准快了加、慢了减）——
	var time_points := int(round((time_par_seconds - seconds) * time_points_per_sec))
	var final_score := kill_score + time_points
	# —— 无伤判定 + 历史最高分判定 ——
	var player = get_tree().get_first_node_in_group("player")
	var perfect: bool = player != null and player.has_method("took_no_damage") and player.took_no_damage()
	var record_broken := _update_record(final_score)

	# —— 把数字填进各行 ——
	var stats := $Center/VBox/Body/Stats
	stats.get_node("KillRow/Val").text = "%d" % kill_score
	stats.get_node("TimeRow/Val").text = _format_time(seconds)
	stats.get_node("BonusRow/Val").text = "%+d" % time_points   # %+d 自带正负号，如 +700 / -1000
	stats.get_node("FinalRow/Val").text = "0"                   # 最终得分稍后从 0 滚上去
	var rank_col := $Center/VBox/Body/RankBox/RankCol
	rank_col.get_node("RankCircle/Rank").text = _rank_of(final_score)
	rank_col.get_node("Perfect").visible = perfect              # 没无伤就整行不占位
	var high := $Center/VBox/HighScore
	if record_broken:
		high.text = "新纪录！"
		high.add_theme_color_override("font_color", Color(1, 0.85, 0.3))   # 破纪录用金色
	else:
		high.text = "历史最高  %d" % _best_score

	# —— 逐行弹出的准备：先把清单元素全调成透明（占位不变，页面大小不会跳动）——
	var sequence: Array = [
		stats.get_node("KillRow"), stats.get_node("TimeRow"), stats.get_node("BonusRow"),
		stats.get_node("Divider"), stats.get_node("FinalRow"),
		rank_col, high, $Center/VBox/Hint,
	]
	for c in sequence:
		c.modulate.a = 0.0

	visible = true
	get_tree().paused = true          # 冻住全场（我是 PROCESS_MODE_ALWAYS，动画照常播）
	# —— 标题推近：整页从 0.2 倍放大到原大 + 黑幕渐深（和"任务失败"同款动作，但不带慢动作）——
	$Center.pivot_offset = $Center.size / 2.0   # 以屏幕中心为缩放支点
	$Center.scale = Vector2(0.2, 0.2)
	$Bg.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)   # 缓出：开头快、收尾柔
	tw.tween_property($Center, "scale", Vector2.ONE, push_duration)
	tw.parallel().tween_property($Bg, "modulate:a", 1.0, push_duration)
	await tw.finished

	# —— 结算清单逐行弹出（街机式：一行一拍）——
	for row in [stats.get_node("KillRow"), stats.get_node("TimeRow"), stats.get_node("BonusRow")]:
		_pop(row)
		await get_tree().create_timer(row_interval).timeout
	# 分隔线和"最终得分"行一起亮出（同一瞬间，只响一声），然后数字从 0 滚到位
	_pop(stats.get_node("Divider"), false)
	_pop(stats.get_node("FinalRow"))
	var roll := create_tween()
	roll.tween_method(_set_final_text, 0.0, float(final_score), final_roll_duration)
	await roll.finished
	# 评级章"砸"下来（带 PERFECT）→ 新纪录/历史最高 → 操作提示，依次亮出
	await _stamp(rank_col)
	await get_tree().create_timer(row_interval).timeout
	_pop(high, false)                # 历史最高/新纪录：安静出现，不响
	_pop($Center/VBox/Hint, false)   # 提示语同样安静
	await get_tree().create_timer(pop_duration).timeout
	_hint_blink = true   # 提示语开始呼吸闪烁，告诉玩家"可以按空格了"

func _process(delta):
	# 演出收尾后让"按 空格 再来一局"呼吸闪烁（和标题页的提示同款）
	if _hint_blink:
		_blink_t += delta
		$Center/VBox/Hint.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink_t * 4.0))

# 让一个元素淡入亮相（逐行弹出用），默认伴随一声"叮"
# ding 传 false = 静音弹出（和别的元素同一瞬间出现时用，避免两声叠在一起）
func _pop(c: CanvasItem, ding := true) -> void:
	if ding:
		$Ding.play()
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, pop_duration)

# 评级章盖章动画：从 stamp_start_scale 倍大小越砸越快地缩到原大，落地瞬间抖一下结算页
func _stamp(c: Control) -> void:
	c.pivot_offset = c.size / 2.0          # 以自己的中心为缩放支点
	c.scale = Vector2(stamp_start_scale, stamp_start_scale)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)   # 缓入：越砸越快
	tw.tween_property(c, "scale", Vector2.ONE, stamp_duration)
	tw.parallel().tween_property(c, "modulate:a", 1.0, stamp_duration * 0.6)
	# 音效比落地画面提前 stamp_sound_lead 秒响：先等到"快落地"，响一声，再等动画收尾
	await get_tree().create_timer(max(stamp_duration - stamp_sound_lead, 0.0)).timeout
	$StampSound.play()
	await tw.finished
	await _shake_page()

# 抖动结算页本身（结算时全场冻结，世界相机的震屏对屏幕层无效，所以直接抖这一层）
func _shake_page() -> void:
	var tw := create_tween()
	for i in range(5):
		var strength: float = stamp_shake * (1.0 - i / 5.0)   # 越抖越轻，自然收住
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
		tw.tween_property(self, "offset", off, 0.04)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.05)
	await tw.finished

# 最终得分滚动期间，每帧把当前数字刷上去
func _set_final_text(v: float) -> void:
	$Center/VBox/Body/Stats/FinalRow/Val.text = "%d" % int(v)

# 读取并更新历史最高分存档；返回"这局是否破了纪录"（第一次通关也算新纪录）
func _update_record(score: int) -> bool:
	var cf := ConfigFile.new()
	var has_record := false
	if cf.load(RECORD_PATH) == OK and cf.has_section_key("record", "best_score"):
		has_record = true
		_best_score = cf.get_value("record", "best_score")
	if has_record and score <= _best_score:
		return false           # 没破纪录：保留旧纪录用于显示
	_best_score = score        # 破纪录（或首次通关）：写回存档
	cf.set_value("record", "best_score", score)
	cf.save(RECORD_PATH)
	return true

# 按最终得分划评级
func _rank_of(score: int) -> String:
	if score >= rank_s:
		return "S"
	if score >= rank_a:
		return "A"
	if score >= rank_b:
		return "B"
	return "C"

# 秒数 → "分:秒"，如 95.4 → 01:35（和 HUD 左上角计时同款格式）
func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):   # 空格（或回车）：再来一局
		get_tree().paused = false                        # 先解冻，否则新一局也是僵的
		get_tree().call_deferred("reload_current_scene") # 重新加载场景＝从头开始
