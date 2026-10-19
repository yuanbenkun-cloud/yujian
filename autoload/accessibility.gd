extends Node
## 全局暂停与可访问性设置；保存到 user://settings.cfg。

var shake_scale := 1.0
var flash_scale := 1.0
var master_volume := 0.85
var music_volume := 0.78
var ambient_volume := 0.82
var sfx_volume := 0.9
var ui_volume := 0.85
var fullscreen_enabled := false
var _layer: CanvasLayer
var _was_paused := false
var _rebinding_action: StringName = &""
var _rebinding_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_controller_bindings()
	_load_settings()
	_apply_audio()
	_apply_window()

func _input(event: InputEvent) -> void:
	if _rebinding_action != &"" and event is InputEventKey and event.pressed and not event.echo:
		_set_keyboard_binding(_rebinding_action, event as InputEventKey)
		if _rebinding_button != null:
			_rebinding_button.text = _action_label(_rebinding_action) + "　" + (event as InputEventKey).as_text_keycode()
		_rebinding_action = &""
		_rebinding_button = null
		_save_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		var chat: Node = get_node_or_null("/root/YudengChat")
		if chat != null and bool(chat.get("is_open")):
			chat.call("close_chat")
			get_viewport().set_input_as_handled()
			return
		_toggle_menu()
		get_viewport().set_input_as_handled()

func _toggle_menu() -> void:
	if _layer != null and is_instance_valid(_layer):
		_close_menu()
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build_menu()

func _close_menu() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	get_tree().paused = _was_paused
	_save_settings()

