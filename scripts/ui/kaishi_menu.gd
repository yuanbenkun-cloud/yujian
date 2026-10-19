extends Control
## 开始界面：复用游戏夜景素材，以原生 Control 与 AnimationPlayer 构成首屏。

const VIEW_SIZE := Vector2(640, 360)
const BG_PATH := "res://assets/production/backgrounds/01/layered-preview.png"

var _started := false
var _default_button: Button

func _ready() -> void:
	_build_background()
	_build_title()
	_build_start_card()
	_build_controls()
	_build_ambient_animation()
	if bool(get_tree().get_meta("opening_video_just_finished", false)):
		get_tree().remove_meta("opening_video_just_finished")
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _build_background() -> void:
	var bg := TextureRect.new()
	bg.name = "NightBackdrop"
	bg.texture = load(BG_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = VIEW_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var wash := ColorRect.new()
	wash.name = "CinematicWash"
	# 保留夜雨氛围，但让吊脚楼、山体和水面层次在首屏仍然可读。
	wash.color = Color(0.025, 0.04, 0.075, 0.38)
	wash.size = VIEW_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.01, 0.02, 0.04, 0.42)
	top_bar.size = Vector2(640, 34)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.01, 0.02, 0.04, 0.72)
	bottom_bar.position = Vector2(0, 302)
	bottom_bar.size = Vector2(640, 58)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)

func _build_title() -> void:
	var chapter := Label.new()
	chapter.name = "Chapter"
	chapter.text = "重庆 · 一条被时间折叠的路"
	chapter.position = Vector2(48, 42)
	chapter.size = Vector2(300, 22)
	chapter.add_theme_font_size_override("font_size", 13)
	chapter.add_theme_color_override("font_color", Color("#e8c47a"))
	add_child(chapter)

	var line := ColorRect.new()
	line.color = Color("#e2a94b")
	line.position = Vector2(48, 70)
	line.size = Vector2(42, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	var title := Label.new()
	title.name = "Title"
	title.text = "渝  见"
	title.position = Vector2(46, 78)
	title.size = Vector2(300, 76)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("#f4c765"))
	add_child(title)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "你以为你只是在旅游。\n其实，你正在走过别人拼命活下来的路。"
	sub.position = Vector2(51, 158)
	sub.size = Vector2(320, 54)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96))
	sub.add_theme_constant_override("line_spacing", 7)
	add_child(sub)

	var genre := Label.new()
	genre.text = "叙事探索 · 横版步行 · 多结局选择"
	genre.position = Vector2(51, 226)
	genre.size = Vector2(300, 22)
	genre.add_theme_font_size_override("font_size", 11)
	genre.add_theme_color_override("font_color", Color(0.67, 0.73, 0.82))
	add_child(genre)

