extends Node

## DialogueSystem（SPEC 6.4）：自研对话系统。无第三方插件。
## - load_data(path): 解析 JSON（每关一个 dialogue_levelN.json）
## - start_dialogue(node_id, speaker): 打开节点 → 逐行打字 → 选项/结束
## - choose(index): 选项回调；节点带 goods_event 时写入 GameState

signal ended

var active: bool = false
var _data: Dictionary = {}
var _queue: Array = []
var _options: Array = []
var _player: Node = null
var _panel: Control = null
var last_choice_next := ""
var _prelude_layer: CanvasLayer = null
var _prelude_serial := 0

func has_dialogue_node(node_id: String) -> bool:
	return _data.has(node_id) and _data[node_id] is Dictionary

func load_data(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_data.clear()
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_data = parsed
		return true
	_data.clear()
	return false

func start_dialogue(node_id: String, speaker: String = "") -> void:
	var p := _get_panel()
	if active:
		# 场景曾在对话期间重载时，旧面板引用会失效；遇到这种状态先自愈，而不是永久拒绝交互。
		if not is_instance_valid(_panel) or _panel != p:
			cancel_for_scene_change()
		else:
			return
	if p == null:
		return
	active = true
	last_choice_next = ""
	_panel = p
	_player = _get_player()
	if _player != null and _player.has_method("freeze"):
		_player.call("freeze", true)
	if speaker != "" and _panel.has_method("set_name_label"):
		_panel.call("set_name_label", speaker)
	if _panel.has_method("reset_portraits"):
		_panel.call("reset_portraits")
	## 关键：连接面板“推进请求”信号（每句按 E 后由面板发出）
	if not _panel.is_connected("advance_requested", _on_advance):
		_panel.connect("advance_requested", _on_advance)
	if not _panel.is_connected("line_completed", _on_line_completed):
		_panel.connect("line_completed", _on_line_completed)
	_panel.show()
	_open_node(node_id)

func _open_node(node_id: String) -> void:
	if not _data.has(node_id):
		_finish()
		return
	var node: Dictionary = _data[node_id]
	if node.has("goods_event") and str(node["goods_event"]) != "":
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			gs.call("apply_goods_event", str(node["goods_event"]))
	_queue = (node.get("lines", []) as Array).duplicate()
	_options = node.get("options", [])
	var prelude_image := str(node.get("prelude_image", ""))
	if prelude_image != "":
		_play_image_prelude(
			prelude_image,
			float(node.get("prelude_duration", 1.5)),
			str(node.get("prelude_stamp", ""))
		)
	else:
		_next_line()

func _play_image_prelude(image_path: String, hold_time: float, stamp_text: String = "") -> void:
	## 某些结局先让玩家完整看见画面，再恢复原对话；对话状态保持 active，避免玩家移动。
	if stamp_text == "@capture_time":
		var gs := get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_photo_timestamp"):
			stamp_text = str(gs.call("get_photo_timestamp", false))
	_prelude_serial += 1
	var serial := _prelude_serial
	_clear_image_prelude()
	if _panel != null:
		_panel.call("hide_panel")
	_prelude_layer = CanvasLayer.new()
	_prelude_layer.name = "DialoguePreludeLayer"
	_prelude_layer.layer = 87
	_prelude_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_prelude_layer)
	var stage := Control.new()
	stage.name = "DialoguePreludeStage"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.modulate.a = 0.0
	_prelude_layer.add_child(stage)
	var image := TextureRect.new()
	image.name = "DialoguePreludeImage"
	image.texture = load(image_path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_STOP
	if stamp_text == "":
		image.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(image)
	else:
		var shade := ColorRect.new()
		shade.color = Color(0.015, 0.02, 0.03, 0.88)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(shade)
		var photo := Panel.new()
		photo.name = "TimestampPhoto"
		photo.position = Vector2(58, 18)
		photo.size = Vector2(524, 324)
		var photo_style := StyleBoxFlat.new()
		photo_style.bg_color = Color("#f1eadc")
		photo_style.border_color = Color("#f7d58c")
		photo_style.set_border_width_all(4)
		photo_style.set_corner_radius_all(3)
		photo.add_theme_stylebox_override("panel", photo_style)
		stage.add_child(photo)
		image.position = Vector2(10, 10)
		image.size = Vector2(504, 272)
		photo.add_child(image)
		var stamp := Label.new()
		stamp.name = "PreludeTimestamp"
		stamp.text = stamp_text
		stamp.position = Vector2(12, 288)
		stamp.size = Vector2(498, 24)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stamp.add_theme_font_size_override("font_size", 12)
		stamp.add_theme_color_override("font_color", Color("#40382e"))
		photo.add_child(stamp)
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(stage, "modulate:a", 1.0, 0.35)
	reveal.tween_interval(maxf(0.4, hold_time))
	reveal.tween_property(stage, "modulate:a", 0.0, 0.35)
	await reveal.finished
	if serial != _prelude_serial or not active:
		return
	_clear_image_prelude()
	if is_instance_valid(_panel):
		_panel.show()
	_next_line()

func _clear_image_prelude() -> void:
	if is_instance_valid(_prelude_layer):
		_prelude_layer.queue_free()
	_prelude_layer = null

func _next_line() -> void:
	if _queue.size() > 0:
		var line: Dictionary = _queue.pop_front()
		_panel.call("play_line", str(line.get("speaker", "")), str(line.get("text", "")))
	else:
		if _options.size() > 0:
			_panel.call("show_options", _options)
		else:
			_finish()

func _on_advance() -> void:
	if _panel != null and bool(_panel.call("has_options")):
		return
	_next_line()

func _on_line_completed() -> void:
	# 最后一句读完就给出选择，不再要求一次额外的“继续”。
	if active and _queue.is_empty() and not _options.is_empty() and is_instance_valid(_panel):
		_panel.call("show_options", _options)

func choose(index: int) -> void:
	if index < 0 or index >= _options.size():
		_finish()
		return
	var opt: Dictionary = _options[index]
	var nxt := str(opt.get("next", ""))
	last_choice_next = nxt
	if nxt == "photo_take":
		var gs := get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("capture_photo_timestamp"):
			gs.call("capture_photo_timestamp")
	if nxt == "":
		_finish()
	else:
		_open_node(nxt)

func _finish() -> void:
	_prelude_serial += 1
	_clear_image_prelude()
	if _panel != null:
		_panel.call("hide_panel")
	if _player != null and _player.has_method("freeze"):
		_player.call("freeze", false)
	active = false
	ended.emit()

func cancel_for_scene_change() -> void:
	## 场景重载/切换专用：静默取消，不发送 ended，避免旧 NPC 回调启动追逐或结算。
	_prelude_serial += 1
	_clear_image_prelude()
	if is_instance_valid(_panel):
		_panel.call("hide_panel")
	if is_instance_valid(_player) and _player.has_method("freeze"):
		_player.call("freeze", false)
	active = false
	_queue.clear()
	_options.clear()
	_panel = null
	_player = null
	last_choice_next = ""

func _get_panel() -> Control:
	var cur := get_tree().current_scene
	if cur == null:
		return null
	var n := cur.find_child("DialoguePanel", true, false)
	return n as Control

func _get_player() -> Node:
	var cur := get_tree().current_scene
	if cur == null:
		return null
	return cur.find_child("zhujue", true, false)
