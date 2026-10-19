extends "res://scripts/npc/interactable.gd"
## 第二关工位：只允许在对应工序到达后开启该工位的独立操作玩法。

@export var station_step := 0

var _work_particles: CPUParticles2D
var _work_glow: PointLight2D

func _ready() -> void:
	super._ready()
	_build_work_effects()

func on_interact(_player: Node) -> void:
	var forge := get_tree().current_scene.find_child("ForgeSequence", true, false)
	if forge != null:
		forge.call("open_station", station_step)

func set_effect_active(value: bool) -> void:
	if _work_particles != null:
		_work_particles.emitting = value
	if _work_glow != null:
		var target_energy := (1.55 if station_step == 0 else 1.05) if value else 0.0
		create_tween().tween_property(_work_glow, "energy", target_energy, 0.16)

func pulse_effect(strength: float = 1.0) -> void:
	var burst := CPUParticles2D.new()
	burst.name = "HeatSparkBurst" if station_step == 0 else "QuenchSplashBurst"
	burst.position = Vector2(0, -54 if station_step == 0 else -34)
	burst.z_index = 24
	burst.amount = maxi(5, int(8.0 * strength))
	burst.lifetime = 0.46
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.direction = Vector2(0, -1)
	burst.spread = 48.0 if station_step == 0 else 72.0
	burst.gravity = Vector2(0, 38 if station_step == 0 else 62)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 72.0 * strength
	burst.scale_amount_min = 0.55
	burst.scale_amount_max = 1.5
	burst.color = Color("#ffb34f") if station_step == 0 else Color("#9feaff")
	burst.texture = _make_particle_texture()
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _build_work_effects() -> void:
	_work_particles = CPUParticles2D.new()
	_work_particles.name = "HeatWorkParticles" if station_step == 0 else "QuenchWorkParticles"
	_work_particles.position = Vector2(0, -50 if station_step == 0 else -31)
	_work_particles.z_index = 23
	_work_particles.amount = 22 if station_step == 0 else 18
	_work_particles.lifetime = 0.72 if station_step == 0 else 0.92
	_work_particles.direction = Vector2(0, -1)
	_work_particles.spread = 34.0 if station_step == 0 else 58.0
	_work_particles.gravity = Vector2(0, -12 if station_step == 0 else -5)
	_work_particles.initial_velocity_min = 18.0
	_work_particles.initial_velocity_max = 48.0 if station_step == 0 else 34.0
	_work_particles.scale_amount_min = 0.45
	_work_particles.scale_amount_max = 1.25 if station_step == 0 else 1.55
	_work_particles.color = Color(1.0, 0.52, 0.16, 0.88) if station_step == 0 else Color(0.62, 0.90, 1.0, 0.72)
	_work_particles.texture = _make_particle_texture()
	_work_particles.emitting = false
	add_child(_work_particles)
	_work_glow = PointLight2D.new()
	_work_glow.name = "HeatWorkGlow" if station_step == 0 else "QuenchWorkGlow"
	_work_glow.position = Vector2(0, -46 if station_step == 0 else -30)
	_work_glow.color = Color("#ff8a3d") if station_step == 0 else Color("#7ddcff")
	_work_glow.energy = 0.0
	_work_glow.texture_scale = 3.1
	_work_glow.texture = _make_glow_texture()
	add_child(_work_glow)

func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.92),
		Color(1, 1, 1, 0.46),
		Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func _make_particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.36, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.82), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 5
	texture.height = 5
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
