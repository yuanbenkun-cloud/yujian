extends CanvasLayer
## Screen-space memory treatment below HUD/dialogue, never intercepts input.

var active: bool = false
var strength: float = 0.0
var screen: ColorRect
var shader_material: ShaderMaterial

func _ready() -> void:
	layer = 10
	screen = ColorRect.new()
	screen.name = "MemoryScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://assets/shaders/memory_screen.gdshader")
	screen.material = shader_material
	add_child(screen)
	screen.hide()

func _process(delta: float) -> void:
	strength = move_toward(strength, 1.0 if active else 0.0, delta * 4.0)
	shader_material.set_shader_parameter("strength", strength)
	screen.visible = strength > 0.001

func set_active(value: bool) -> void:
	active = value