func _build_menu() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(145, 15)
	panel.size = Vector2(350, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17161cf2")
	style.border_color = Color("#d69752")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(panel)
	var title := _label(panel, "暂停与设置", Vector2(24, 12), Vector2(302, 28), 19)
	title.add_theme_color_override("font_color", Color("#ffd59a"))
	_add_slider(panel, "总音量", "MasterSlider", 47, master_volume, func(v: float) -> void:
		master_volume = v; _apply_audio())
	_add_slider(panel, "音乐", "MusicSlider", 82, music_volume, func(v: float) -> void:
		music_volume = v; _apply_audio())
	_add_slider(panel, "环境声", "AmbientSlider", 117, ambient_volume, func(v: float) -> void:
		ambient_volume = v; _apply_audio())
	_add_slider(panel, "音效", "SFXSlider", 152, sfx_volume, func(v: float) -> void:
		sfx_volume = v; _apply_audio())
	_add_slider(panel, "界面音", "UISlider", 187, ui_volume, func(v: float) -> void:
		ui_volume = v; _apply_audio())
	var shake := CheckButton.new()
	shake.text = "减弱震屏"
	shake.position = Vector2(22, 226)
	shake.button_pressed = shake_scale < 0.5
	shake.toggled.connect(func(on: bool) -> void: shake_scale = 0.22 if on else 1.0)
	panel.add_child(shake)
	var flash := CheckButton.new()
	flash.text = "减弱闪光"
	flash.position = Vector2(174, 226)
	flash.button_pressed = flash_scale < 0.5
	flash.toggled.connect(func(on: bool) -> void: flash_scale = 0.18 if on else 1.0)
	panel.add_child(flash)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏"
	fullscreen.position = Vector2(22, 253)
	fullscreen.button_pressed = fullscreen_enabled
	fullscreen.toggled.connect(_set_fullscreen)
	panel.add_child(fullscreen)
	var controller_hint := Label.new()
	controller_hint.text = "手柄：摇杆 / A 跳跃 / X 交互"
	controller_hint.position = Vector2(105, 258)
	controller_hint.size = Vector2(222, 18)
	controller_hint.add_theme_font_size_override("font_size", 10)
	controller_hint.add_theme_color_override("font_color", Color(0.65, 0.69, 0.76))
	panel.add_child(controller_hint)
	var keys := Button.new()
	keys.text = "修改键位"
	keys.position = Vector2(22, 280)
	keys.size = Vector2(112, 30)
	keys.pressed.connect(_open_key_bindings)
	panel.add_child(keys)
	var close := Button.new()
	close.text = "继续游戏  ESC"
	close.position = Vector2(151, 280)
	close.size = Vector2(176, 30)
	close.pressed.connect(_close_menu)
	panel.add_child(close)
	close.grab_focus.call_deferred()

func _open_key_bindings() -> void:
	if _layer == null:
		return
	var old := _layer.get_node_or_null("KeyBindingsPanel")
	if old != null:
		old.queue_free()
	var panel := Panel.new()
	panel.name = "KeyBindingsPanel"
	panel.position = Vector2(145, 36)
	panel.size = Vector2(350, 286)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#11131af7")
	style.border_color = Color("#e1aa4d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(panel)
	var title := _label(panel, "键位设置", Vector2(24, 16), Vector2(302, 28), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffd59a"))
	var actions: Array[StringName] = [&"move_left", &"move_right", &"jump", &"interact"]
	for i in range(actions.size()):
		var action := actions[i]
		var button := Button.new()
		button.text = _action_label(action) + "　" + _keyboard_name(action)
		button.position = Vector2(62, 58 + i * 43)
		button.size = Vector2(226, 34)
		button.pressed.connect(_begin_rebind.bind(action, button))
		panel.add_child(button)
	var close := Button.new()
	close.text = "完成"
	close.position = Vector2(112, 238)
	close.size = Vector2(126, 34)
	close.pressed.connect(func() -> void:
		_rebinding_action = &""
		_rebinding_button = null
		panel.queue_free())
	panel.add_child(close)
	close.grab_focus.call_deferred()

func _begin_rebind(action: StringName, button: Button) -> void:
	_rebinding_action = action
	_rebinding_button = button
	button.text = _action_label(action) + "　请按新按键…"

func _set_keyboard_binding(action: StringName, key_event: InputEventKey) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement := InputEventKey.new()
	replacement.keycode = key_event.keycode
	replacement.physical_keycode = key_event.physical_keycode
	InputMap.action_add_event(action, replacement)

func _action_label(action: StringName) -> String:
	return {&"move_left": "向左", &"move_right": "向右", &"jump": "跳跃", &"interact": "交互"}.get(action, str(action))

func _keyboard_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_keycode()
	return "未设置"

func _set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	_apply_window()

func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _ensure_controller_bindings() -> void:
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("interact", JOY_BUTTON_X)

func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value):
			return
	var input := InputEventJoypadMotion.new()
	input.axis = axis
	input.axis_value = value
	InputMap.action_add_event(action, input)

func _add_joy_button(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var input := InputEventJoypadButton.new()
	input.button_index = button
	InputMap.action_add_event(action, input)

func _add_slider(parent: Control, title: String, slider_name: String, y: float, value: float, callback: Callable) -> void:
	_label(parent, title, Vector2(24, y), Vector2(72, 22), 12)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.position = Vector2(100, y)
	slider.size = Vector2(220, 22)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(callback)
	parent.add_child(slider)

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _apply_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.call("set_bus_volume", "Master", master_volume)
	audio.call("set_bus_volume", "Music", music_volume)
	audio.call("set_bus_volume", "Ambient", ambient_volume)
	audio.call("set_bus_volume", "SFX", sfx_volume)
	audio.call("set_bus_volume", "UI", ui_volume)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	ambient_volume = float(cfg.get_value("audio", "ambient", ambient_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	ui_volume = float(cfg.get_value("audio", "ui", ui_volume))
	shake_scale = float(cfg.get_value("accessibility", "shake", shake_scale))
	flash_scale = float(cfg.get_value("accessibility", "flash", flash_scale))
	fullscreen_enabled = bool(cfg.get_value("display", "fullscreen", fullscreen_enabled))
	for action in [&"move_left", &"move_right", &"jump", &"interact"]:
		var keycode := int(cfg.get_value("controls", str(action), 0))
		if keycode > 0:
			var key_event := InputEventKey.new()
			key_event.keycode = keycode as Key
			_set_keyboard_binding(action, key_event)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ui", ui_volume)
	cfg.set_value("accessibility", "shake", shake_scale)
	cfg.set_value("accessibility", "flash", flash_scale)
	cfg.set_value("display", "fullscreen", fullscreen_enabled)
	for action in [&"move_left", &"move_right", &"jump", &"interact"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				var code := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
				cfg.set_value("controls", str(action), int(code))
				break
	cfg.save("user://settings.cfg")
