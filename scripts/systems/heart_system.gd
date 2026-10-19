class_name HeartSystem
extends Node

## 第一关镇定值：三段式状态条。被追兵或人流持续挤压时损失一格。

signal changed(current: int)

const MAX_VALUE := 3
var current: int = MAX_VALUE
var _legacy_label: Label = null
var _panel: PanelContainer = null
var _segments: Array[ColorRect] = []
var _value_label: Label = null

func _ready() -> void:
	var cur := get_tree().current_scene
	if cur != null:
		_legacy_label = cur.find_child("UI_Hearts", true, false) as Label
		if _legacy_label != null:
			_legacy_label.visible = false
		var ui := cur.find_child("UI_Base", true, false)
		if ui != null:
			_build_hud(ui)
	_refresh()

func take_damage(amount: int = 1) -> void:
	if current <= 0:
		return
	current = maxi(0, current - amount)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_error", 0.82, -1.0)
	changed.emit(current)
	_refresh()
	_damage_pulse()
	if current <= 0:
		var lm := get_node_or_null("/root/LevelManager")
		if lm != null:
			lm.call("fail", "你放弃了洪崖洞的旅程。但有些路，该走还是要走。")

func _build_hud(parent: Node) -> void:
	_panel = PanelContainer.new()
	_panel.name = "ComposureHUD"
	_panel.position = Vector2(8, 46)
	_panel.size = Vector2(166, 43)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.075, 0.9)
	panel_style.border_color = Color("#a87658")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 3
	_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child.call_deferred(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	title.text = "镇定"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("#f3d8aa"))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 9)
	_value_label.add_theme_color_override("font_color", Color("#c9bca8"))
	header.add_child(_value_label)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	rows.add_child(bar)
	for i in range(MAX_VALUE):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(44, 8)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(segment)
		_segments.append(segment)

func _refresh() -> void:
	if _legacy_label != null:
		_legacy_label.text = "♥".repeat(current)
	if _value_label != null:
		_value_label.text = "%d / %d" % [current, MAX_VALUE]
	for i in range(_segments.size()):
		var lit := i < current
		var healthy_color := Color("#e8b35e") if current > 1 else Color("#e15e52")
		_segments[i].color = healthy_color if lit else Color(0.18, 0.19, 0.23, 0.82)

func _damage_pulse() -> void:
	if not is_instance_valid(_panel):
		return
	_panel.modulate = Color("#ff8273")
	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
