extends Node2D

## 第六章：未来重庆 · 记忆失真
## 将前五关的追逐、节奏校准、护送和观察选择重新组合成一条完整流程。

enum Stage { INTRO, CHASE, CALIBRATION, ESCORT, FINALE, COMPLETE }

const WORLD_RIGHT := 3260.0
const ROAD_BODY_Y := 282.0
const ROAD_FOOT_Y := 288.0
const SHUTTLE_LEFT := -180.0
const SHUTTLE_RIGHT := 820.0
const SHUTTLE_SPEED := 72.0
const SHUTTLE_ALTITUDE := 72.0
const SYNC_WIDTHS: Array[float] = [0.12, 0.105, 0.09, 0.08]
const SYNC_CENTERS: Array[float] = [0.50, 0.72, 0.30, 0.64]
const SCAN_LOCK_SECONDS: float = 0.75
const HISTORY_DRAIN: float = 14.0
const REALITY_RECHARGE: float = 16.0
const INTRO_LINES := [
	"有人想让路更宽、日子更方便。也有人问：\n‘老街改了，那些人的故事放哪儿？’",
	"争论还没结束，旧记忆已被列入待清理档案。\n窑火、江岸和引路灯，正变成蓝色乱码。",
	"渝灯：‘先把记忆找回来，好吗？\n别让大家还没看见，就把它们忘了。’",
	"陈默：‘先把人和故事找齐。怎么留下它们，\n看过以后再决定。’",
]
const INTRO_COMIC_ART := "res://assets/production/future/intro-comic-v1/atlas.png"

@onready var shuttle := $FutureLayers/SkyShuttle as Sprite2D
@onready var background_layers := $FutureLayers as Node2D
@onready var player := $zhujue as CharacterBody2D
@onready var camera := $zhujue/zhujue_shexiangji as Camera2D
@onready var ui := $UI_Base as CanvasLayer

var stage := Stage.INTRO
var history_mode := false
var memory_shards := 0
var _intro_index := 0
var _intro_comic: Control
var _time := 0.0
var _message_timer := 0.0
var _scanner_timer := 0.0
var _scanner_zones := [1720.0, 2070.0, 2290.0]
var _scanner_visuals: Array[Polygon2D] = []
var _civilians: Array[Node2D] = []
var _recruited: Array[Node2D] = []
var _history_echo_layer: Node2D
var _drone: Sprite2D
var _terminal: Area2D
var _power_gates: Array[Area2D] = []
var _history_energy := 100.0
var _checkpoint_x := 88.0
var _ending_choice := ""
var _ending_shown_at := 0
var _visited_gates: Dictionary = {}
var _pending_gate := ""
var _gate_observed_at := 0
var _mouse_hold := false
var _return_button: Button
var _city_particles: CPUParticles2D

var _objective: Label
var _mode_badge: Label
var _shard_label: Label
var _story_panel: PanelContainer
var _story_label: Label
var _mode_tint: ColorRect
var _memory_screen: CanvasLayer
var _calibration_panel: PanelContainer
var _calibration_title: Label
var _calibration_hint: Label
var _calibration_fill: ColorRect
var _calibration_target: ColorRect
var _calibration_marker: ColorRect
var _calibration_mode := 0
var _calibration_value := 0.0
var _timing_direction := 1.0
var _timing_hits := 0
var _memory_circuit: PanelContainer
var _escort_waiting: bool = false
var _ending_panel: PanelContainer
var _ending_label: Label
var _ending_art_layer: CanvasLayer
var _ending_art: TextureRect

func _ready() -> void:
	camera.limit_left = 0
	camera.limit_right = int(WORLD_RIGHT)
	camera.limit_top = 0
	camera.limit_bottom = 360
	camera.offset = Vector2.ZERO
	camera.limit_smoothed = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	shuttle.position = Vector2(-110, SHUTTLE_ALTITUDE)
	shuttle.scale = Vector2.ONE * (220.0 / float(shuttle.texture.get_width()))
	_prepare_background_parallax()
	RenderingServer.frame_pre_draw.connect(_align_background_for_draw)
	_build_world()
	_build_ui()
	_memory_screen = CanvasLayer.new()
	_memory_screen.name = "MemoryScreenEffect"
	_memory_screen.set_script(preload("res://scripts/levels/memory_screen_effect.gd"))
	add_child(_memory_screen)
	_start_future_ambience()
	player.frozen = true
	_show_intro_line()
	_update_hud()

