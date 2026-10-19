class_name ForgeSequence
extends Node

## 三工位、三种操作：鼓风连按 → 按住淬火 → 移动条凿击。
enum Step { HEAT, QUENCH, CHISEL }
const TIME_LIMIT := 120.0
const STEP_NAMES := ["选料添炭", "淬火控温", "顺纹凿击"]
const STEP_HINTS := ["快速连按 E 对抗降温回退，把炉温推入橙区", "按住 E 淬火；四段水阻速度不同，进入蓝区立即松开", "观察往返指针，进入裂纹亮区时按 E"]
const ROUNDS_BY_STEP := [4, 4, 3]
const TOTAL_ACTIONS := 11
const CURSOR_SPEEDS := [1.10, 1.40, 1.74]
const TARGET_WIDTHS := [0.135, 0.14, 0.145]
const HEAT_TAP_GAIN := 0.12
const HEAT_DECAY_BASE := 0.205
const MISS_TIME_PENALTY := 5.0
const PERFECT_TIME_BONUS := 1.0
const ROUND_SPEED_GROWTH := 0.15
const ROUND_WIDTH_SHRINK := 0.075

var current_step: int = Step.HEAT
var current_round := 0
var time_left := TIME_LIMIT
var score := 0
var combo := 0
var best_combo := 0
var _active := true
var _timing := false
var _resolving := false
var _cursor_value := 0.05
var _cursor_dir := 1.0
var _target_center := 0.5
var _holding := false
var _wall: Node
var _timer_label: Label
var _notice: Label
var _player: Node
var _panel: Panel
var _title: Label
var _hint: Label
var _target: ColorRect
var _perfect: ColorRect
var _cursor: ColorRect
var _result: Label
var _progress: Label
var _bar: ColorRect
var _segment_markers: Array[ColorRect] = []
var _stations: Dictionary = {}
var _quench_zone := -1
var _story_paused := false
var _ui_layer: CanvasLayer

func _ready() -> void:
	_acquire_refs()
	_build_timing_ui()
	_refresh_timer()
	_show_notice("先到窑炉旁连续鼓风，把炉温送进橙色区域")

func _acquire_refs() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		cur = get_parent()
	_wall = cur.find_child("di_erguan_yanbi", true, false)
	_stations = {
		Step.HEAT: cur.find_child("HeatStation", true, false),
		Step.QUENCH: cur.find_child("QuenchStation", true, false),
	}
	_timer_label = cur.find_child("UI_Timer", true, false) as Label
	_notice = cur.find_child("UI_Notice", true, false) as Label
	_player = cur.find_child("zhujue", true, false)

func _process(delta: float) -> void:
	if not _active:
		return
	var director := get_node_or_null("/root/StoryDirector")
	if _story_paused or (director != null and bool(director.get("busy"))):
		return
	var arrival := get_node_or_null("/root/ChapterArrival")
	if arrival != null and bool(arrival.call("is_presenting")):
		return # 时空字幕不占用窑场的限时操作时间。
	time_left = maxf(0.0, time_left - delta)
	_refresh_timer()
	if time_left <= 0.0:
		_fail_timeout()
		return
	if _timing and not _resolving:
		match current_step:
			Step.HEAT:
				var decay := HEAT_DECAY_BASE + float(current_round) * 0.055 + _cursor_value * 0.045
				_cursor_value = maxf(0.04, _cursor_value - delta * decay)
			Step.QUENCH:
				if _holding:
					_cursor_value = maxf(0.0, _cursor_value - delta * _quench_cooling_rate())
					_update_quench_resistance()
					if _cursor_value <= 0.0:
						_holding = false
						_judge()
			Step.CHISEL:
				_cursor_value += _cursor_dir * _current_speed() * delta
				if _cursor_value >= 1.0:
					_cursor_value = 1.0
					_cursor_dir = -1.0
				elif _cursor_value <= 0.0:
					_cursor_value = 0.0
					_cursor_dir = 1.0
		_layout_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if not _timing or _resolving:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match current_step:
			Step.HEAT:
				_heat_tap()
			Step.QUENCH:
				_holding = true
			Step.CHISEL:
				_judge()
	elif current_step == Step.QUENCH and _holding and event.is_action_released("interact"):
		get_viewport().set_input_as_handled()
		_holding = false
		_judge()

func advance() -> void:
	open_station(current_step)

func open_station(station_step: int) -> void:
	if not _active or _timing:
		return
	if station_step != current_step:
		_show_notice("当前工序：%s，请前往对应工位" % STEP_NAMES[current_step])
		return
	_timing = true
	_set_station_effect(station_step, true)
	if _notice != null:
		_notice.visible = false
	if _player != null and _player.has_method("freeze"):
		_player.call("freeze", true)
	_panel.visible = true
	_prepare_attempt()

