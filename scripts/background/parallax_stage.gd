class_name LayeredParallaxStage
extends ParallaxBackground

## 《洞见》正式横向视差舞台。
## 每关使用独立生成的 sky / far / mid 景片；近雾、前景雾、地面、碰撞和交互物保持独立。

const BACKGROUND_ROOT := "res://assets/production/backgrounds"
const SOURCE_HEIGHT := 720.0
const VIEW_HEIGHT := 360.0
const PLATE_Y := -96.0
const WORLD_GROUND_Y := 240.0
const MID_GROUND_OVERLAP := 7.0
const STAGE_START := -2200.0
const STAGE_END := 4600.0

const PROFILES := {
	"01": {"sky_tint": Color(0.82, 0.86, 1.0, 1.0), "far_tint": Color(0.72, 0.78, 0.94, 0.84), "mid_tint": Color(0.82, 0.86, 1.0, 0.93), "fog": Color(0.24, 0.34, 0.58, 0.13), "fore_fog": Color(0.08, 0.12, 0.24, 0.08)},
	"02": {"sky_tint": Color(0.92, 0.82, 0.78, 1.0), "far_tint": Color(0.82, 0.68, 0.64, 0.82), "mid_tint": Color(0.92, 0.82, 0.72, 0.94), "fog": Color(0.78, 0.42, 0.28, 0.10), "fore_fog": Color(0.30, 0.12, 0.06, 0.07)},
	"03": {"sky_tint": Color(0.84, 0.90, 0.88, 1.0), "far_tint": Color(0.72, 0.82, 0.80, 0.82), "mid_tint": Color(0.84, 0.90, 0.82, 0.93), "fog": Color(0.66, 0.76, 0.72, 0.13), "fore_fog": Color(0.18, 0.24, 0.18, 0.07)},
	"04": {"sky_tint": Color(0.72, 0.64, 0.58, 1.0), "far_tint": Color(0.62, 0.54, 0.50, 0.74), "mid_tint": Color(0.78, 0.66, 0.54, 0.91), "fog": Color(0.12, 0.10, 0.12, 0.16), "fore_fog": Color(0.02, 0.02, 0.03, 0.16)},
	"05": {"sky_tint": Color(0.96, 0.96, 1.0, 1.0), "far_tint": Color(0.82, 0.88, 0.96, 0.82), "mid_tint": Color(0.90, 0.92, 0.92, 0.92), "fog": Color(0.86, 0.91, 0.88, 0.17), "fore_fog": Color(0.55, 0.69, 0.68, 0.08)},
}

@export var era: String = "01"
@export var layer_palette: PackedColorArray = PackedColorArray([Color("#0a0f22"), Color("#14204a"), Color("#3a4f8f"), Color("#6b4a6b"), Color("#23273f")])

@onready var sky_layer: ParallaxLayer = $BG_Sky
@onready var far_layer: ParallaxLayer = $BG_Far
@onready var mid_layer: ParallaxLayer = $BG_Mid
@onready var near_layer: ParallaxLayer = $BG_Near
@onready var fore_layer: ParallaxLayer = $BG_Fore

func configure(era_id: String, colors: Array) -> void:
	era = era_id
	layer_palette = PackedColorArray(colors)

func _ready() -> void:
	var profile: Dictionary = PROFILES.get(era, PROFILES["01"])
	_build_image_layer(sky_layer, "sky", profile["sky_tint"])
	_build_image_layer(far_layer, "far", profile["far_tint"])
	_build_image_layer(mid_layer, "mid", profile["mid_tint"])
	_build_atmosphere(profile)

func _build_image_layer(target_layer: ParallaxLayer, layer_name: String, tint: Color) -> void:
	var path := "%s/%s/%s.png" % [BACKGROUND_ROOT, era, layer_name]
	var texture: Texture2D = load(path)
	if texture == null:
		if layer_name == "sky":
			_add_sky_fallback()
		return
	var display_scale := VIEW_HEIGHT / SOURCE_HEIGHT
	var layer_y := PLATE_Y
	if layer_name == "mid":
		layer_y = _grounded_mid_y(texture, display_scale)
	_add_mirrored_strip(target_layer, texture, display_scale, layer_y, tint)

func _grounded_mid_y(texture: Texture2D, display_scale: float) -> float:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return PLATE_Y
	var used := image.get_used_rect()
	if used.size.y <= 0:
		return PLATE_Y
	# 以 PNG 的最后一行非透明像素为建筑脚线，而不是以整张画布的底边定位。
	var visible_bottom := float(used.position.y + used.size.y) * display_scale
	return WORLD_GROUND_Y + MID_GROUND_OVERLAP - visible_bottom

func _add_sky_fallback() -> void:
	var band := ColorRect.new()
	band.name = "SkyFallback"
	band.color = layer_palette[0] if not layer_palette.is_empty() else Color("#0a0f22")
	band.position = Vector2(STAGE_START, -180)
	band.size = Vector2(STAGE_END - STAGE_START, 720)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(band)

func _build_atmosphere(profile: Dictionary) -> void:
	_add_vertical_fog(near_layer, "DepthMist", profile["fog"], 112.0, 150.0)
	_add_vertical_fog(fore_layer, "ForegroundMist", profile["fore_fog"], 276.0, 104.0)

func _add_vertical_fog(target_layer: ParallaxLayer, node_name: String, color: Color, y: float, height: float) -> void:
	var gradient := Gradient.new()
	var transparent := Color(color.r, color.g, color.b, 0.0)
	gradient.colors = PackedColorArray([transparent, color, color, transparent])
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.68, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 128
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var fog := TextureRect.new()
	fog.name = node_name
	fog.texture = texture
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_SCALE
	fog.position = Vector2(STAGE_START, y)
	fog.size = Vector2(STAGE_END - STAGE_START, height)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_layer.add_child(fog)

func _add_mirrored_strip(target_layer: ParallaxLayer, texture: Texture2D, display_scale: float, y: float, tint: Color) -> void:
	var step_x := float(texture.get_width()) * display_scale
	if step_x <= 0.0:
		return
	var x := STAGE_START
	var index := 0
	while x < STAGE_END:
		var sprite := Sprite2D.new()
		sprite.name = "Plate_%02d" % index
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2(display_scale, display_scale)
		sprite.position = Vector2(x, y)
		sprite.flip_h = index % 2 == 1
		sprite.modulate = tint
		target_layer.add_child(sprite)
		if target_layer == mid_layer:
			sprite.set_meta("visible_ground_y", WORLD_GROUND_Y + MID_GROUND_OVERLAP)
		x += step_x
		index += 1
