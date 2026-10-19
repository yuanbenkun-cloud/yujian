extends Node
## 第五关探索闭环：收集六段“城市记忆”后才解锁最终观景台。

const TOTAL := 6
const NAMES := {"board": "城门", "old_man": "建造者", "wall": "旧墙", "flyer": "谋生者", "view": "两江", "lights": "灯火"}
var collected: Dictionary = {}
var _label: Label
var _hint: Label

func _ready() -> void:
	_build_hud()
	_refresh()

func collect(memory_id: String) -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	if collected.has(memory_id):
		return
	collected[memory_id] = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_confirm", 1.0 + collected.size() * 0.06, -1.0)
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("record_insight", "memory_" + memory_id, true)
	_refresh()
	_show_hint("记忆拼图：%s　%d/%d" % [NAMES.get(memory_id, memory_id), collected.size(), TOTAL], Color("#e8c87a"))
	var photo := get_tree().current_scene.find_child("diwuguan_zhaoxiangdian", true, false)
	if photo != null and collected.size() >= TOTAL:
		photo.modulate = Color("#fff2c6")

func can_finish() -> bool:
	return collected.size() >= TOTAL

func show_missing() -> void:
	var missing: Array[String] = []
	for key: String in NAMES:
		if not collected.has(key):
			missing.append(str(NAMES[key]))
	_show_hint("还没真正看完这里：%s" % "、".join(missing), Color("#ffd080"))

func _refresh() -> void:
	if _label != null:
		_label.text = "晨光记忆　%s%s　%d/%d" % ["●".repeat(collected.size()), "○".repeat(TOTAL - collected.size()), collected.size(), TOTAL]

func _show_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)
	_hint.visible = true
	_hint.modulate.a = 1.0
	_hint.scale = Vector2(0.86, 0.86)
	var tween := create_tween()
	tween.tween_property(_hint, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.5)
	tween.tween_property(_hint, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void: _hint.visible = false)

func _build_hud() -> void:
	var cur := get_tree().current_scene
	if cur == null: cur = get_parent()
	var ui := cur.find_child("UI_Base", true, false)
	_label = Label.new()
	_label.name = "UI_MemoryProgress"
	_label.position = Vector2(420, 8)
	_label.size = Vector2(205, 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color("#fff0cf"))
	_label.add_theme_color_override("font_outline_color", Color("#3a2b20"))
	_label.add_theme_constant_override("outline_size", 2)
	ui.add_child(_label)
	_hint = Label.new()
	_hint.name = "UI_MemoryHint"
	_hint.position = Vector2(120, 42)
	_hint.size = Vector2(400, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_outline_color", Color("#3a2b20"))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.visible = false
	ui.add_child(_hint)