func set_story_paused(value: bool) -> void:
	_story_paused = value

func interact_heat() -> void:
	open_station(Step.HEAT)
func interact_quench() -> void:
	open_station(Step.QUENCH)
func interact_chisel() -> void:
	open_station(Step.CHISEL)

func _prepare_attempt() -> void:
	_resolving = false
	_holding = false
	_quench_zone = -1
	match current_step:
		Step.HEAT:
			_cursor_value = 0.06
			_target_center = randf_range(0.84, 0.90)
			_target.color = Color("#e8833f")
			_perfect.color = Color("#ffe16b")
		Step.QUENCH:
			_cursor_value = 1.0
			_target_center = randf_range(0.30, 0.60)
			_target.color = Color("#5ca8c9")
			_perfect.color = Color("#b9f2ff")
		Step.CHISEL:
			_cursor_value = 0.04 if _cursor_dir > 0.0 else 0.96
			_target_center = randf_range(0.29, 0.71)
			_target.color = Color("#5cbf78")
			_perfect.color = Color("#ffe67b")
	_title.text = "%s · 第 %d/%d 次" % [STEP_NAMES[current_step], current_round + 1, _required_rounds()]
	_hint.text = STEP_HINTS[current_step]
	_result.text = ""
	for marker in _segment_markers:
		marker.visible = current_step == Step.QUENCH
	_update_progress()
	_layout_target()
	_layout_cursor()

func _heat_tap() -> void:
	_cursor_value = minf(1.08, _cursor_value + HEAT_TAP_GAIN - float(current_round) * 0.008)
	_pulse_station_effect(Step.HEAT, 0.75 + _cursor_value * 0.45)
	_layout_cursor()
	var half_width := _current_width() * 0.5
	if absf(_cursor_value - _target_center) <= half_width or _cursor_value > _target_center + half_width:
		_judge()
	else:
		_result.text = "鼓风中……炉温 %d%%" % int(_cursor_value * 100.0)
		_result.add_theme_color_override("font_color", Color("#ffbd73"))

func _judge() -> void:
	_resolving = true
	_holding = false
	var audio := get_node_or_null("/root/AudioManager")
	var distance := absf(_cursor_value - _target_center)
	var half_width: float = _current_width() * 0.5
	if distance <= _perfect_half_width():
		_spawn_timing_impact(true, true)
		score += 100
		combo += 1
		best_combo = maxi(best_combo, combo)
		time_left = minf(TIME_LIMIT, time_left + PERFECT_TIME_BONUS)
		_show_result("完美！ +100  连击 x%d" % combo, Color("#fff0a6"))
		if audio != null: audio.call("play_event", "forge", 1.12, 0.0)
		_apply_success(true)
	elif distance <= half_width:
		_spawn_timing_impact(true, false)
		score += 65
		combo += 1
		best_combo = maxi(best_combo, combo)
		_show_result("成功！ +65  连击 x%d" % combo, Color("#9ff0bd"))
		if audio != null: audio.call("play_event", "forge", 0.96, -1.0)
		_apply_success(false)
	else:
		_spawn_timing_impact(false, false)
		combo = 0
		time_left = maxf(0.0, time_left - MISS_TIME_PENALTY)
		var penalty_seconds := int(MISS_TIME_PENALTY)
		var miss_text := "过热了！时间 -%d 秒" % penalty_seconds if current_step == Step.HEAT else ("水温不对！时间 -%d 秒" % penalty_seconds if current_step == Step.QUENCH else "偏了！时间 -%d 秒，稳住再来" % penalty_seconds)
		_show_result(miss_text, Color("#ff8585"))
		if audio != null: audio.call("play_event", "ui_error", 0.8, -1.0)
		_feedback_shake(3.0)
		get_tree().create_timer(0.72).timeout.connect(func() -> void:
			if is_instance_valid(self) and _active:
				_prepare_attempt())

func _apply_success(perfect_hit: bool) -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	_pulse_station_effect(current_step, 1.35 if perfect_hit else 1.0)
	match current_step:
		Step.HEAT:
			if _wall != null: _wall.call("mark_heat")
		Step.QUENCH:
			if _wall != null: _wall.call("mark_quench")
		Step.CHISEL:
			if _wall != null: _wall.call("crack")
			_feedback_shake(5.5 if perfect_hit else 4.0)
	current_round += 1
	if current_round < _required_rounds():
		get_tree().create_timer(0.62).timeout.connect(func() -> void:
			if is_instance_valid(self) and _active:
				_prepare_attempt())
		return
	current_round = 0
	_set_station_effect(current_step, false)
	current_step += 1
	if current_step > Step.CHISEL:
		_finish_forge()
		return
	_timing = false
	_holding = false
	_panel.visible = false
	if _player != null and _player.has_method("freeze"):
		_player.call("freeze", false)
	_show_notice("本工位完成！前往：%s" % STEP_NAMES[current_step])

