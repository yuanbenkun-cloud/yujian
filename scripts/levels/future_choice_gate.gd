extends Area2D

@export var choice_id := "real"
@export var title := "真实记忆"
@export var texture_path := ""

var _prompt: Label
var _frame: Polygon2D

func _ready() -> void:
	z_index = 16
	collision_layer = 1
	collision_mask = 0
	monitoring = true
	_build_visual()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(170, 126)
	shape.position = Vector2(0, -64)
	shape.shape = rect
	add_child(shape)

func is_interaction_available() -> bool:
	return true

func set_prompt_visible(value: bool) -> void:
	if _prompt != null:
		_prompt.visible = value

func on_interact(_player: Node) -> void:
	var level := get_parent()
	if level != null and level.has_method("choose_memory_gate"):
		level.call("choose_memory_gate", choice_id)

func _build_visual() -> void:
	_frame = Polygon2D.new()
	_frame.polygon = PackedVector2Array([Vector2(-87, -130), Vector2(87, -130), Vector2(87, 0), Vector2(-87, 0)])
	_frame.color = Color(0.04, 0.10, 0.16, 0.93)
	add_child(_frame)
	if ResourceLoader.exists(texture_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.centered = true
		sprite.position = Vector2(0, -69)
		var size := sprite.texture.get_size()
		if size.x > 0 and size.y > 0:
			sprite.scale = Vector2(158.0 / size.x, 96.0 / size.y)
		sprite.modulate = Color(1, 1, 1, 0.86)
		add_child(sprite)
	var border := Line2D.new()
	border.points = PackedVector2Array([Vector2(-87, -130), Vector2(87, -130), Vector2(87, 0), Vector2(-87, 0), Vector2(-87, -130)])
	border.width = 2.0
	border.default_color = Color("#8cdbeb")
	add_child(border)
	var label := Label.new()
	label.position = Vector2(-82, -28)
	label.size = Vector2(164, 22)
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", border.default_color)
	add_child(label)
	_prompt = Label.new()
	_prompt.position = Vector2(-72, 5)
	_prompt.size = Vector2(144, 22)
	_prompt.text = "E  查看记忆"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color("#f7d58a"))
	_prompt.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.visible = false
	add_child(_prompt)