func _process(delta: float) -> void:
	_time += delta
	_update_fixed_background(delta)
	var arrival := get_node_or_null("/root/ChapterArrival")
	var showing_arrival := arrival != null and bool(arrival.call("is_presenting"))
	if _message_timer > 0.0 and stage not in [Stage.INTRO, Stage.COMPLETE] and not showing_arrival:
		_message_timer -= delta
		if _message_timer <= 0.0 and _story_panel != null:
			_story_panel.visible = false
	_update_world_safety()
	if stage == Stage.COMPLETE:
		_update_ending_city(delta)
	elif stage == Stage.CHASE and memory_shards == 0 and is_instance_valid(_drone):
		_shard_label.text = "接回记忆  %.0fs · R 重试" % float(_drone.get("remaining"))
	if stage == Stage.CALIBRATION:
		_update_calibration(delta)
	elif stage == Stage.ESCORT:
		_update_history_energy(delta)
		_update_scanners(delta)
		if _escort_arrived():
			stage = Stage.FINALE
			_scanner_timer = 0.0
			_history_energy = 100.0
			_checkpoint_x = 2460.0
			_set_objective("辨认真实的洪崖洞记忆，再决定这座城如何保存过去")
			_show_message("队尾也到了。阿明把包袱放下：‘现在人齐了。前面两个节点，你都看看——别只挑灯最亮的那个。’", 6.0)
		_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_hold = event.pressed
	# 模态阶段在 GUI 之前接收输入，面板内部点击和外部点击均可推进。
	if stage not in [Stage.INTRO, Stage.CALIBRATION]:
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		advance = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not advance:
		return
	if stage == Stage.CALIBRATION and _calibration_mode == 1:
		return # Circuit buttons own mouse/Enter; do not swallow their GUI events.
	if stage == Stage.INTRO:
		if is_instance_valid(_intro_comic):
			_intro_comic.call("_request_advance")
			if bool(_intro_comic.get("complete_requested")):
				_start_chase()
	elif _calibration_mode == 0:
		_calibration_value = minf(1.0, _calibration_value + 0.09)
		_pulse_calibration_bar()
	elif _calibration_mode == 2:
		_attempt_timing_hit()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_C or event.keycode == KEY_C) and stage == Stage.ESCORT:
		toggle_escort_waiting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and stage == Stage.CHASE and memory_shards == 0:
		restart_chase()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		if stage not in [Stage.INTRO, Stage.CALIBRATION, Stage.COMPLETE]:
			set_history_mode(not history_mode)
			get_viewport().set_input_as_handled()
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("jump")
	if event is InputEventMouseButton:
		advance = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not advance:
		return
	if stage == Stage.COMPLETE and _ending_choice != "" and Time.get_ticks_msec() - _ending_shown_at > 900:
		_return_to_title()
		get_viewport().set_input_as_handled()

func _update_fixed_background(delta: float) -> void:
	_align_background_for_draw()
	# 这套景片是同一构图的对齐图层，左右并非无缝素材。
	# 保持楼体/桥梁原有对齐，不能独立循环后硬拼接。
	for layer_name in ["Far", "Mid"]:
		(background_layers.get_node(layer_name) as Sprite2D).position.x = 0.0
	var previous_shuttle_x := shuttle.position.x
	var speed := SHUTTLE_SPEED * (1.6 if _ending_choice == "overwrite" else 1.0)
	shuttle.position.x += speed * delta
	shuttle.position.y = SHUTTLE_ALTITUDE + sin(_time * 0.85) * 4.0
	# 中心点越过边缘和整艘飞船后才回收，避免可见区域内瞬移。
	if shuttle.position.x > SHUTTLE_RIGHT:
		shuttle.position.x = SHUTTLE_LEFT
	if previous_shuttle_x < -80.0 and shuttle.position.x >= -80.0:
		var audio := get_node_or_null("FutureShuttleAudio") as AudioStreamPlayer
		if audio != null:
			audio.play()

func _align_background_for_draw() -> void:
	# 镜头平滑在场景处理后更新；用绘制前最终画布变换，避免瞬间露出灰边。
	if not is_inside_tree() or not is_instance_valid(background_layers):
		return
	var viewport := get_viewport()
	if viewport != null:
		background_layers.global_position = viewport.get_canvas_transform().affine_inverse() * Vector2.ZERO

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_align_background_for_draw):
		RenderingServer.frame_pre_draw.disconnect(_align_background_for_draw)

func _build_world() -> void:
	_build_ground_tiles()
	_build_chase_obstacles()
	_build_history_echoes()
	_build_drone()
	_build_terminal()
	_build_civilians()
	_build_scanners()
	_build_power_gates()
	_build_route_landmarks()
	_build_city_particles()
	_build_edge_walls()
	_build_final_gates()

func _build_ground_tiles() -> void:
	var texture := load("res://assets/production/backgrounds/06_future/ground.png") as Texture2D
	if texture == null:
		return
	# 实体路面必须留在世界坐标，不能跟随背景镜头横移或跳跃。
	# 相邻段镜像衔接，同一边缘像素相接，避免非无缝素材的硬切。
	var road := Node2D.new()
	road.name = "RoadSurface"
	road.z_index = 8
	add_child(road)
	var width := texture.get_width() * 0.5
	for i in range(-1, 6):
		var tile := Sprite2D.new()
		tile.name = "RoadTile%d" % i
		tile.texture = texture
		tile.centered = false
		tile.position.x = float(i) * width
		tile.scale = Vector2(0.5, 0.5)
		tile.flip_h = posmod(i, 2) == 1
		road.add_child(tile)

func _build_chase_obstacles() -> void:
	var data := [
		{"x": 420.0, "w": 42.0, "h": 30.0},
		{"x": 565.0, "w": 54.0, "h": 42.0},
		{"x": 710.0, "w": 38.0, "h": 54.0},
	]
	for item: Dictionary in data:
		var body := StaticBody2D.new()
		body.name = "MaintenanceBarrier%d" % int(item["x"])
		body.position = Vector2(float(item["x"]), ROAD_BODY_Y - float(item["h"]) * 0.5)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(float(item["w"]), float(item["h"]))
		shape.shape = rect
		body.add_child(shape)
		var hw := float(item["w"]) * 0.5
		var hh := float(item["h"]) * 0.5
		var shadow := Polygon2D.new()
		shadow.name = "ContactShadow"
		shadow.polygon = PackedVector2Array([Vector2(-hw - 8, hh + 3), Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw + 8, hh + 3), Vector2(hw, hh + 8), Vector2(-hw, hh + 8)])
		shadow.color = Color(0.01, 0.02, 0.03, 0.65)
		shadow.z_index = 10
		body.add_child(shadow)
		var base := Polygon2D.new()
		base.name = "AnchoredBase"
		base.polygon = PackedVector2Array([Vector2(-hw - 3, hh - 2), Vector2(hw + 3, hh - 2), Vector2(hw + 3, hh + 6), Vector2(-hw - 3, hh + 6)])
		base.color = Color("#304554")
		base.z_index = 14
		body.add_child(base)
		var visual := Sprite2D.new()
		visual.name = "GeneratedBarrier"
		visual.texture = load("res://assets/production/future/maintenance-barrier-v5.png")
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.scale = Vector2((float(item["w"]) + 6.0) / 192.0, (float(item["h"]) + 6.0) / 96.0)
		visual.position.y = 3.0
		visual.z_index = 12
		body.add_child(visual)
		add_child(body)