func _finish_forge() -> void:
	_active = false
	_timing = false
	_disable_all_station_effects()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.call("record_insight", "labor", score)
	_result.text = "岩壁贯通！总分 %d · 最高连击 x%d" % [score, best_combo]
	_hint.text = "老匠人：水退下去了！行啊小伙子，这把锤子没白交给你。"
	if _wall != null and _wall.has_method("celebrate_breakthrough"):
		_wall.call("celebrate_breakthrough")
	var portal := get_tree().current_scene.find_child("dierguan_chukou", true, false)
	if portal != null and portal.has_method("activate"):
		portal.call("activate")
	_feedback_shake(7.0)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "explosion", 1.22, -5.0)
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if is_instance_valid(_panel):
			_panel.visible = false
		if is_instance_valid(_player) and _player.has_method("freeze"):
			_player.call("freeze", false)
		_show_notice("时空门已经开启，穿过它继续前行"))

func _fail_timeout() -> void:
	_active = false
	_timing = false
	_disable_all_station_effects()
	if _player != null and _player.has_method("freeze"):
		_player.call("freeze", false)
	_show_notice("一炷香燃尽了……")
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null: lm.call("fail", "一炷香燃尽了。")

func _show_result(text: String, color: Color) -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", color)
	_result.pivot_offset = _result.size * 0.5
	_result.scale = Vector2(0.82, 0.82)
	create_tween().tween_property(_result, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_progress()

func _spawn_timing_impact(success: bool, perfect_hit: bool) -> void:
	if _ui_layer == null or _cursor == null:
		return
	var impact_color := Color("#fff0a6") if perfect_hit else (Color("#8ff0b2") if success else Color("#ff7373"))
	var center := _cursor.get_global_rect().get_center()
	var sparks := CPUParticles2D.new()
	sparks.name = "TimingImpactParticles"
	sparks.position = center
	sparks.z_index = 120
	sparks.amount = 20 if perfect_hit else (13 if success else 8)
	sparks.lifetime = 0.42
	sparks.one_shot = true
	sparks.explosiveness = 0.98
	sparks.direction = Vector2(0, -1)
	sparks.spread = 150.0
	sparks.gravity = Vector2(0, 82)
	sparks.initial_velocity_min = 44.0 if success else 28.0
	sparks.initial_velocity_max = 112.0 if perfect_hit else 78.0
	sparks.scale_amount_min = 0.65
	sparks.scale_amount_max = 1.45
	sparks.color = impact_color
	sparks.texture = _make_impact_texture()
	_ui_layer.add_child(sparks)
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true

	var ring := Line2D.new()
	ring.name = "TimingImpactRing"
	ring.position = center
	ring.z_index = 119
	ring.width = 2.0 if success else 1.4
	ring.default_color = impact_color
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 9.0)
	ring.points = points
	ring.scale = Vector2(0.38, 0.38)
	_ui_layer.add_child(ring)
	var ring_tween := create_tween().set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.30)
	ring_tween.finished.connect(ring.queue_free)

	_cursor.pivot_offset = _cursor.size * 0.5
	_cursor.modulate = impact_color
	_cursor.scale = Vector2(2.1 if perfect_hit else 1.65, 1.0)
	var cursor_tween := create_tween().set_parallel(true)
	cursor_tween.tween_property(_cursor, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cursor_tween.tween_property(_cursor, "modulate", Color.WHITE, 0.20)
	_feedback_shake(1.7 if perfect_hit else (1.0 if success else 2.2))

func _make_impact_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 6
	texture.height = 6
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func _feedback_shake(strength: float) -> void:
	var camera := get_tree().current_scene.find_child("Camera2D", true, false)
	if camera != null and camera.has_method("shake"):
		camera.call("shake", strength, 0.22)

func _layout_target() -> void:
	var width: float = _current_width() * _bar.size.x
	_target.position.x = _target_center * _bar.size.x - width * 0.5
	_target.size.x = width
	var perfect_half := _perfect_half_width()
	_perfect.position.x = _target_center * _bar.size.x - perfect_half * _bar.size.x
	_perfect.size.x = perfect_half * 2.0 * _bar.size.x

func _layout_cursor() -> void:
	_cursor.position.x = _cursor_value * _bar.size.x - _cursor.size.x * 0.5

func _current_speed() -> float:
	return CURSOR_SPEEDS[current_step] * (1.0 + current_round * ROUND_SPEED_GROWTH)

func _current_width() -> float:
	return TARGET_WIDTHS[current_step] * (1.0 - current_round * ROUND_WIDTH_SHRINK)

func _perfect_half_width() -> float:
	return maxf(0.023, 0.035 - float(current_round) * 0.004)

func _quench_cooling_rate() -> float:
	# 四段水阻：蒸汽膜慢 → 沸腾骤快 → 水膜再次变慢 → 末段快速冷却。
	var rate := 0.28
	if _cursor_value > 0.78:
		rate = 0.28
	elif _cursor_value > 0.58:
		rate = 0.88
	elif _cursor_value > 0.36:
		rate = 0.38
	else:
		rate = 1.02
	return rate * (1.0 + float(current_round) * 0.16)

func _update_quench_resistance() -> void:
	var zone := 0 if _cursor_value > 0.78 else (1 if _cursor_value > 0.58 else (2 if _cursor_value > 0.36 else 3))
	if zone == _quench_zone:
		return
	_quench_zone = zone
	var labels := ["蒸汽膜：高阻，降温缓慢", "剧烈沸腾：低阻，温度骤降", "水膜形成：中阻，速度放缓", "冷却末段：阻力解除，迅速下坠"]
	_result.text = labels[zone]
	_result.add_theme_color_override("font_color", Color("#9feaff"))
	_pulse_station_effect(Step.QUENCH, 0.85 + float(zone) * 0.12)

func _set_station_effect(step: int, enabled: bool) -> void:
	var station: Node = _stations.get(step)
	if station != null and station.has_method("set_effect_active"):
		station.call("set_effect_active", enabled)

func _pulse_station_effect(step: int, strength: float) -> void:
	var station: Node = _stations.get(step)
	if station != null and station.has_method("pulse_effect"):
		station.call("pulse_effect", strength)

func _disable_all_station_effects() -> void:
	for station in _stations.values():
		if station != null and station.has_method("set_effect_active"):
			station.call("set_effect_active", false)

func _required_rounds() -> int:
	return int(ROUNDS_BY_STEP[current_step])

func _update_progress() -> void:
	var completed := current_round
	for step_index in range(current_step):
		completed += int(ROUNDS_BY_STEP[step_index])
	_progress.text = "进度 %d/%d　分数 %d　连击 x%d" % [completed, TOTAL_ACTIONS, score, combo]

func _refresh_timer() -> void:
	if _timer_label != null:
		_timer_label.text = "⏳ %d" % int(ceil(time_left))

func _show_notice(text: String) -> void:
	if _notice == null: return
	_notice.text = text
	_notice.visible = true
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if is_instance_valid(_notice): _notice.visible = false)

