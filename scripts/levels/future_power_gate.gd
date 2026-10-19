extends Area2D
## 现实层接通的轨道供能门；历史层无法操作实体设备。

var powered := false
var _blocker: StaticBody2D
var _label: Label
var _beam: ColorRect

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(140, 130)
	area_shape.shape = area_rect
	area_shape.position = Vector2(-25, -60)
	add_child(area_shape)
	_blocker = StaticBody2D.new()
	var wall := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(12, 150)
	wall.shape = wall_rect
	wall.position = Vector2(0, -75)
	_blocker.add_child(wall)
	add_child(_blocker)
	_beam = ColorRect.new()
	_beam.position = Vector2(-5, -150)
	_beam.size = Vector2(10, 150)
	_beam.color = Color(0.25, 0.82, 1.0, 0.60)
	_beam.z_index = 14
	add_child(_beam)
	_label = Label.new()
	_label.position = Vector2(-80, -174)
	_label.size = Vector2(160, 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_constant_override("outline_size", 3)
	_label.text = "现实层 · E 接通供能门"
	add_child(_label)

func is_interaction_available() -> bool:
	return not powered and int(get_parent().get("stage")) == 3

func set_prompt_visible(_value: bool) -> void:
	pass

func on_interact(_player: Node) -> void:
	var level := get_parent()
	if powered or not is_interaction_available():
		return
	if bool(level.get("history_mode")):
		level.call("_show_message", "阿明：‘这是现在的机器，先按 Q 回现实，咱们再接电。’", 3.0)
		return
	powered = true
	_blocker.set_deferred("collision_layer", 0)
	_beam.color = Color(0.35, 1.0, 0.65, 0.14)
	_label.text = "供能门已接通"
	level.call("power_gate_opened", self)