func _build_history_echoes() -> void:
	_history_echo_layer = Node2D.new()
	_history_echo_layer.name = "HistoryEchoes"
	_history_echo_layer.z_index = 14
	add_child(_history_echo_layer)
	# 只提取有地面锚点的历史建筑，代替悬在半空的旧关卡截图。
	var paths := [
		"res://assets/production/props/memory_landmarks/old-gate-v1.png",
		"res://assets/production/props/forge_stations/heat-workstation-v1.png",
		"res://assets/production/props/memory_landmarks/old-gate-v1.png",
		"res://assets/production/props/gameplay/blast-shield-ai-v2.png",
		"res://assets/production/props/memory_landmarks/city-lights-railing-v1.png",
	]
	var xs := [520.0, 1120.0, 1620.0, 2120.0, 2800.0]
	for i in range(paths.size()):
		var sprite := Sprite2D.new()
		if not ResourceLoader.exists(paths[i]):
			continue
		sprite.texture = load(paths[i])
		sprite.position = Vector2(xs[i], 282)
		if sprite.texture != null:
			var size := sprite.texture.get_size()
			var bounds := sprite.texture.get_image().get_used_rect()
			var s := minf(300.0 / float(maxi(bounds.size.x, 1)), 170.0 / float(maxi(bounds.size.y, 1)))
			sprite.scale = Vector2.ONE * s
			sprite.position.y = 288.0 - (float(bounds.end.y) - size.y * 0.5) * s
		sprite.name = "SolidHistoryLandmark%d" % (i + 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color.WHITE
		# 同时处理素材自带alpha；只调节点alpha不能保证原图实体不透景。
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/solid_memory.gdshader")
		sprite.material = material
		_history_echo_layer.add_child(sprite)
	_history_echo_layer.visible = false

func _build_drone() -> void:
	_drone = Sprite2D.new()
	_drone.name = "MemoryDrone"
	_drone.texture = load("res://assets/production/future/memory-drone-v1.png")
	_drone.position = Vector2(310, 193)
	_drone.z_index = 18
	_drone.set_script(load("res://scripts/levels/future_memory_drone.gd"))
	add_child(_drone)

func _build_terminal() -> void:
	_terminal = Area2D.new()
	_terminal.name = "MemoryTerminal"
	_terminal.position = Vector2(1110, 282)
	_terminal.set_script(load("res://scripts/levels/future_memory_terminal.gd"))
	_terminal.set("terminal_index", 1)
	add_child(_terminal)

func _build_civilians() -> void:
	var positions := [Vector2(1510, 282), Vector2(1860, 282), Vector2(2210, 282)]
	for i in range(positions.size()):
		var civilian := Node2D.new()
		civilian.name = "MemoryCivilian%d" % (i + 1)
		civilian.position = positions[i]
		civilian.set_script(load("res://scripts/levels/future_memory_civilian.gd"))
		civilian.call("setup", i, player)
		civilian.set_meta("origin", positions[i])
		add_child(civilian)
		_civilians.append(civilian)

func _build_scanners() -> void:
	for x: float in _scanner_zones:
		var beam := Polygon2D.new()
		beam.position = Vector2(x, 0)
		beam.polygon = PackedVector2Array([Vector2(-58, 72), Vector2(58, 72), Vector2(86, 282), Vector2(-86, 282)])
		beam.color = Color(1.0, 0.18, 0.22, 0.12)
		beam.z_index = 6
		add_child(beam)
		_scanner_visuals.append(beam)

func _build_final_gates() -> void:
	var gate_script := load("res://scripts/levels/future_choice_gate.gd")
	var fake := Area2D.new()
	fake.name = "PerfectReplica"
	fake.position = Vector2(2740, 282)
	fake.set_script(gate_script)
	fake.set("choice_id", "fake")
	fake.set("title", "城市记忆 · 节点 A")
	fake.set("texture_path", "res://assets/production/backgrounds/01/layered-preview.png")
	add_child(fake)
	var real := Area2D.new()
	real.name = "LivingMemory"
	real.position = Vector2(3010, 282)
	real.set_script(gate_script)
	real.set("choice_id", "real")
	real.set("title", "城市记忆 · 节点 B")
	real.set("texture_path", "res://assets/production/backgrounds/05/layered-preview.png")
	add_child(real)

func _build_ui() -> void:
	_objective = Label.new()
	_objective.position = Vector2(18, 48)
	_objective.size = Vector2(300, 42)
	_objective.add_theme_font_size_override("font_size", 11)
	_objective.add_theme_color_override("font_color", Color("#d7f8ff"))
	_objective.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.95))
	_objective.add_theme_constant_override("outline_size", 4)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(_objective)
	_mode_badge = Label.new()
	_mode_badge.position = Vector2(18, 94)
	_mode_badge.size = Vector2(182, 26)
	_mode_badge.add_theme_font_size_override("font_size", 11)
	_mode_badge.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.95))
	_mode_badge.add_theme_constant_override("outline_size", 4)
	ui.add_child(_mode_badge)
	_shard_label = Label.new()
	_shard_label.position = Vector2(18, 120)
	_shard_label.size = Vector2(180, 24)
	_shard_label.add_theme_font_size_override("font_size", 11)
	_shard_label.add_theme_color_override("font_color", Color("#ffd176"))
	_shard_label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.95))
	_shard_label.add_theme_constant_override("outline_size", 4)
	ui.add_child(_shard_label)
	_mode_tint = ColorRect.new()
	_mode_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_tint.color = Color(0.12, 0.36, 0.42, 0.0)
	_mode_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_mode_tint)
	ui.move_child(_mode_tint, 0)
	_build_story_panel()
	_build_calibration_panel()
	_build_ending_panel()