func _build_start_card() -> void:
	var panel := Panel.new()
	panel.name = "StartCard"
	panel.position = Vector2(394, 76)
	panel.size = Vector2(198, 196)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.09, 0.88)
	panel_style.border_color = Color(0.87, 0.65, 0.28, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var card_label := Label.new()
	card_label.text = "第一章"
	card_label.position = Vector2(18, 18)
	card_label.size = Vector2(162, 20)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 12)
	card_label.add_theme_color_override("font_color", Color("#d8b66f"))
	panel.add_child(card_label)

	var place := Label.new()
	place.text = "洪崖洞 · 迷途"
	place.position = Vector2(18, 45)
	place.size = Vector2(162, 24)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.add_theme_font_size_override("font_size", 17)
	place.add_theme_color_override("font_color", Color("#f3f4f6"))
	panel.add_child(place)

	var btn := Button.new()
	btn.name = "StartButton"
	btn.text = "开 始 新 故 事"
	btn.position = Vector2(18, 78)
	btn.size = Vector2(162, 38)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color("#17130d"))
	btn.add_theme_color_override("font_hover_color", Color("#17130d"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#e1aa4d")
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f2c86f")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#bd8032")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(_start)
	panel.add_child(btn)
	_default_button = btn

	var gs := get_node_or_null("/root/GameState")
	if gs != null and bool(gs.call("can_enter_future")):
		var future_btn := Button.new()
		future_btn.name = "FutureButton"
		future_btn.text = "第 六 章 · 未 来 重 庆"
		future_btn.position = Vector2(18, 122)
		future_btn.size = Vector2(162, 34)
		future_btn.focus_mode = Control.FOCUS_ALL
		future_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		future_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		future_btn.add_theme_font_size_override("font_size", 12)
		future_btn.add_theme_color_override("font_color", Color("#b9f4ff"))
		var future_style := StyleBoxFlat.new()
		future_style.bg_color = Color(0.05, 0.19, 0.25, 0.96)
		future_style.border_color = Color("#4ed8f2")
		future_style.set_border_width_all(1)
		future_style.set_corner_radius_all(4)
		future_btn.add_theme_stylebox_override("normal", future_style)
		var future_hover := future_style.duplicate() as StyleBoxFlat
		future_hover.bg_color = Color(0.08, 0.30, 0.38, 0.98)
		future_btn.add_theme_stylebox_override("hover", future_hover)
		future_btn.pressed.connect(_start_future)
		panel.add_child(future_btn)
		_default_button = future_btn
	elif gs != null and bool(gs.call("has_continue")):
		var continue_btn := Button.new()
		continue_btn.name = "ContinueButton"
		continue_btn.text = "继 续 · 第 %d 章" % int(gs.call("get_continue_level"))
		continue_btn.position = Vector2(18, 122)
		continue_btn.size = Vector2(162, 34)
		continue_btn.add_theme_font_size_override("font_size", 13)
		continue_btn.pressed.connect(_continue_story)
		panel.add_child(continue_btn)
	elif gs != null and int(gs.get("highest_unlocked_level")) > 1:
		var chapter_btn := Button.new()
		chapter_btn.name = "ChapterButton"
		chapter_btn.text = "章 节 选 择"
		chapter_btn.position = Vector2(18, 122)
		chapter_btn.size = Vector2(162, 34)
		chapter_btn.add_theme_font_size_override("font_size", 13)
		chapter_btn.pressed.connect(_open_chapter_select)
		panel.add_child(chapter_btn)

	var enter_hint := Label.new()
	enter_hint.text = "ENTER / SPACE"
	enter_hint.position = Vector2(18, 166)
	enter_hint.size = Vector2(162, 18)
	enter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enter_hint.add_theme_font_size_override("font_size", 10)
	enter_hint.add_theme_color_override("font_color", Color(0.56, 0.63, 0.72))
	panel.add_child(enter_hint)
	_default_button.grab_focus.call_deferred()

func _build_controls() -> void:
	var controls := Label.new()
	controls.name = "Controls"
	controls.text = "A  D  移动    SPACE  跳跃    E  交互    ESC  设置"
	controls.position = Vector2(44, 319)
	controls.size = Vector2(552, 22)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	add_child(controls)

func _build_ambient_animation() -> void:
	var player := AnimationPlayer.new()
	player.name = "AmbientAnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 2.4
	animation.loop_mode = Animation.LOOP_LINEAR
	var title_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(title_track, NodePath("Title:position"))
	animation.track_set_interpolation_type(title_track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(title_track, 0.0, Vector2(46, 78))
	animation.track_insert_key(title_track, 1.2, Vector2(46, 75))
	animation.track_insert_key(title_track, 2.4, Vector2(46, 78))
	var button_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(button_track, NodePath("StartCard/StartButton:modulate"))
	animation.track_set_interpolation_type(button_track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(button_track, 0.0, Color(1, 1, 1, 0.88))
	animation.track_insert_key(button_track, 1.2, Color.WHITE)
	animation.track_insert_key(button_track, 2.4, Color(1, 1, 1, 0.88))
	library.add_animation("ambient", animation)
	player.add_animation_library("", library)
	player.play("ambient")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		# E / Space / Enter 都执行当前聚焦按钮。旧逻辑无论焦点在哪都调用
		# “开始新故事”，导致已解锁的第六章看起来完全按不动。
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.is_visible_in_tree() and not focused.disabled:
			focused.pressed.emit()
		elif _default_button != null and not _default_button.disabled:
			_default_button.pressed.emit()
		else:
			_start()
		get_viewport().set_input_as_handled()

func _start() -> void:
	if _started:
		return
	_started = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_confirm", 0.9, -1.0)
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("start_new_story")
	else:
		get_tree().change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")

func _continue_story() -> void:
	if _started:
		return
	_started = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_confirm", 1.0, -1.0)
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("continue_story")

func _open_chapter_select() -> void:
	var overlay := ColorRect.new()
	overlay.name = "ChapterSelectOverlay"
	overlay.color = Color(0.01, 0.02, 0.04, 0.94)
	overlay.size = VIEW_SIZE
	overlay.z_index = 100
	add_child(overlay)
	var title := Label.new()
	title.text = "选择要重温的章节"
	title.position = Vector2(0, 35)
	title.size = Vector2(640, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0c46d"))
	overlay.add_child(title)
	var names := ["霓虹背后", "窑火与岩壁", "一段托付", "警报之下", "天亮以后"]
	var unlocked := int(get_node("/root/GameState").get("highest_unlocked_level"))
	for i in range(5):
		var button := Button.new()
		button.text = "%d　%s" % [i + 1, names[i]]
		button.position = Vector2(190, 84 + i * 43)
		button.size = Vector2(260, 34)
		button.disabled = i + 1 > unlocked
		button.pressed.connect(_start_chapter.bind(i + 1))
		overlay.add_child(button)
		if i == 0:
			button.grab_focus.call_deferred()
	var back := Button.new()
	back.text = "返回"
	back.position = Vector2(270, 310)
	back.size = Vector2(100, 32)
	back.pressed.connect(overlay.queue_free)
	overlay.add_child(back)

func _start_chapter(level: int) -> void:
	if _started:
		return
	_started = true
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("start_chapter", level)

func _start_future() -> void:
	if _started:
		return
	var lm := get_node_or_null("/root/LevelManager")
	if lm == null:
		return
	# 只有关卡管理器真正接收（或排队）请求后才锁住菜单。
	# 旧逻辑先置 _started，遇到上一段转场尚未释放时会永久吞掉点击。
	var accepted := bool(lm.call("start_future_bonus"))
	if not accepted:
		return
	_started = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_confirm", 1.05, -1.0)
	var future_button := find_child("FutureButton", true, false) as Button
	if future_button != null:
		future_button.text = "正 在 穿 越 …"
		future_button.disabled = true
