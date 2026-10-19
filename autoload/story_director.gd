extends Node
## 全局叙事导演：使用分层背景、镜头缓动、章节卡和可跳过输入组织游戏内过场。

const VIEW_SIZE := Vector2(640, 360)
const BACKDROP_PATTERN := "res://assets/production/backgrounds/%02d/layered-preview.png"

const CHAPTERS := {
	1: ["第一章", "霓虹背后", "洪崖洞 · 今夜", "他只想找到一个没有路人的机位。"],
	2: ["第二章", "窑火与岩壁", "磁器口 · 旧时", "脚下一空，霓虹沉入江水；再抬头，只剩窑火。"],
	3: ["第三章", "一段托付", "中山古镇 · 雨巷", "水声退去，市声迎面而来。一包染布，把陌生人连在一起。"],
	4: ["第四章", "警报之下", "重庆防空洞 · 1941", "货包的绳结还在掌心，防空警报已经撕开山城。"],
	5: ["第五章", "天亮以后", "洪崖洞 · 清晨", "最后一个人走进光里。他回到了同一条街。"],
	6: ["第六章", "城市还记得", "重庆 · 2086年（未来想象）", "渝灯带着五段旧时光，照向重庆还没写完的明天。"],
}

const TRANSITION_STORIES := {
	2: {
		"art": "res://assets/production/story/portal-origin.png",
		"eyebrow": "洪崖门旧址 · 雨夜",
		"title": "取景框里，多出了一扇门",
		"body": "雨水顺着手机边缘钻进掌心。那张传单忽然挣脱，贴着金蓝色的光飞向旧城门。\n陈默想后退，脚下却传来窑锤、船号和一声遥远的呼救——下一步，石板不见了。",
	},
	3: {
		"art": "res://assets/production/story/level3-trust.png",
		"eyebrow": "中山古镇 · 雨巷",
		"title": "这一次，重量落在他手里",
		"body": "湿透的布包压进臂弯，绳结勒得手心发疼。掌柜没有催，只望着门外等工钱的人。\n远处那道光又亮了。陈默第一次没有朝它跑，而是把包往怀里抱紧。",
	},
	4: {
		"art": "res://assets/production/story/level4-responsibility.png",
		"eyebrow": "重庆防空洞 · 1941",
		"title": "他听见身后还有脚步",
		"body": "警报把洞壁震得发颤，碎土落进衣领。出口的光就在前面，身后却传来孩子的哭声。\n陈默停了一瞬，转身伸出手：‘跟紧我。一个也别落下。’",
	},
	5: {
		"art": "res://assets/production/story/level5-return.png",
		"eyebrow": "洪崖洞 · 清晨",
		"title": "原来他回到的，不只是原地",
		"body": "手机还停在昨夜的取景界面，江风里却混着窑火、湿布和煤油灯的气味。\n扫帚擦过石阶。陈默慢慢放下镜头——这一次，他先看见了举灯、撑船和早起的人。",
	},
}

const PROLOGUE_COMIC := [
	{"art": "res://assets/production/story/prologue-v3/atlas.png", "crop": Rect2(0, 0, 0.5, 0.5), "title": "赶去洪崖洞打卡", "body": "陈默只惦记着最火的夜景机位。\n再晚一点，人只会更多。"},
	{"art": "res://assets/production/story/prologue-v3/atlas.png", "crop": Rect2(0.5, 0, 0.5, 0.5), "title": "主路太挤，那就抄小路", "body": "导航上的窄巷似乎能绕开游客。\n他没多想，转身钻了进去。"},
	{"art": "res://assets/production/story/prologue-v3/atlas.png", "crop": Rect2(0, 0.5, 0.5, 0.5), "title": "小路上还是遇见了她", "body": "阿姨递来传单：‘小伙子，帮我扫一个吧，\n今天还差两单。’"},
	{"art": "res://assets/production/story/prologue-v3/atlas.png", "crop": Rect2(0.5, 0.5, 0.5, 0.5), "title": "怎么抄小路也躲不开", "body": "陈默敷衍一句便转身跑。\n阿姨攥着传单追了上来。"},
]

