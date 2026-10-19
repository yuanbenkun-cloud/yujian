extends Control
## 双结局片尾：选择、跨关表现与制作人员信息在此真正汇合。

const VIEW_SIZE := Vector2(640, 360)
const BACKDROP := "res://assets/production/backgrounds/05/layered-preview.png"
const PHOTO_BACKDROP := "res://assets/production/story/ending-hongyadong-photo.png"

var _choice := "observe"
var _stage := 0
var _ready_for_input := false
var _content: Control
var _credits: Control
var _buttons: HBoxContainer
var _game_state: Node

func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	_choice = str(_game_state.get("ending_choice")) if _game_state != null else "observe"
	_build_scene()
	_play_ending()

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		if _stage == 0:
			_show_credits()
		else:
			_return_to_title()
		get_viewport().set_input_as_handled()

func _build_scene() -> void:
	var bg := TextureRect.new()
	bg.name = "EndingBackdrop"
	bg.texture = load(BACKDROP)
	bg.set_meta("ending_variant", _choice)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = VIEW_SIZE + Vector2(36, 20)
	bg.position = Vector2(-18, -10)
	bg.pivot_offset = bg.size * 0.5
	add_child(bg)
	var drift := create_tween().set_loops()
	drift.tween_property(bg, "position:x", -30.0, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(bg, "position:x", -18.0, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var wash := ColorRect.new()
	wash.color = Color(0.025, 0.035, 0.055, 0.48 if _choice == "photo" else 0.34)
	wash.size = VIEW_SIZE
	add_child(wash)
	_content = Control.new()
	_content.name = "EndingContent"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	_build_ending_content()
	_build_credits()

func _build_ending_content() -> void:
	var eyebrow := _label(_content, "终章 · 天亮以后", Vector2(52, 36), Vector2(360, 24), 13, Color("#e6bd70"))
	var title_text := "把洪崖洞留在照片里" if _choice == "photo" else "把清晨留给这一刻"
	var title := _label(_content, title_text, Vector2(50, 68), Vector2(540, 48), 29, Color("#f5f1e8"))
	var line := ColorRect.new()
	line.color = Color("#e1aa4d")
	line.position = Vector2(52, 122)
	line.size = Vector2(76, 3)
	_content.add_child(line)
	var body_text := "快门落下，层叠的吊脚楼、江雾和晨光被留在同一张照片里。\n这一次，他拍下了天亮时的洪崖洞。"
	if _choice != "photo":
		body_text = "他收起手机，扶起被风吹倒的提示牌。\n不是所有看见，都需要一张照片来证明。"
	var body := _label(_content, body_text, Vector2(52, 143), Vector2(410, 70), 14, Color(0.92, 0.92, 0.9))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 7)
	_build_choice_motif()
	var result := _label(_content, _result_summary(), Vector2(52, 231), Vector2(536, 48), 12, Color(0.78, 0.82, 0.83))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var quote := _label(_content, "洞见，不是看见更多，而是终于看见人。", Vector2(52, 294), Vector2(536, 28), 16, Color("#f0ca7a"))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(_content, "E / SPACE 继续片尾", Vector2(430, 333), Vector2(172, 18), 10, Color(0.72, 0.75, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for item in [eyebrow, title, line, body, result, quote, hint]:
		item.modulate.a = 0.0

func _build_choice_motif() -> void:
	if _choice == "photo":
		var frame := Panel.new()
		frame.name = "CapturedPhoto"
		frame.position = Vector2(474, 142)
		frame.size = Vector2(118, 82)
		frame.clip_contents = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f0eadc")
		style.border_color = Color("#f6d28a")
		style.set_border_width_all(3)
		style.set_corner_radius_all(2)
		frame.add_theme_stylebox_override("panel", style)
		_content.add_child(frame)
		var image := Sprite2D.new()
		image.name = "HongyadongPhoto"
		var snapshot: Texture2D = load(PHOTO_BACKDROP)
		image.texture = snapshot
		image.centered = false
		image.position = Vector2(6, 6)
		image.scale = Vector2(106.0 / float(snapshot.get_width()), 58.0 / float(snapshot.get_height()))
		frame.add_child(image)
		var stamp := Label.new()
		stamp.name = "PhotoTimestamp"
		stamp.text = str(_game_state.call("get_photo_timestamp", true)) if _game_state != null and _game_state.has_method("get_photo_timestamp") else "拍摄时间未记录"
		stamp.position = Vector2(7, 64)
		stamp.size = Vector2(104, 14)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stamp.add_theme_font_size_override("font_size", 7)
		stamp.add_theme_color_override("font_color", Color("#40382e"))
		frame.add_child(stamp)
		frame.rotation = 0.025
		frame.modulate.a = 0.0
	else:
		var marker := Control.new()
		marker.name = "UnrecordedMoment"
		marker.position = Vector2(478, 142)
		marker.size = Vector2(112, 82)
		_content.add_child(marker)
		var open_line := ColorRect.new()
		open_line.color = Color(0.92, 0.72, 0.36, 0.78)
		open_line.position = Vector2(0, 10)
		open_line.size = Vector2(2, 52)
		marker.add_child(open_line)
		var pause := Label.new()
		pause.text = "……"
		pause.position = Vector2(13, 2)
		pause.size = Vector2(92, 30)
		pause.add_theme_font_size_override("font_size", 24)
		pause.add_theme_color_override("font_color", Color("#f0ca7a"))
		marker.add_child(pause)
		var note := Label.new()
		note.text = "没有快门声。\n清晨仍在继续。"
		note.position = Vector2(14, 37)
		note.size = Vector2(94, 40)
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", Color(0.86, 0.87, 0.86))
		marker.add_child(note)
		marker.modulate.a = 0.0

func _build_credits() -> void:
	_credits = Control.new()
	_credits.name = "Credits"
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.visible = false
	add_child(_credits)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.018, 0.03, 0.82)
	shade.size = VIEW_SIZE
	_credits.add_child(shade)
	var title := _label(_credits, "渝  见", Vector2(0, 34), Vector2(640, 46), 31, Color("#f0c46d"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credits_text := "策划、程序与关卡　　独立游戏制作\n美术协作　　　　　　　生成素材与项目原有素材\n音乐与环境声　　　　　项目原创程序生成\n音效　　　　　　　　　Kenney CC0\n引擎　　　　　　　　　Godot Engine\n\n感谢每一个认真生活、也认真看见别人的人。"
	var body := _label(_credits, credits_text, Vector2(112, 94), Vector2(416, 150), 13, Color(0.88, 0.89, 0.91))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_constant_override("line_spacing", 8)
	_buttons = HBoxContainer.new()
	_buttons.position = Vector2(155, 274)
	_buttons.size = Vector2(330, 42)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	_credits.add_child(_buttons)
	var replay := Button.new()
	replay.text = "重温终章"
	replay.custom_minimum_size = Vector2(140, 38)
	replay.pressed.connect(_replay_finale)
	_buttons.add_child(replay)
	var back := Button.new()
	back.text = "返回标题"
	back.custom_minimum_size = Vector2(140, 38)
	back.pressed.connect(_return_to_title)
	_buttons.add_child(back)
	back.grab_focus.call_deferred()
	var hint := _label(_credits, "E / SPACE 返回标题", Vector2(424, 333), Vector2(178, 18), 10, Color(0.7, 0.74, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _play_ending() -> void:
	await get_tree().create_timer(0.45).timeout
	var tween := create_tween().set_parallel(true)
	var items := _content.get_children()
	for i in range(items.size()):
		var item = items[i]
		if item is CanvasItem:
			tween.tween_property(item, "modulate:a", 1.0, 0.42).set_delay(float(i) * 0.10)
	await tween.finished
	_ready_for_input = true

func _show_credits() -> void:
	if _stage != 0:
		return
	_stage = 1
	_ready_for_input = false
	_credits.visible = true
	_credits.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 0.0, 0.32)
	tween.parallel().tween_property(_credits, "modulate:a", 1.0, 0.45)
	await tween.finished
	_content.visible = false
	_ready_for_input = true

func _result_summary() -> String:
	if _game_state == null:
		return "他走过窑火、雨巷与警报，终于看见建筑背后的人。"
	var flags: Dictionary = _game_state.get("insight_flags")
	var labor_score := int(flags.get("labor", 0))
	var trust := str(flags.get("trust", _game_state.call("get_result_tier")))
	var rescued := bool(flags.get("responsibility", false))
	var craft_text := "岩壁前，他学会把力气落在正确的一刻" if labor_score >= 500 else "岩壁前，他学会在失手后重新找准节奏"
	var trust_text := "托付完整抵达" if trust == "完好" else ("受损的托付仍被送到" if trust == "受损" else "几乎失去的托付仍有人接住")
	var rescue_text := "；警报之下，一个人也没有落下。" if rescued else "。"
	return craft_text + "；" + trust_text + rescue_text

func _label(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _replay_finale() -> void:
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("travel_to", 5, "天亮以后，他又回到那座观景台。")

func _return_to_title() -> void:
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("return_to_title")