func _build_story_panel() -> void:
	_story_panel = PanelContainer.new()
	_story_panel.position = Vector2(70, 255)
	_story_panel.size = Vector2(500, 86)
	_story_panel.add_theme_stylebox_override("panel", _panel_style(Color("#d7a84f")))
	_story_label = Label.new()
	_story_label.custom_minimum_size = Vector2(468, 64)
	_story_label.add_theme_font_size_override("font_size", 12)
	_story_label.add_theme_color_override("font_color", Color("#f5f1e9"))
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_panel.add_child(_story_label)
	ui.add_child(_story_panel)

func _build_calibration_panel() -> void:
	_calibration_panel = PanelContainer.new()
	_calibration_panel.position = Vector2(80, 168)
	_calibration_panel.size = Vector2(480, 154)
	_calibration_panel.add_theme_stylebox_override("panel", _panel_style(Color("#54dcef")))
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	_calibration_panel.add_child(root_box)
	_calibration_title = Label.new()
	_calibration_title.add_theme_font_size_override("font_size", 14)
	_calibration_title.add_theme_color_override("font_color", Color("#e8fbff"))
	root_box.add_child(_calibration_title)
	_calibration_hint = Label.new()
	_calibration_hint.add_theme_font_size_override("font_size", 10)
	_calibration_hint.add_theme_color_override("font_color", Color("#a9cbd4"))
	root_box.add_child(_calibration_hint)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(440, 30)
	root_box.add_child(bar)
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(8, 7)
	bar_bg.size = Vector2(424, 16)
	bar_bg.color = Color("#263442")
	bar.add_child(bar_bg)
	_calibration_target = ColorRect.new()
	_calibration_target.position = Vector2(310, 7)
	_calibration_target.size = Vector2(64, 16)
	_calibration_target.color = Color(0.94, 0.78, 0.34, 0.72)
	bar.add_child(_calibration_target)
	_calibration_fill = ColorRect.new()
	_calibration_fill.position = Vector2(8, 7)
	_calibration_fill.size = Vector2(0, 16)
	_calibration_fill.color = Color("#48ddeb")
	bar.add_child(_calibration_fill)
	_calibration_marker = ColorRect.new()
	_calibration_marker.position = Vector2(8, 3)
	_calibration_marker.size = Vector2(4, 24)
	_calibration_marker.color = Color.WHITE
	bar.add_child(_calibration_marker)
	_calibration_panel.visible = false
	ui.add_child(_calibration_panel)

func _build_ending_panel() -> void:
	_ending_panel = PanelContainer.new()
	_ending_panel.position = Vector2(100, 78)
	_ending_panel.size = Vector2(440, 240)
	_ending_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f0bd5c")))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_ending_panel.add_child(box)
	_ending_label = Label.new()
	_ending_label.text = "城市记忆已经恢复。该怎样让它留在未来？"
	_ending_label.add_theme_font_size_override("font_size", 13)
	_ending_label.add_theme_color_override("font_color", Color("#f6efe2"))
	_ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_label.custom_minimum_size = Vector2(408, 54)
	box.add_child(_ending_label)
	var choices := [
		["封存历史 · 完整保存进档案", "archive"],
		["覆盖历史 · 让效率决定城市", "overwrite"],
		["让历史继续生活 · 接入公共空间", "living"],
	]
	for item: Array in choices:
		var button := Button.new()
		button.text = str(item[0])
		button.custom_minimum_size = Vector2(408, 38)
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_finish_future.bind(str(item[1])))
		box.add_child(button)
	_ending_panel.visible = false
	ui.add_child(_ending_panel)

func _panel_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.065, 0.95)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 5
	return style

func _show_intro_line() -> void:
	_story_panel.hide()
	_intro_comic = preload("res://scripts/ui/story_comic.gd").new()
	_intro_comic.name = "FutureIntroComic"
	ui.add_child(_intro_comic)
	var beats: Array = []
	var titles: Array[String] = ["01 · 城市该往哪走", "02 · 记忆正在失真", "03 · 先找回来，再作选择", "04 · 从一枚灯芯开始"]
	for i in range(4):
		beats.append({
			"art": INTRO_COMIC_ART,
			"crop": Rect2(float(i % 2) * 0.5, float(i / 2) * 0.5, 0.5, 0.5),
			"title": titles[i], "body": INTRO_LINES[i],
		})
	_intro_comic.call("configure", "第六章 · 未来重庆：谁来记得", beats, "点击 / E / SPACE　出发寻回记忆")
	# 第一格自动展开；其余逐格阅读，最后一次确认才开始追逐。
	_intro_comic.set("_guard_until", 0)
	_intro_comic.call("_request_advance")

func _start_chase() -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	if is_instance_valid(_intro_comic):
		_intro_comic.queue_free()
		_intro_comic = null
	stage = Stage.CHASE
	_story_panel.visible = false
	player.frozen = false
	_set_objective("18秒内越过三处维护障碍 · 跳起接灯芯 · R 重试")
	if _drone != null and _drone.has_method("begin"):
		_drone.call("begin", player)
	_show_message("渝灯：‘无人机在运走待清理档案。跳起接回灯芯，找齐记忆后，再作选择。’", 5.0)

func on_drone_caught(at_position: Vector2) -> void:
	if stage != Stage.CHASE or memory_shards > 0:
		return
	memory_shards = 1
	_checkpoint_x = 850.0
	_spawn_memory_burst(at_position)
	_set_objective("前往城市记忆终端，完成三段校准")
	_show_message("第一枚碎片回到灯芯。里面没有宏大的事件，只有夜里赶路的人、摊贩收摊的声音，以及一条被反复走过的小路。", 5.0)
	_update_hud()