func _build_timing_ui() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		cur = get_parent()
	var ui := cur.find_child("UI_Base", true, false)
	if ui == null: return
	_ui_layer = ui as CanvasLayer
	_panel = Panel.new()
	_panel.name = "ForgeTimingPanel"
	_panel.position = Vector2(92, 210)
	_panel.size = Vector2(456, 138)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#17161ce8")
	box.border_color = Color("#d69752")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	ui.add_child(_panel)
	_title = _label(Vector2(18, 10), Vector2(220, 24), 16, Color("#ffd59a"))
	_hint = _label(Vector2(18, 34), Vector2(420, 20), 11, Color("#d9d2c5"))
	_bar = ColorRect.new()
	_bar.name = "TimingBar"
	_bar.color = Color("#353440")
	_bar.position = Vector2(22, 64)
	_bar.size = Vector2(412, 22)
	_panel.add_child(_bar)
	_target = ColorRect.new()
	_target.color = Color("#5cbf78")
	_target.size.y = 22
	_bar.add_child(_target)
	_perfect = ColorRect.new()
	_perfect.color = Color("#ffe67b")
	_perfect.size.y = 22
	_bar.add_child(_perfect)
	# 淬火条分成四个阻力区；竖线只在淬火阶段显示。
	for fraction in [0.25, 0.50, 0.75]:
		var marker := ColorRect.new()
		marker.name = "ResistanceMarker"
		marker.color = Color(0.78, 0.91, 1.0, 0.42)
		marker.position = Vector2(float(fraction) * _bar.size.x - 1.0, 0)
		marker.size = Vector2(2, 22)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.visible = false
		_bar.add_child(marker)
		_segment_markers.append(marker)
	_cursor = ColorRect.new()
	_cursor.color = Color("#fffaf0")
	_cursor.position.y = -5
	_cursor.size = Vector2(4, 32)
	_bar.add_child(_cursor)
	_result = _label(Vector2(22, 92), Vector2(270, 22), 13, Color.WHITE)
	_progress = _label(Vector2(285, 94), Vector2(150, 20), 11, Color("#b8ac9c"))
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.visible = false

func _label(pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_panel.add_child(label)
	return label