const COMIC_STORIES := {
	2: [
		{"art": "res://assets/production/story/portal-origin.png", "crop": Rect2(0.35, 0.05, 0.46, 0.72), "title": "古墙彻底裂开", "body": "追逐尽头，残影化成入口。陈默被卷进潮湿滚烫的旧时。"},
		{"art": "res://assets/production/story/level2-kiln-wall-illustration.png", "crop": Rect2(0.43, 0.05, 0.54, 0.67), "title": "山洪堵住窑场", "body": "塌石封死泄水道。水再涨一尺，窑火和这一街人的饭碗都会熄灭。", "sfx": "forge"},
		{"art": "res://assets/production/story/level2-kiln-wall-illustration.png", "crop": Rect2(0.18, 0.18, 0.52, 0.66), "title": "老人守不住了", "body": "老匠人的手已经发抖，却仍不肯离开烧了半辈子的窑。"},
		{"art": "res://assets/production/story/level2-kiln-wall-illustration.png", "crop": Rect2(0.34, 0.12, 0.62, 0.75), "title": "这一次，他留下", "body": "出口就在光后。陈默却接过工具：先凿开岩壁，让水退下去。", "sfx": "forge"},
	],
	3: [
		{"art": "res://assets/production/story/level2-kiln-wall-illustration.png", "crop": Rect2(0.48, 0.08, 0.50, 0.75), "title": "水退了，商路才醒", "body": "泄水道重新轰鸣。下游码头传来船号，却只等最后一包货。"},
		{"art": "res://assets/production/story/level3-trust.png", "crop": Rect2(0.00, 0.12, 0.48, 0.66), "title": "不是普通的染布", "body": "老掌柜把布包交给陈默：渡船开走前，必须送到码头老周手中。", "sfx": "cloth"},
		{"art": "res://assets/production/story/level3-trust.png", "crop": Rect2(0.28, 0.13, 0.45, 0.72), "title": "十几户人的工钱", "body": "布若受损，染坊收不到货款，十几户人的工钱也会落空。", "sfx": "cloth"},
		{"art": "res://assets/production/story/level3-trust.png", "crop": Rect2(0.48, 0.08, 0.50, 0.78), "title": "光在码头，他先抱紧包", "body": "时空门已在远处亮起。陈默第一次没有只顾着奔向出口。"},
	],
	4: [
		{"art": "res://assets/production/story/level3-trust.png", "crop": Rect2(0.00, 0.18, 0.52, 0.67), "title": "货赶上了船", "body": "老周刚系紧布包，刺耳警报便穿过雨幕。下一道残影骤然张开。", "sfx": "alert"},
		{"art": "res://assets/production/story/level4-responsibility.png", "crop": Rect2(0.00, 0.03, 0.48, 0.61), "title": "重庆，1941", "body": "炸弹正落向山城。陈默跌进防空洞，出口被烟尘和塌木切断。", "sfx": "explosion"},
		{"art": "res://assets/production/story/level4-responsibility.png", "crop": Rect2(0.33, 0.25, 0.49, 0.61), "title": "引路人倒下了", "body": "伤者指向东口：沿挡板走，把这里六个人都带出去。渝灯飞到前方，照亮了脚下的路。"},
		{"art": "res://assets/production/story/level4-responsibility.png", "crop": Rect2(0.47, 0.10, 0.50, 0.82), "title": "他本可以一个人跑", "body": "孩子抓住他的衣角。渝灯在前方亮起，陈默转身招呼：跟紧我，一个也别落下。"},
	],
	5: [
		{"art": "res://assets/production/story/level4-responsibility.png", "crop": Rect2(0.28, 0.20, 0.61, 0.67), "title": "最后一人走进光里", "body": "身后的脚步一个不少。洞口的裂光这才重新出现。"},
		{"art": "res://assets/production/story/level5-return.png", "crop": Rect2(0.00, 0.05, 0.48, 0.75), "title": "手机还停在昨夜", "body": "再睁眼，洪崖洞已是清晨。屏幕上的时间，仿佛只过去一分钟。"},
		{"art": "res://assets/production/story/level5-return.png", "crop": Rect2(0.28, 0.18, 0.50, 0.68), "title": "但他终于看见人", "body": "扫街的、摆摊的、撑船的——旧时残影，原来一直留在城市的日常里。"},
		{"art": "res://assets/production/story/level5-return.png", "crop": Rect2(0.47, 0.08, 0.50, 0.82), "title": "古墙为什么选中他", "body": "老人认出石扣：它不惩罚轻视历史的人，只让抄近路的人，把前人的路走完。"},
	],
}