func begin_terminal_calibration(terminal: Area2D) -> void:
	if stage != Stage.CHASE or memory_shards < 1:
		_show_message("终端没有响应。先找回被巡逻机带走的记忆碎片。", 3.0)
		return
	_terminal = terminal
	stage = Stage.CALIBRATION
	player.frozen = true
	_calibration_mode = 0
	_calibration_value = 0.0
	_timing_hits = 0
	_calibration_panel.visible = true
	_story_panel.visible = false
	_message_timer = 0.0
	_mouse_hold = false
	_set_calibration_copy()

func _update_calibration(delta: float) -> void:
	if _calibration_mode == 0:
		_calibration_value = maxf(0.0, _calibration_value - delta * 0.23)
		_calibration_fill.size.x = 424.0 * _calibration_value
		_calibration_marker.visible = false
		_calibration_target.visible = true
		if _calibration_value >= 0.78:
			_next_calibration_mode()
	elif _calibration_mode == 1:
		return # Circuit verification, not holding, advances this phase.
	else:
		_calibration_value += delta * (0.95 + 0.10 * _timing_hits) * _timing_direction
		if _calibration_value >= 1.0:
			_calibration_value = 1.0
			_timing_direction = -1.0
		elif _calibration_value <= 0.0:
			_calibration_value = 0.0
			_timing_direction = 1.0
		_calibration_fill.size.x = 0
		_calibration_marker.visible = true
		_calibration_target.visible = true
		_calibration_marker.position.x = 8.0 + 424.0 * _calibration_value

func _next_calibration_mode() -> void:
	_calibration_mode += 1
	_calibration_value = 0.0
	_timing_direction = 1.0
	_set_calibration_copy()
	if _calibration_mode == 1:
		_calibration_panel.hide()
		_memory_circuit = preload("res://scripts/ui/memory_circuit.gd").new()
		ui.add_child(_memory_circuit)
		_memory_circuit.reconstructed.connect(_on_memory_reconstructed)
		_set_objective("重构档案线路 · 旋转九宫格，连接左右端口")

func _on_memory_reconstructed() -> void:
	if stage != Stage.CALIBRATION or _calibration_mode != 1: return
	_memory_circuit.queue_free()
	_memory_circuit = null
	_next_calibration_mode()
	_calibration_panel.show()
	_set_objective("记忆已接通 · 完成四次广播同步")

func _set_calibration_copy() -> void:
	match _calibration_mode:
		0:
			_calibration_title.text = "接通一 · 公共记忆供电"
			_calibration_hint.text = "连按 E / 点击鼓动电容，接回窑场工人的记忆"
			_calibration_target.position.x = 8.0 + 424.0 * 0.78
			_calibration_target.size.x = 424.0 * 0.18
		1:
			_calibration_title.text = "接通二 · 记忆线路重构"
			_calibration_hint.text = "旋转线路连接左右端口，再验证档案信号"
		2:
			_calibration_title.text = "接通三 · 同步公共广播"
			_layout_sync_target()
			_calibration_hint.text = "金色区按 E / 点击 · 0/4 · 后续判定逐渐收窄"

func _layout_sync_target() -> void:
	var width: float = SYNC_WIDTHS[_timing_hits]
	_calibration_target.position.x = 8.0 + 424.0 * (SYNC_CENTERS[_timing_hits] - width * 0.5)
	_calibration_target.size.x = 424.0 * width

func _attempt_timing_hit() -> void:
	var center := (_calibration_target.position.x - 8.0 + _calibration_target.size.x * 0.5) / 424.0
	var half := _calibration_target.size.x * 0.5 / 424.0
	if absf(_calibration_value - center) <= half:
		_timing_hits += 1
		_pulse_calibration_bar()
		if _timing_hits >= SYNC_WIDTHS.size():
			_complete_calibration()
			return
		_layout_sync_target()
		_calibration_hint.text = "金色区按 E / 点击 · %d/4 · 正在提速" % _timing_hits
	else:
		_timing_hits = maxi(0, _timing_hits - 1)
		_layout_sync_target()
		_calibration_hint.text = "错位扣一次命中，重新稳住节奏 · %d/4" % _timing_hits

func _complete_calibration() -> void:
	stage = Stage.ESCORT
	_checkpoint_x = 1420.0
	_history_energy = 100.0
	memory_shards = 2
	player.frozen = false
	_calibration_panel.visible = false
	if _terminal != null and _terminal.has_method("mark_completed"):
		_terminal.call("mark_completed")
	set_history_mode(true)
	_set_objective("Q 切层找人避扫描 · 现实 E 开门 · C 队伍等候／跟随")
	_show_message("渝灯：‘供电接回去了。开灯找人、绕扫描；过供能门要先关灯按 E。灯芯用完之前，记得回现实歇一会儿。’", 7.0)
	_update_hud()

func can_recruit_civilian() -> bool:
	return stage == Stage.ESCORT and history_mode

func recruit_civilian(civilian: Node2D) -> void:
	if not _recruited.has(civilian):
		_recruited.append(civilian)
		civilian.set("waiting", _escort_waiting)
		memory_shards = mini(5, 2 + _recruited.size())
		_spawn_memory_burst(civilian.global_position + Vector2(0, -45))
		var index := int(civilian.get("follower_index"))
		var lines := [
			"阿明：‘你认得我？窑场那回，多亏有人肯留下。现在轮到我给你搭把手。’",
			"老周：‘货包我还记得，人怎么倒成了无用数据？那条到码头的路，可别删了。’",
			"周叔：‘那年有人举灯带我出洞。楼修得再高，走慢的人也得有路啊。’",
		]
		_show_message("%s\n队伍 %d/3 · 走到集合点后等队尾" % [lines[index], _recruited.size()], 6.0)
		_update_hud()

