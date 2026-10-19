extends Node
## 第三关流程导演：顺序门、货物完整度 HUD、受损即时反馈。

const STAGE_TEXTS := [
	"先听老掌柜交代托付",
	"护送染布：经过茶馆街口",
	"护送染布：核验码头帮工",
	"护送染布：交给老周",
	"托付已经送达",
]

var stage := 0
var delivery_compromised := false
var _objective: Label
var _integrity: ProgressBar
var _integrity_text: Label
var _feedback: Label

func _ready() -> void:
	_build_hud()
	var gs := get_node_or_null("/root/GameState")
	if gs != null and not gs.is_connected("goods_changed", _on_goods_changed):
		gs.connect("goods_changed", _on_goods_changed)
	if gs != null:
		delivery_compromised = int(gs.get("goods_integrity")) < 50
	_refresh()

func can_use(required_stage: int) -> bool:
	return stage == required_stage

func advance_stage(next_stage: int) -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	stage = maxi(stage, next_stage)
	_refresh()
	_pop_feedback("新目标：%s" % STAGE_TEXTS[stage], Color("#9fd9b5"))

func show_locked(required_stage: int) -> void:
	var hint: String = STAGE_TEXTS[clampi(required_stage, 0, STAGE_TEXTS.size() - 1)]
	_pop_feedback("还不能进行：%s" % hint, Color("#ffd080"))

func show_completed() -> void:
	_pop_feedback("这段托付已经完成，继续向前", Color("#9fd9b5"))

func report_hazard(hazard_name: String) -> void:
	_pop_feedback("%s擦过货包——先把染布送到码头验货" % hazard_name, Color("#ff7474"))

func _on_goods_changed(current: int, delta: int, _event_name: String) -> void:
	_refresh_integrity(current)
	if delta < 0:
		delivery_compromised = current < 50
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null: audio.call("play_event", "cloth", 0.82, -2.0)
		_pop_feedback("染布不足50%：送到码头后须重新护送" if delivery_compromised else "染布受损，但剩余至少50%仍可交付", Color("#ff7474") if delivery_compromised else Color("#ffd080"))
		var camera := get_tree().current_scene.find_child("Camera2D", true, false)
		if camera != null and camera.has_method("shake"):
			camera.call("shake", 2.2, 0.16)
	elif delta == 0 and _event_name == "safe":
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null: audio.call("play_event", "ui_confirm", 1.08, -2.0)
		_pop_feedback("判断正确，货物完好", Color("#9fd9b5"))

func _refresh() -> void:
	if _objective != null:
		var warning := "　（不足50%，无法交付）" if delivery_compromised else ""
		_objective.text = "托付 %d/4　%s%s" % [stage, STAGE_TEXTS[stage], warning]
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		_refresh_integrity(int(gs.get("goods_integrity")))

func _refresh_integrity(value: int) -> void:
	if _integrity == null:
		return
	_integrity.value = value
	_integrity_text.text = "染布 %d%% / 至少50%%" % value
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#7fb58c") if value >= 70 else (Color("#d5a64f") if value >= 50 else Color("#c65353"))
	fill.set_corner_radius_all(3)
	_integrity.add_theme_stylebox_override("fill", fill)

func _pop_feedback(text: String, color: Color) -> void:
	if _feedback == null:
		return
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.visible = true
	_feedback.modulate.a = 1.0
	_feedback.position.y = 50
	var tween := create_tween()
	tween.tween_property(_feedback, "position:y", 43.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(_feedback, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _feedback.visible = false)

func _build_hud() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		cur = get_parent()
	var ui := cur.find_child("UI_Base", true, false)
	if ui == null:
		return
	_objective = Label.new()
	_objective.name = "UI_TradeObjective"
	_objective.position = Vector2(12, 46)
	_objective.size = Vector2(390, 22)
	_objective.add_theme_font_size_override("font_size", 12)
	_objective.add_theme_color_override("font_color", Color("#f0dfbe"))
	ui.add_child(_objective)
	_integrity = ProgressBar.new()
	_integrity.name = "UI_CargoIntegrity"
	_integrity.position = Vector2(470, 9)
	_integrity.size = Vector2(150, 16)
	_integrity.min_value = 0
	_integrity.max_value = 100
	_integrity.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#2a2d31d9")
	background.set_corner_radius_all(3)
	_integrity.add_theme_stylebox_override("background", background)
	ui.add_child(_integrity)
	_integrity_text = Label.new()
	_integrity_text.position = Vector2(470, 7)
	_integrity_text.size = Vector2(150, 19)
	_integrity_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_integrity_text.add_theme_font_size_override("font_size", 10)
	_integrity_text.add_theme_color_override("font_color", Color.WHITE)
	ui.add_child(_integrity_text)
	_feedback = Label.new()
	_feedback.name = "UI_TradeFeedback"
	_feedback.position = Vector2(155, 74)
	_feedback.size = Vector2(330, 24)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 13)
	_feedback.visible = false
	ui.add_child(_feedback)
