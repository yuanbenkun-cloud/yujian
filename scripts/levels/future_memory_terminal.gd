extends Area2D

## 可复用的城市记忆终端。功能性文字由 Godot UI 绘制，贴图只负责外观。

@export var terminal_index := 0
var completed := false
var _sprite: Sprite2D
var _prompt: Label
var _time := 0.0
var _grounded_y := -47.0

func _ready() -> void:
	z_index = 16
	collision_layer = 1
	collision_mask = 0
	monitoring = true
	monitorable = true
	_build_collision()
	_build_visual()
	_build_base()

func _build_base() -> void:
	# 不再绘制大面积背板，设备轮廓直接透出原场景；只保留落地底座。
	var half_width := 24.0
	if _sprite != null:
		var bounds := _sprite.texture.get_image().get_used_rect()
		half_width = minf(24.0, float(bounds.size.x) * _sprite.scale.x * 0.5 + 5.0)
	var base := Polygon2D.new()
	base.name = "GroundedBase"
	base.polygon = PackedVector2Array([Vector2(-half_width - 4, 6), Vector2(-half_width, 2), Vector2(half_width, 2), Vector2(half_width + 4, 6), Vector2(half_width + 4, 11), Vector2(-half_width - 4, 11)])
	base.color = Color("#294353")
	add_child(base)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-half_width - 8, 6), Vector2(-half_width, 1), Vector2(half_width, 1), Vector2(half_width + 8, 6), Vector2(half_width, 11), Vector2(-half_width, 11)])
	shadow.color = Color(0.01, 0.025, 0.035, 0.55)
	shadow.z_index = -2
	add_child(shadow)

func _process(delta: float) -> void:
	_time += delta
	if _sprite != null:
		# 落脚位置固定，呼吸动效使用颜色，避免实体终端上下悬浮。
		_sprite.position.y = _grounded_y
		_sprite.self_modulate = Color.WHITE.lerp(Color(0.80, 0.96, 1.0), (sin(_time * 2.2) + 1.0) * 0.08)
	queue_redraw()

func is_interaction_available() -> bool:
	return not completed

func set_prompt_visible(value: bool) -> void:
	if _prompt != null:
		_prompt.visible = value and not completed

func on_interact(_player: Node) -> void:
	if completed:
		return
	var level := get_parent()
	if level != null and level.has_method("begin_terminal_calibration"):
		level.call("begin_terminal_calibration", self)

func mark_completed() -> void:
	completed = true
	if _prompt != null:
		_prompt.visible = false
	# 完成状态不对背板/边框整体染色。
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.9, 0.68, 1.0)
	queue_redraw()

func _build_collision() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(76, 112)
	shape.position = Vector2(0, -52)
	shape.shape = rect
	add_child(shape)

func _build_visual() -> void:
	var path := "res://assets/production/future/memory-terminal-v1.png"
	if ResourceLoader.exists(path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(path)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = true
		_sprite.position = Vector2(0, -47)
		var image := _sprite.texture.get_image()
		var used := image.get_used_rect() if image != null else Rect2i()
		if used.size.x > 0 and used.size.y > 0:
			var s := minf(82.0 / float(used.size.x), 104.0 / float(used.size.y))
			_sprite.scale = Vector2.ONE * s
			_grounded_y = 6.0 - (float(used.end.y) - _sprite.texture.get_height() * 0.5) * s
			_sprite.position.y = _grounded_y
		add_child(_sprite)
	_prompt = Label.new()
	_prompt.position = Vector2(-58, -132)
	_prompt.size = Vector2(116, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 11)
	_prompt.add_theme_color_override("font_color", Color("#f4c96b"))
	_prompt.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.95))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.text = "E  校准记忆"
	_prompt.visible = false
	add_child(_prompt)

func _draw() -> void:
	if _sprite != null:
		return
	# 素材尚未导入时的确定性占位外观，保证关卡仍可运行。
	var glow := Color("#55e4ff") if not completed else Color("#ffd36a")
	draw_circle(Vector2(0, -72), 28.0 + sin(_time * 2.0) * 1.5, Color(glow, 0.12))
	draw_rect(Rect2(-24, -94, 48, 78), Color("#102a3c"), true)
	draw_rect(Rect2(-20, -90, 40, 60), Color(0.04, 0.15, 0.23, 0.95), true)
	draw_polyline(PackedVector2Array([Vector2(-24, -94), Vector2(24, -94), Vector2(24, -16), Vector2(-24, -16), Vector2(-24, -94)]), glow, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -80), Vector2(12, -67), Vector2(0, -54), Vector2(-12, -67)]), Color("#ffb83f"))
	draw_rect(Rect2(-32, -17, 64, 12), Color("#172331"), true)