func set_history_mode(value: bool) -> void:
	if value and stage == Stage.ESCORT and _history_energy < 8.0:
		_show_message("渝灯：‘灯芯还没缓过来，在现实里歇一会儿。’", 2.5)
		return
	history_mode = value
	if is_instance_valid(_memory_screen):
		_memory_screen.call("set_active", history_mode)
	# 历史建筑保留实色，压暗未来远景以建立前后景对比，不盖暗人物和UI。
	for layer_name in ["Sky", "Far", "Mid", "SkyShuttle"]:
		(background_layers.get_node(layer_name) as CanvasItem).modulate = Color(0.48, 0.57, 0.66) if history_mode else Color.WHITE
	if _history_echo_layer != null:
		_history_echo_layer.visible = history_mode
	if _mode_tint != null:
		_mode_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	for beam in _scanner_visuals:
		beam.color = Color(0.25, 0.9, 1.0, 0.06) if history_mode else Color(1.0, 0.18, 0.22, 0.12)
	_update_hud()

func _update_scanners(delta: float) -> void:
	var in_scanner := false
	for actor in [player] + _recruited:
		for x: float in _scanner_zones:
			if absf(actor.global_position.x - x) < 72.0:
				in_scanner = true
				break
	if in_scanner and not history_mode and not _recruited.is_empty():
		_scanner_timer += delta
		_mode_badge.text = "⚠ 扫描锁定 %.1f" % maxf(0.0, SCAN_LOCK_SECONDS - _scanner_timer)
		_mode_badge.add_theme_color_override("font_color", Color("#ff756f"))
		if _scanner_timer >= SCAN_LOCK_SECONDS:
			_reset_escort()
	else:
		_scanner_timer = maxf(0.0, _scanner_timer - delta * 2.0)
		_update_hud()

func _reset_escort() -> void:
	_escort_waiting = false
	_scanner_timer = 0.0
	_recruited.clear()
	memory_shards = 2
	for civilian in _civilians:
		if civilian.has_method("reset_memory"):
			civilian.call("reset_memory")
	player.global_position = Vector2(1420, 282)
	player.velocity = Vector2.ZERO
	_history_energy = 100.0
	set_history_mode(true)
	_show_message("扫描抹去了刚刚恢复的连接。渝灯把陈默拉回残影层：‘带着人过扫描区时，莫急着关灯。’", 4.0)

func toggle_escort_waiting() -> void:
	if stage != Stage.ESCORT or _recruited.is_empty(): return
	_escort_waiting = not _escort_waiting
	for civilian in _recruited: civilian.set("waiting", _escort_waiting)
	_update_hud()
	_show_message("队伍原地等候。你可以先侦察安全补能点；C 继续跟随。注意留在扫描区的人仍会被锁定！" if _escort_waiting else "队伍继续跟随。先等队尾靠近，再带大家一起通过。", 4.0)

func choose_memory_gate(choice_id: String) -> void:
	if stage != Stage.FINALE:
		_show_message("记忆还没有收集完整，这两座洪崖洞都无法验证。", 3.0)
		return
	if _visited_gates.size() == 2 and _pending_gate == choice_id and Time.get_ticks_msec() - _gate_observed_at >= 350:
		_confirm_memory_gate(choice_id)
		return
	_visited_gates[choice_id] = true
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	_pending_gate = choice_id
	_gate_observed_at = Time.get_ticks_msec()
	var clue := "节点 A：招牌每次都在同一秒闪亮，广播重复同一句欢迎。石阶很新，听不到脚步，也没有摊贩的应答。" if choice_id == "fake" else "节点 B：石阶中间磨低了，巷口有人问今天的工钱，远处传来木桶碰撞声。老周说：‘这声音，我认得。’"
	var hint := "再去看另一个节点，比较生活痕迹。" if _visited_gates.size() < 2 else "两边都已观察。再按 E，选择把当前节点交给渝灯。"
	_show_message(clue + "\n" + hint, 9.0)

func _confirm_memory_gate(choice_id: String) -> void:
	if choice_id == "fake":
		_show_message("陈默：‘它像洪崖洞，却没记住在这里生活的人。’\n渝灯：‘再听听另一边，不急着选。’", 6.0)
		_pending_gate = ""
		return
	player.frozen = true
	stage = Stage.COMPLETE
	_message_timer = 0.0
	_ending_panel.visible = true
	_story_panel.visible = false
	var buttons := _ending_panel.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()

func _finish_future(choice: String) -> void:
	if stage != Stage.COMPLETE or _ending_choice != "":
		return
	_ending_choice = choice
	_ending_shown_at = Time.get_ticks_msec()
	_message_timer = 0.0
	set_history_mode(choice != "overwrite")
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("record_insight", "future_ending", choice)
	_ending_panel.visible = false
	_story_panel.position = Vector2(70, 180)
	_story_panel.size = Vector2(500, 164)
	_story_label.custom_minimum_size = Vector2(468, 140)
	_story_label.add_theme_font_size_override("font_size", 11)
	_story_panel.visible = true
	_start_ending_city(choice)
	match choice:
		"archive":
			_story_label.text = "档案柜一格格亮起，旧时的人和路被完整保留下来。街上的广播恢复了安静。\n阿明站在柜门里：‘有人来问的时候，记得打开给他看。’\n\nE / ENTER 返回标题"
		"overwrite":
			_story_label.text = "飞船加速掠过上空，旧墙的光慢慢熄灭。道路更整齐，却没人再喊出那三个人的名字。\n陈默望着空下来的巷口，把没说完的话留在了风里。\n\nE / ENTER 返回标题"
		_:
			_story_label.text = "车窗依次映出窑火、码头和防空洞。阿明往铺子走，老周问起下一班船，周叔慢慢沿石阶回家。\n渝灯：‘有人接着走，这段路就还在。’\n陈默放下手机，先把他们的话听完。\n\nE / ENTER 返回标题"
	_show_ending_illustration(choice)
	_return_button = Button.new()
	_return_button.text = "返回主界面"
	_return_button.position = Vector2(248, 316)
	_return_button.size = Vector2(144, 32)
	_return_button.pressed.connect(_return_to_title)
	_ending_art_layer.add_child(_return_button)
	_return_button.grab_focus()

