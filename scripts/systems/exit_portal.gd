class_name ExitPortal
extends Area2D

## 关底出口（04→05 等）：玩家到达即通关（队伍跟在身后）。

var _used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if body is CharacterBody2D and body.has_method("set_look_dir"):
		var cur := get_tree().current_scene
		var group := cur.find_child("GroupFollower", true, false) if cur != null else null
		if group != null and group.has_method("all_rescued") and not bool(group.call("all_rescued")):
			var status := cur.find_child("UI_EscortStatus", true, false) as Label
			if status != null:
				status.text = "还有难民留在洞中，不能丢下他们。"
				status.visible = true
				status.modulate.a = 1.0
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.call("play_event", "ui_error", 0.92, -1.0)
			return
		_used = true
		body.call("freeze", true)
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			gs.call("record_insight", "responsibility", true)
		var warning := cur.find_child("BombWarning", true, false) if cur != null else null
		if warning != null and warning.has_method("stop"):
			warning.call("stop")
		_play_rescue_tableau(cur)

func _play_rescue_tableau(scene: Node) -> void:
	if scene == null:
		_finish_level()
		return
	var ui := scene.find_child("UI_Base", true, false)
	if ui == null:
		_finish_level()
		return
	var glow := ColorRect.new()
	glow.name = "RescueDawnGlow"
	glow.color = Color(1.0, 0.78, 0.48, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(glow)
	var text := Label.new()
	text.text = "最后一个人，也走进了光里。"
	text.position = Vector2(110, 154)
	text.size = Vector2(420, 36)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 19)
	text.add_theme_color_override("font_color", Color("#fff0c2"))
	text.modulate.a = 0.0
	ui.add_child(text)
	var tween := create_tween()
	tween.tween_property(glow, "color:a", 0.18, 0.45)
	tween.parallel().tween_property(text, "modulate:a", 1.0, 0.45)
	tween.tween_interval(1.05)
	tween.tween_property(glow, "color:a", 0.0, 0.32)
	tween.parallel().tween_property(text, "modulate:a", 0.0, 0.28)
	tween.tween_callback(_finish_level)

func _finish_level() -> void:
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null:
		lm.call("complete")