var busy := false
var _skip_all := false
var _skip_enabled_at := 0
var _layer: CanvasLayer
var _root: Control
var _backdrop: TextureRect
var _wash: ColorRect
var _eyebrow: Label
var _title: Label
var _body: Label
var _line: ColorRect
var _skip_hint: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _illustration_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not busy or Time.get_ticks_msec() < _skip_enabled_at:
		return
	# 漫画自己消费 E / SPACE，每次只揭开一格；这里不能把同一次输入当作整段跳过。
	if _layer != null and _layer.find_child("StoryComic", true, false) != null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		_skip_all = true
		get_viewport().set_input_as_handled()

func play_prologue(on_finished: Callable = Callable()) -> void:
	if busy:
		return
	_run_prologue(on_finished)

func play_transition(to_path: String, level: int, fallback_caption: String = "") -> void:
	if busy:
		return
	# 出口常由 Area2D.body_entered 触发。延迟到空闲帧再启动，避免
	# change_scene_to_file 在物理回调中释放 CollisionObject2D。
	busy = true
	_run_transition.call_deferred(to_path, level, fallback_caption)

func _run_prologue(on_finished: Callable) -> void:
	busy = true
	_skip_all = false
	_freeze_current_player(true)
	var comic := _build_comic("序章 · 抄近路的人", PROLOGUE_COMIC, "点击进入第一章 · 洪崖洞迷途")
	await _wait_for_comic(comic)
	_freeze_current_player(false)
	busy = false
	if on_finished.is_valid():
		on_finished.call()