func _show_ending_illustration(choice: String) -> void:
	# Ending art is outside the blue memory postprocess and never tinted like gameplay.
	_ending_art_layer = CanvasLayer.new()
	_ending_art_layer.name = "EndingIllustrationLayer"
	_ending_art_layer.layer = 30
	add_child(_ending_art_layer)
	_ending_art = TextureRect.new()
	_ending_art.name = "EndingArt"
	_ending_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ending_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ending_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ending_art.texture = load("res://assets/production/future/endings-v1/%s.png" % choice)
	_ending_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_art_layer.add_child(_ending_art)
	var header := Label.new()
	header.name = "EndingTitle"
	header.text = {"archive": "结局 · 留在档案里的光", "overwrite": "结局 · 没有回声的新城", "living": "结局 · 让这条路继续"}.get(choice, "未来重庆")
	header.position = Vector2(18, 12)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color("#ffe0a0"))
	header.add_theme_color_override("font_outline_color", Color("#07101f"))
	header.add_theme_constant_override("outline_size", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_art_layer.add_child(header)
	_story_panel.reparent(_ending_art_layer)
	_story_panel.position = Vector2(14, 228)
	_story_label.custom_minimum_size = Vector2(580, 68)
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_story_panel.size = Vector2(612, 122)
	_story_label.text = _story_label.text.replace("\n\nE / ENTER 返回标题", "")
	_story_label.text = _story_label.text.replace("。阿明", "。\n阿明").replace("。道路", "。\n道路")
	_story_label.add_theme_font_size_override("font_size", 11)
	_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_art.modulate.a = 0.0
	create_tween().tween_property(_ending_art, "modulate:a", 1.0, 0.5)

func _return_after_ending(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_return_to_title()

func _return_to_title() -> void:
	if stage == Stage.COMPLETE and _ending_choice != "" and Time.get_ticks_msec() - _ending_shown_at < 900:
		return
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("return_to_title")
	else:
		get_tree().change_scene_to_file("res://scenes/kaishi.tscn")

func _set_objective(text: String) -> void:
	if _objective != null:
		_objective.text = "目标 · " + text

func _show_message(text: String, duration: float = 3.5) -> void:
	if _story_panel == null:
		return
	# Narrow, screen-safe top-right card; never stretches a bottom panel over actors.
	_story_panel.position = Vector2(346, 48)
	_story_label.custom_minimum_size = Vector2(244, 0)
	_story_label.size = Vector2(244, 0)
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_story_label.add_theme_font_size_override("font_size", 10)
	var lines: PackedStringArray = []
	for paragraph: String in text.split("\n"):
		while paragraph.length() > 24:
			lines.append(paragraph.substr(0, 24))
			paragraph = paragraph.substr(24)
		lines.append(paragraph)
	_story_label.text = "\n".join(lines)
	_story_panel.size = Vector2(276, 0)
	_story_panel.visible = true
	_message_timer = minf(duration, 5.0)

func _update_hud() -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	if _mode_badge != null:
		_mode_badge.text = "Q · %s  灯芯 %d%%" % ["回忆区" if history_mode else "现实区", int(_history_energy)] if stage == Stage.ESCORT else "Q  视角 · %s" % ("回忆区 · 记忆重建" if history_mode else "现实区 · 未来重庆")
		_mode_badge.add_theme_color_override("font_color", Color("#73efff") if history_mode else Color("#b6c9d5"))
		if stage == Stage.ESCORT:
			_mode_badge.text += "\nC · 队伍%s" % ("等候中" if _escort_waiting else "跟随中")
	if _shard_label != null:
		_shard_label.text = "城市记忆  ◆ %d / 5" % memory_shards

func _pulse_calibration_bar() -> void:
	if _calibration_fill == null:
		return
	var tween := create_tween()
	_calibration_fill.color = Color("#fff0a0")
	tween.tween_property(_calibration_fill, "color", Color("#48ddeb"), 0.16)

func _spawn_memory_burst(world_position: Vector2) -> void:
	for i in range(12):
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
		shard.color = Color("#ffd15c") if i % 2 == 0 else Color("#55e9ff")
		shard.global_position = world_position
		shard.z_index = 30
		add_child(shard)
		var angle := TAU * float(i) / 12.0
		var target := world_position + Vector2(cos(angle), sin(angle)) * randf_range(24.0, 52.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate:a", 0.0, 0.42)
		tween.chain().tween_callback(shard.queue_free)

func _build_power_gates() -> void:
	for x in [1600.0, 1950.0]:
		var gate := Area2D.new()
		gate.name = "PowerGate%d" % (_power_gates.size() + 1)
		gate.position = Vector2(x, 282)
		gate.set_script(load("res://scripts/levels/future_power_gate.gd"))
		add_child(gate)
		_power_gates.append(gate)

func power_gate_opened(_gate: Area2D) -> void:
	_history_energy = minf(100.0, _history_energy + 12.0)
	_spawn_memory_burst(_gate.global_position + Vector2(0, -80))
	_show_message("供能门打开了。等队尾靠近，再按 Q 开灯一起穿过扫描区。", 4.5)
	_update_hud()

func _update_history_energy(delta: float) -> void:
	_history_energy = clampf(_history_energy + delta * (-HISTORY_DRAIN if history_mode else REALITY_RECHARGE), 0.0, 100.0)
	if history_mode and _history_energy <= 0.0:
		set_history_mode(false)
		_show_message("渝灯：‘先关灯缓一缓，避开红光，我很快就好。’", 3.0)
	_update_hud()

func _escort_arrived() -> bool:
	if _recruited.size() != 3 or player.global_position.x < 2460.0:
		return false
	for civilian in _recruited:
		if not is_instance_valid(civilian) or bool(civilian.get("waiting")) or civilian.global_position.x < 2310.0:
			return false
	for gate in _power_gates:
		if not bool(gate.get("powered")):
			return false
	return true

func _build_edge_walls() -> void:
	for x in [-8.0, WORLD_RIGHT + 8.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(x, 140)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 500)
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)

func _update_world_safety() -> void:
	if player.position.y < 450.0 and player.position.x >= -20.0 and player.position.x <= WORLD_RIGHT + 20.0:
		return
	if stage == Stage.ESCORT:
		_reset_escort()
	else:
		player.global_position = Vector2(_checkpoint_x, 282)
		player.velocity = Vector2.ZERO
		if stage == Stage.CHASE and memory_shards == 0:
			restart_chase()
		_show_message("渝灯把他拉回了最近的路口：‘慢点，路还在。’", 3.0)
	camera.reset_smoothing()

func restart_chase() -> void:
	player.global_position = Vector2(160, 282)
	player.velocity = Vector2.ZERO
	if is_instance_valid(_drone):
		_drone.call("reset_chase", player)
	_show_message("18秒后档案将被上传！按 R 重试；越过三处维护障碍，靠近后跳起接灯芯。", 5.0)

func _build_route_landmarks() -> void:
	for item in [[200.0, "轨道维护段"], [1100.0, "公共记忆站"], [2450.0, "山城社区 · 集合点"]]:
		var sign := Label.new()
		sign.text = str(item[1])
		sign.position = Vector2(float(item[0]) - 100.0, 150)
		sign.size = Vector2(200, 28)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size", 11)
		sign.add_theme_color_override("font_color", Color("#8ceeff"))
		sign.add_theme_constant_override("outline_size", 4)
		sign.z_index = 12
		add_child(sign)
	for i in range(9):
		var post := Line2D.new()
		var x := 1280.0 + float(i) * 140.0
		post.points = PackedVector2Array([Vector2(x, 244), Vector2(x, 216), Vector2(x + 55, 216)])
		post.width = 2
		post.default_color = Color(0.25, 0.82, 0.98, 0.40)
		post.z_index = 10
		add_child(post)

func _build_city_particles() -> void:
	_city_particles = CPUParticles2D.new()
	_city_particles.amount = 35
	_city_particles.lifetime = 4.0
	_city_particles.preprocess = 4.0
	_city_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_city_particles.emission_rect_extents = Vector2(340, 130)
	_city_particles.direction = Vector2(0.2, 1.0)
	_city_particles.gravity = Vector2.ZERO
	_city_particles.initial_velocity_min = 8.0
	_city_particles.initial_velocity_max = 15.0
	_city_particles.scale_amount_min = 1.0
	_city_particles.scale_amount_max = 2.0
	_city_particles.color = Color(0.4, 0.85, 1.0, 0.30)
	_city_particles.position = Vector2(320, 130)
	_city_particles.z_index = 4
	background_layers.add_child(_city_particles)

func _start_future_ambience() -> void:
	var shuttle_audio := AudioStreamPlayer.new()
	shuttle_audio.name = "FutureShuttleAudio"
	shuttle_audio.stream = load("res://assets/audio/future/第6关-飞船掠空.wav")
	shuttle_audio.volume_db = -17.0
	shuttle_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(shuttle_audio)

func _start_ending_city(choice: String) -> void:
	var accent := Color("#ffdca0") if choice == "living" else Color("#82b9d7")
	_mode_tint.color = Color(accent, 0.09)
	for gate in [get_node("PerfectReplica"), get_node("LivingMemory")]:
		gate.hide()
	var names := ["阿明的窑火", "老周的码头", "周叔的引路灯"]
	for i in range(_civilians.size()):
		var civilian := _civilians[i]
		civilian.set("ending_mode", choice)
		civilian.global_position = Vector2(2800.0 + float(i) * 65.0, 282)
		if choice == "archive":
			var frame := Line2D.new()
			frame.position = civilian.position
			frame.points = PackedVector2Array([Vector2(-23, 4), Vector2(-23, -83), Vector2(23, -83), Vector2(23, 4), Vector2(-23, 4)])
			frame.width = 2
			frame.default_color = Color("#8fd1ed")
			frame.z_index = 21
			add_child(frame)
			var label := Label.new()
			label.text = names[i]
			label.position = civilian.position + Vector2(-40, 9)
			label.add_theme_font_size_override("font_size", 9)
			label.z_index = 22
			add_child(label)
	if choice == "living":
		_spawn_memory_burst(Vector2(2930, 190))
		_show_public_memory_sign()

func _show_public_memory_sign() -> void:
	var sign := Label.new()
	sign.text = "公共记忆步道 · 窑火 / 江岸 / 引路灯"
	sign.position = Vector2(2720, 126)
	sign.add_theme_font_size_override("font_size", 12)
	sign.add_theme_color_override("font_color", Color("#ffdf9b"))
	sign.add_theme_constant_override("outline_size", 3)
	sign.z_index = 24
	add_child(sign)

func _update_ending_city(delta: float) -> void:
	if _ending_choice == "overwrite":
		for civilian in _civilians:
			civilian.modulate.a = move_toward(civilian.modulate.a, 0.0, delta * 0.25)

func _prepare_background_parallax() -> void:
	for layer_name in ["Far", "Mid"]:
		(background_layers.get_node(layer_name) as Sprite2D).position = Vector2.ZERO
