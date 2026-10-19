extends Area2D
## 第三关可读、可躲避的路线危险；命中只记录货损，仍要求走到码头验货。

@export var required_stage := 1
@export var event_name := "stolen"
@export var hazard_name := "路面水花"
@export var motion_span := 36.0
@export var motion_speed := 1.2

var _origin_x := 0.0
var _phase := 0.0
var _triggered := false
var _carrier: AnimatedSprite2D
var _warning: Node2D
var _route: Node
var _player: Node2D

func _ready() -> void:
	_origin_x = position.x
	_phase = float(required_stage) * 1.7
	_build_water_carrier()
	_build_warning()
	_route = get_parent().get_node_or_null("ChoiceSystem")
	_player = get_parent().get_node_or_null("zhujue") as Node2D
	body_entered.connect(_on_body_entered)

func _build_warning() -> void:
	_warning = Node2D.new()
	_warning.name = "CargoHazardWarning"
	_warning.position.y = 246.0 - global_position.y - 94.0
	_warning.z_index = 40
	add_child(_warning)
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(0, -11), Vector2(11, 8), Vector2(-11, 8)])
	triangle.color = Color("#ffc45a")
	_warning.add_child(triangle)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(0, -11), Vector2(11, 8), Vector2(-11, 8), Vector2(0, -11)])
	outline.width = 1.5
	outline.default_color = Color("#332514")
	_warning.add_child(outline)
	var icon := Label.new()
	icon.text = "!"
	icon.position = Vector2(-4, -13)
	icon.add_theme_font_size_override("font_size", 15)
	icon.add_theme_color_override("font_color", Color("#332514"))
	_warning.add_child(icon)
	var caption := Label.new()
	caption.text = "避让 · 勿碰"
	caption.position = Vector2(-25, 10)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_constant_override("outline_size", 3)
	_warning.add_child(caption)
	_warning.hide()

func _build_water_carrier() -> void:
	var visual := get_node_or_null("HazardVisual") as Node2D
	if visual == null:
		return
	# 扁担、水桶已经画进专用动画，隐藏旧固定人物与几何桶。
	for child in visual.get_children():
		if child is CanvasItem:
			child.hide()
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5.0)
	frames.set_animation_loop("walk", true)
	for index in range(1, 7):
		var texture := load("res://assets/production/npc/water_carrier/walk-%d.png" % index) as Texture2D
		frames.add_frame("walk", texture)
	_carrier = AnimatedSprite2D.new()
	_carrier.name = "WaterCarrierAnimation"
	_carrier.sprite_frames = frames
	_carrier.centered = false
	_carrier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var display_scale := 70.0 / 88.0
	_carrier.scale = Vector2.ONE * display_scale
	_carrier.position = Vector2(-64.0 * display_scale, 246.0 - global_position.y - 112.0 * display_scale)
	_carrier.set_meta("grounded_visible_bottom_y", 246.0)
	_carrier.set_meta("visible_height_world", 70.0)
	visual.add_child(_carrier)
	_carrier.play("walk")

func _process(delta: float) -> void:
	if is_instance_valid(_warning):
		_warning.visible = not _triggered and is_instance_valid(_route) and int(_route.get("stage")) == required_stage and is_instance_valid(_player) and absf(_player.global_position.x - global_position.x) < 380
	if _triggered:
		return
	_phase += delta * motion_speed
	var previous_x := position.x
	position.x = _origin_x + sin(_phase) * motion_span
	if _carrier != null:
		if absf(position.x - previous_x) > 0.01:
			_carrier.flip_h = position.x < previous_x
		_carrier.speed_scale = clampf(absf(cos(_phase)) * motion_span * motion_speed / 35.0, 0.55, 1.4)

func _on_body_entered(body: Node) -> void:
	if _triggered or not (body is CharacterBody2D and body.has_method("set_look_dir")):
		return
	var route := get_tree().current_scene.find_child("ChoiceSystem", true, false)
	if route == null or int(route.get("stage")) != required_stage:
		return
	_triggered = true
	if _carrier != null:
		_carrier.pause()
	set_deferred("monitoring", false)
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("apply_goods_event", event_name)
	if route.has_method("report_hazard"):
		route.call("report_hazard", hazard_name)
	var camera := get_tree().current_scene.find_child("Camera2D", true, false)
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 2.4, 0.16)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.25, 0.16)
