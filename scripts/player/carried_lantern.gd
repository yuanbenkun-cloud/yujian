extends Node2D
## 第四关随身煤油灯：跟随朝向、轻微摆动并让洞内光晕自然呼吸。

@export var side_offset := 11.0
@export var base_energy := 1.65

var _carrier: CharacterBody2D
var _light: PointLight2D
var _flame: CanvasItem
var _time := 0.0

func _ready() -> void:
	_carrier = get_parent() as CharacterBody2D
	_light = get_node_or_null("PointLight2D") as PointLight2D
	_flame = get_node_or_null("Flame") as CanvasItem
	_replace_lantern_art()

func _replace_lantern_art() -> void:
	var texture := load("res://assets/production/props/gameplay/carried-lantern-v3.png") as Texture2D
	if texture == null:
		return
	for child_name in ["Handle", "LanternBody", "LanternGlass", "Flame"]:
		var old_visual := get_node_or_null(child_name) as CanvasItem
		if old_visual != null:
			old_visual.hide()
	var sprite := Sprite2D.new()
	sprite.name = "LanternArtwork"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 0.45
	sprite.position = Vector2(0.0, -3.0)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = unshaded
	add_child(sprite)

func _process(delta: float) -> void:
	_time += delta
	if _carrier == null:
		return
	var facing := int(_carrier.get("look_dir"))
	position.x = side_offset * float(facing)
	var movement_sway := clampf(_carrier.velocity.x / 170.0, -1.0, 1.0) * 0.09
	rotation = lerpf(rotation, -movement_sway + sin(_time * 5.2) * 0.025, minf(1.0, delta * 8.0))
	if _light != null:
		_light.energy = base_energy + sin(_time * 9.7) * 0.10 + sin(_time * 17.3) * 0.045
	if _flame != null:
		_flame.scale.y = 0.88 + sin(_time * 12.0) * 0.13