func _run_transition(to_path: String, level: int, fallback_caption: String) -> void:
	busy = true
	_skip_all = false
	_freeze_current_player(true)
	var beats: Array = COMIC_STORIES.get(level, []) if to_path.begins_with("res://scenes/guanqia/") else []
	var chapter: Array = CHAPTERS.get(level, ["旅途", "时间折叠", "重庆", fallback_caption])
	if beats.is_empty():
		await _run_simple_transition(to_path, level, fallback_caption, chapter)
		return
	var comic := _build_comic(str(chapter[0]) + " · " + str(chapter[1]), beats, "点击进入 · " + str(chapter[2]))
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("start_story_ambience", level)
	var err := get_tree().change_scene_to_file(to_path)
	if err != OK:
		push_error("场景切换失败：%s（错误码 %d）" % [to_path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	_freeze_current_player(true)
	await _wait_for_comic(comic)
	if audio != null:
		audio.call("stop_story_ambience")
	if to_path.begins_with("res://scenes/guanqia/") and level >= 2:
		await _play_arrival_portal()
	_freeze_current_player(false)
	busy = false

func _run_simple_transition(to_path: String, level: int, caption: String, chapter: Array) -> void:
	var accent := Color("#e6c77a")
	_build_overlay(level, accent)
	_root.modulate.a = 0.0
	var cover := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cover.tween_property(_root, "modulate:a", 1.0, 0.28)
	await cover.finished
	var err := get_tree().change_scene_to_file(to_path)
	if err != OK:
		push_error("场景切换失败：%s（错误码 %d）" % [to_path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	var body_text := caption if caption != "" else str(chapter[3])
	await _show_card(str(chapter[0]), str(chapter[1]), body_text, 1.8)
	await _fade_and_clear()
	_freeze_current_player(false)
	busy = false

func _build_comic(header_text: String, beats: Array, finish_text: String) -> Control:
	_clear_overlay()
	_illustration_mode = true
	_layer = CanvasLayer.new()
	_layer.name = "StoryDirectorLayer"
	_layer.layer = 88
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var comic := load("res://scripts/ui/story_comic.gd").new() as Control
	comic.name = "StoryComic"
	_layer.add_child(comic)
	comic.call("configure", header_text, beats, finish_text)
	return comic

func _wait_for_comic(comic: Control) -> void:
	while is_instance_valid(comic) and not bool(comic.get("complete_requested")):
		if _skip_all:
			comic.call("finish_immediately")
		await get_tree().process_frame
	if is_instance_valid(comic):
		var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(comic, "modulate:a", 0.0, 0.22)
		await fade.finished
	_clear_overlay()

func _play_arrival_portal() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.find_child("zhujue", true, false) as Node2D
	if player == null:
		return
	var portal_script: Script = load("res://scripts/systems/arrival_portal.gd")
	if portal_script == null:
		return
	var portal := Node2D.new()
	portal.set_script(portal_script)
	portal.name = "ArrivalPortal"
	scene.add_child(portal)
	await portal.call("play_arrival", player)

func _build_overlay(level: int, accent: Color, illustration_path: String = "") -> void:
	_clear_overlay()
	_illustration_mode = illustration_path != ""
	_layer = CanvasLayer.new()
	_layer.name = "StoryDirectorLayer"
	_layer.layer = 88
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.size = VIEW_SIZE + (Vector2(24, 4) if _illustration_mode else Vector2(64, 36))
	_backdrop.position = Vector2(-2, -2) if _illustration_mode else Vector2(-32, -18)
	_backdrop.texture = load(illustration_path) if _illustration_mode else load("res://assets/production/backgrounds/06_future/layered-preview.png" if level == 6 else BACKDROP_PATTERN % clampi(level, 1, 5))
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _illustration_mode else CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.pivot_offset = _backdrop.size * 0.5
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	_wash = ColorRect.new()
	_wash.color = Color(0.015, 0.025, 0.05, 0.0 if _illustration_mode else 0.74)
	_wash.size = VIEW_SIZE
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wash)
	_top_bar = ColorRect.new()
	_top_bar.color = Color(0.005, 0.008, 0.015, 0.78)
	_top_bar.size = Vector2(640, 38)
	_top_bar.visible = not _illustration_mode
	_root.add_child(_top_bar)
	_bottom_bar = ColorRect.new()
	_bottom_bar.color = Color(0.005, 0.008, 0.015, 0.91)
	_bottom_bar.position = Vector2(0, 248) if _illustration_mode else Vector2(0, 310)
	_bottom_bar.size = Vector2(640, 112) if _illustration_mode else Vector2(640, 50)
	_root.add_child(_bottom_bar)
	_line = ColorRect.new()
	_line.color = accent
	_line.position = Vector2(42, 316) if _illustration_mode else Vector2(74, 112)
	_line.size = Vector2(0, 3)
	_root.add_child(_line)
	_eyebrow = _make_label(Vector2(42, 258) if _illustration_mode else Vector2(74, 76), Vector2(220, 20) if _illustration_mode else Vector2(492, 24), 10 if _illustration_mode else 13, accent)
	_title = _make_label(Vector2(40, 278) if _illustration_mode else Vector2(72, 121), Vector2(220, 36) if _illustration_mode else Vector2(496, 58), 20 if _illustration_mode else 36, Color("#f4f0e7"))
	_body = _make_label(Vector2(270, 260) if _illustration_mode else Vector2(75, 190), Vector2(334, 62) if _illustration_mode else Vector2(490, 68), 11 if _illustration_mode else 14, Color(0.9, 0.91, 0.92, 0.94))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 7)
	_skip_hint = _make_label(Vector2(450, 337) if _illustration_mode else Vector2(390, 326), Vector2(158, 18) if _illustration_mode else Vector2(218, 18), 9 if _illustration_mode else 10, Color(0.68, 0.72, 0.78, 0.9))
	_skip_hint.text = "E / SPACE 跳过过场"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func _show_card(eyebrow_text: String, title_text: String, body_text: String, duration: float) -> void:
	_eyebrow.text = eyebrow_text
	_title.text = title_text
	_body.text = body_text
	for item in [_eyebrow, _title, _body]:
		item.modulate.a = 0.0
	var title_x := 40.0 if _illustration_mode else 72.0
	_title.position.x = title_x + 16.0
	_line.size.x = 0.0
	var intro := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro.tween_property(_line, "size:x", 178.0 if _illustration_mode else 74.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(_eyebrow, "modulate:a", 1.0, 0.3)
	intro.tween_property(_title, "modulate:a", 1.0, 0.32)
	intro.parallel().tween_property(_title, "position:x", title_x, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(_body, "modulate:a", 1.0, 0.28)
	await intro.finished
	await _wait_or_skip(duration)
	if _skip_all:
		return
	var outro := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	outro.tween_property(_eyebrow, "modulate:a", 0.0, 0.2)
	outro.parallel().tween_property(_title, "modulate:a", 0.0, 0.2)
	outro.parallel().tween_property(_body, "modulate:a", 0.0, 0.2)
	await outro.finished

func _wait_or_skip(seconds: float) -> void:
	var end_at := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_at and not _skip_all:
		await get_tree().process_frame

func _fade_and_clear() -> void:
	if not is_instance_valid(_root):
		return
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_root, "modulate:a", 0.0, 0.38 if not _skip_all else 0.16)
	await fade.finished
	_clear_overlay()

func _freeze_current_player(value: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.find_child("zhujue", true, false)
	if player != null and player.has_method("freeze"):
		player.call("freeze", value)

func _clear_overlay() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_root = null
	_top_bar = null
	_bottom_bar = null
	_illustration_mode = false
