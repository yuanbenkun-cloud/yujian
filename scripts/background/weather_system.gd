class_name WeatherSystem
extends CanvasLayer

## 各关共享的屏幕空间天气层。层级低于 UI_Base(10)，因此不会让雨、雾和热浪污染对白。

@export var era := "01"
@export var world_left := -700.0
@export var world_right := 2500.0

var _elapsed := 0.0
var _light_shafts: Array[Polygon2D] = []

func configure(era_id: String, left_edge: float, right_edge: float) -> void:
	era = era_id
	world_left = left_edge
	world_right = right_edge

func _ready() -> void:
	layer = 4
	match era:
		"01":
			# 第一关只保留干净夜色；动态主体交给孔明灯，避免雨、雾、光点同时抢画面。
			_add_tint("ClearNightTone", Color(0.08, 0.11, 0.19, 0.025))
		"02":
			_add_heat_haze()
			_add_motes("HeatEmbers", 46, Color(1.0, 0.40, 0.12, 0.60), Vector2(8, -24), 1.1, 2.6)
		"03":
			_add_tint("RainHaze", Color(0.18, 0.23, 0.27, 0.17))
			_add_rain("DrizzleParticles", 168, Color(0.68, 0.77, 0.82, 0.48), 285.0)
			_add_motes("RainMist", 34, Color(0.72, 0.78, 0.78, 0.12), Vector2(12, -3), 3.0, 6.5)
		"04":
			_add_tint("ShelterDustVeil", Color(0.20, 0.12, 0.09, 0.055))
			_add_motes("CaveDust", 72, Color(0.66, 0.53, 0.41, 0.33), Vector2(5, 4), 1.4, 3.6)
		"05":
			_add_tint("MorningWarmth", Color(1.0, 0.79, 0.47, 0.075))
			_add_morning_light()
			_add_motes("GoldenMotes", 58, Color(1.0, 0.82, 0.42, 0.42), Vector2(-3, -5), 1.8, 3.8)

func _process(delta: float) -> void:
	_elapsed += delta
	for i in range(_light_shafts.size()):
		var shaft := _light_shafts[i]
		if is_instance_valid(shaft):
			shaft.modulate.a = 0.56 + sin(_elapsed * 0.48 + float(i) * 0.9) * 0.12

func _add_tint(node_name: String, color: Color) -> void:
	var tint := ColorRect.new()
	tint.name = node_name
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = color
	add_child(tint)

func _add_heat_haze() -> void:
	var haze := ColorRect.new()
	haze.name = "HeatDistortion"
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/heat_haze.gdshader")
	haze.material = material
	add_child(haze)

func _add_rain(node_name: String, count: int, color: Color, speed: float) -> void:
	var rain := CPUParticles2D.new()
	rain.name = node_name
	rain.position = Vector2(320, -18)
	rain.amount = count
	rain.lifetime = 1.48
	rain.preprocess = 1.5
	rain.randomness = 0.54
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(380, 28)
	rain.direction = Vector2(0.20, 1.0)
	rain.spread = 7.0
	rain.gravity = Vector2(16, 90)
	rain.initial_velocity_min = speed * 0.78
	rain.initial_velocity_max = speed * 1.12
	rain.scale_amount_min = 0.7
	rain.scale_amount_max = 1.25
	rain.color = color
	rain.texture = _make_streak_texture()
	add_child(rain)
	rain.emitting = true

func _add_motes(node_name: String, count: int, color: Color, gravity: Vector2, min_scale: float, max_scale: float) -> void:
	var motes := CPUParticles2D.new()
	motes.name = node_name
	motes.position = Vector2(320, 180)
	motes.amount = count
	motes.lifetime = 4.6
	motes.preprocess = 4.6
	motes.randomness = 0.82
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(355, 205)
	motes.direction = Vector2(0, -1)
	motes.spread = 180.0
	motes.gravity = gravity
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 10.0
	motes.scale_amount_min = min_scale
	motes.scale_amount_max = max_scale
	motes.color = color
	motes.texture = _make_dot_texture()
	add_child(motes)
	motes.emitting = true

func _add_morning_light() -> void:
	for i in range(3):
		var shaft := Polygon2D.new()
		shaft.name = "MorningLightShaft%d" % (i + 1)
		var top_x := 505.0 + float(i) * 54.0
		shaft.polygon = PackedVector2Array([
			Vector2(top_x, -20), Vector2(top_x + 42, -20),
			Vector2(top_x - 110, 380), Vector2(top_x - 218, 380),
		])
		shaft.color = Color(1.0, 0.83, 0.48, 0.12 - float(i) * 0.018)
		add_child(shaft)
		_light_shafts.append(shaft)

func _make_dot_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func _make_streak_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.82, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.72), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 2
	texture.height = 15
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture
