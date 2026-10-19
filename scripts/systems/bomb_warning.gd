class_name BombWarning
extends Node

## 第四关空袭：预警落点 → 可见导弹下落 → 挡板拦截或地面爆炸。
enum Phase { COOLDOWN, WARNING, FALLING, RESOLVE }

const GROUND_Y := 226.0
const WARNING_TIME := 0.82
const INITIAL_COOLDOWN := 3.0
const EARLY_COOLDOWN_MIN := 2.3
const EARLY_COOLDOWN_MAX := 3.0
const LATE_COOLDOWN_MIN := 0.35
const LATE_COOLDOWN_MAX := 0.70
const RAMP_STRIKES := 3
const RESOLVE_DELAY := 0.35
const MISSILE_START_Y := -38.0
const BLAST_RADIUS := 54.0
const GROUND_EFFECT_SINK := 18.0
const SHIELD_EFFECT_SINK := 4.0

@export var min_strike_x := 130.0
@export var max_strike_x := 1260.0

var _phase: int = Phase.COOLDOWN
var _cooldown := INITIAL_COOLDOWN
var _warn_left := 0.0
var _pending_x := 0.0
var _fall_speed := 165.0
var _strike_count := 0
var _active := false
var _flash: ColorRect
var _marker: Node2D
var _marker_visual: CanvasItem
var _missile: Node2D
var _missile_flame: Polygon2D
var _missile_light: PointLight2D
var _status: Label
var _shields: Array[Node] = []

func _ready() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		return
	_flash = cur.find_child("UI_BombFlash", true, false) as ColorRect
	_status = cur.find_child("UI_BombStatus", true, false) as Label
	_shields.assign(cur.find_children("BlastShield*", "Node2D", true, false))
	_build_marker(cur)
	_build_missile(cur)
	await get_tree().process_frame
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	match _phase:
		Phase.COOLDOWN:
			_cooldown -= delta
			if _cooldown <= 0.0:
				_start_warning()
		Phase.WARNING:
			_warn_left -= delta
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.026)
			_marker.scale = Vector2.ONE * (0.92 + pulse * 0.18)
			_marker_visual.modulate.a = 0.55 + pulse * 0.45
			if _flash != null:
				var access := get_node_or_null("/root/Accessibility")
				var flash_scale := float(access.get("flash_scale")) if access != null else 1.0
				_flash.modulate.a = (0.05 + pulse * 0.08) * flash_scale
			if _warn_left <= 0.0:
				_launch_missile()
		Phase.FALLING:
			_fall_speed += 230.0 * delta
			_missile.position.y += _fall_speed * delta
			_missile_flame.scale.y = 0.78 + randf_range(0.0, 0.45)
			if _missile_light != null:
				_missile_light.energy = 0.72 + 0.24 * absf(sin(Time.get_ticks_msec() * 0.018))
			var shield := _shield_at(_pending_x)
			var impact_y := GROUND_Y
			if shield != null:
				impact_y = float(shield.call("get_impact_y"))
			if _missile.position.y >= impact_y:
				_explode(shield)

func stop() -> void:
	_active = false
	if _marker != null:
		_marker.visible = false
	if _missile != null:
		_missile.visible = false
	if _flash != null:
		_flash.visible = false
	if _status != null:
		_status.visible = false

func _start_warning() -> void:
	var cur := get_tree().current_scene
	var player := cur.find_child("zhujue", true, false) as Node2D
	var base := 180.0 if player == null else player.global_position.x
	_pending_x = clampf(base + randf_range(-42.0, 72.0), min_strike_x, max_strike_x)
	_phase = Phase.WARNING
	_warn_left = WARNING_TIME
	_marker.visible = true
	_marker.global_position = Vector2(_pending_x, GROUND_Y)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "alert", 0.82, -1.0)
	if _flash != null:
		_flash.color = Color("#b92121")
		_flash.visible = true
	if _status != null:
		_status.text = "空袭预警！进入挡板下方，或离开红色落点"
		_status.visible = true

func _launch_missile() -> void:
	_phase = Phase.FALLING
	_fall_speed = 165.0
	_missile.global_position = Vector2(_pending_x, MISSILE_START_Y)
	_missile.visible = true
	if _status != null:
		_status.text = "航弹下落！"

func _explode(shield: Node) -> void:
	_phase = Phase.RESOLVE
	var impact_pos := _missile.global_position
	_missile.visible = false
	_marker.visible = false
	_spawn_impact_flash(shield != null)
	_spawn_explosion(impact_pos, shield != null)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		# 航弹命中专属轰炸声；挡板吸收时更闷、更低，地面直击更响。
		audio.call("play_event", "bombardment", 0.86 if shield != null else 1.0, -4.5 if shield != null else -1.0)
	var camera := get_tree().current_scene.find_child("Camera2D", true, false)
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 6.5 if shield == null else 4.0, 0.32)
	if shield != null:
		shield.call("absorb_hit")
		if _status != null:
			_status.text = "挡板接住了冲击，但耐久正在下降"
	else:
		if _hit_anyone(Vector2(_pending_x, GROUND_Y), BLAST_RADIUS):
			var lm := get_node_or_null("/root/LevelManager")
			if lm != null:
				lm.call("fail", "落弹穿过了掩体空隙——队伍里有人没能走出去。")
		if _status != null:
			_status.text = "爆炸！下一轮空袭即将到来"
	get_tree().create_timer(RESOLVE_DELAY).timeout.connect(_reset_cycle)

func _reset_cycle() -> void:
	if _status != null:
		_status.visible = false
	_phase = Phase.COOLDOWN
	var bounds := _current_cooldown_bounds()
	_cooldown = randf_range(bounds.x, bounds.y)
	_strike_count += 1

func _current_cooldown_bounds() -> Vector2:
	var pressure := clampf(float(_strike_count) / float(RAMP_STRIKES), 0.0, 1.0)
	return Vector2(
		lerpf(EARLY_COOLDOWN_MIN, LATE_COOLDOWN_MIN, pressure),
		lerpf(EARLY_COOLDOWN_MAX, LATE_COOLDOWN_MAX, pressure)
	)

func _shield_at(world_x: float) -> Node:
	for shield in _shields:
		if is_instance_valid(shield) and shield.has_method("covers_x") and bool(shield.call("covers_x", world_x)):
			return shield
	return null

func _hit_anyone(pos: Vector2, radius: float) -> bool:
	var cur := get_tree().current_scene
	if cur == null:
		return false
	var targets: Array[Node2D] = []
	var player := cur.find_child("zhujue", true, false) as Node2D
	if player != null:
		targets.append(player)
	var container := cur.find_child("NPC_Group", true, false)
	if container != null:
		for child in container.get_children():
			if child is Node2D:
				targets.append(child as Node2D)
	for target in targets:
		if target.global_position.distance_to(pos) < radius:
			return true
	return false

func _build_marker(cur: Node) -> void:
	_marker = Node2D.new()
	_marker.name = "BombMarker"
	_marker.z_index = 35
	var visual := Node2D.new()
	visual.name = "AirRaidWarningEmblem"
	_marker_visual = visual
	_marker.add_child(visual)
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	visual.material = material
	for ring_data in [[25.0, 3.0, Color("#ff553d")], [36.0, 2.0, Color(1.0, 0.72, 0.32, 0.78)]]:
		var ring := Line2D.new()
		ring.width = float(ring_data[1])
		ring.default_color = ring_data[2] as Color
		var points := PackedVector2Array()
		for i in range(25):
			var angle := TAU * float(i) / 24.0
			# 留出四个断口，让标记不像旧版单条色块。
			var radius := float(ring_data[0]) + sin(angle * 4.0) * 1.2
			points.append(Vector2(cos(angle), sin(angle) * 0.36) * radius)
		ring.points = points
		visual.add_child(ring)
	var bomb := Polygon2D.new()
	bomb.name = "BombIcon"
	bomb.polygon = PackedVector2Array([Vector2(-4, -18), Vector2(4, -18), Vector2(7, 6), Vector2(0, 16), Vector2(-7, 6)])
	bomb.color = Color("#ffe0a0")
	visual.add_child(bomb)
	for side in [-1.0, 1.0]:
		var fin := Polygon2D.new()
		fin.polygon = PackedVector2Array([Vector2(side * 4, -13), Vector2(side * 13, -20), Vector2(side * 7, -5)])
		fin.color = Color("#ff7048")
		visual.add_child(fin)
	cur.add_child.call_deferred(_marker)
	_marker.visible = false

func _build_missile(cur: Node) -> void:
	_missile = Node2D.new()
	_missile.name = "FallingMissile"
	_missile.z_index = 40
	var missile_material := CanvasItemMaterial.new()
	missile_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_missile.material = missile_material
	var body := Sprite2D.new()
	body.use_parent_material = true
	body.texture = load("res://assets/production/props/gameplay/aerial-bomb.png")
	_missile.add_child(body)
	_missile_flame = Polygon2D.new()
	_missile_flame.use_parent_material = true
	_missile_flame.polygon = PackedVector2Array([Vector2(-4, -19), Vector2(4, -19), Vector2(0, -31)])
	_missile_flame.color = Color(0.88, 0.72, 0.43, 0.72)
	_missile.add_child(_missile_flame)
	_missile_light = PointLight2D.new()
	_missile_light.name = "MissileGlow"
	_missile_light.texture = _make_radial_light_texture()
	_missile_light.texture_scale = 2.2
	_missile_light.color = Color("#ffad55")
	_missile_light.energy = 0.82
	_missile_light.shadow_enabled = false
	_missile.add_child(_missile_light)
	cur.add_child.call_deferred(_missile)
	_missile.visible = false

func _spawn_explosion(pos: Vector2, blocked: bool) -> Node2D:
	## 爆炸反馈全部挂在临时节点下：火花、暖光都会衰减并在一秒内销毁。
	var feedback := Node2D.new()
	feedback.name = "ExplosionFeedback"
	feedback.z_index = 41
	# 航弹判定点位于接触面上方；视觉底边继续压入地面/挡板，消除浮空缝隙。
	var contact_sink := SHIELD_EFFECT_SINK if blocked else GROUND_EFFECT_SINK
	feedback.global_position = pos + Vector2(0, contact_sink)
	feedback.set_meta("contact_sink", contact_sink)
	get_tree().current_scene.add_child(feedback)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var strength := 0.76 if blocked else 1.0
	var outer_flame := Polygon2D.new()
	outer_flame.name = "GroundFlameOuter"
	outer_flame.z_index = 2
	outer_flame.material = additive
	outer_flame.polygon = PackedVector2Array([
		Vector2(-38, 1), Vector2(-29, -6), Vector2(-20, -8),
		Vector2(-14, -24), Vector2(-8, -15), Vector2(-2, -43),
		Vector2(5, -20), Vector2(13, -31), Vector2(18, -13),
		Vector2(29, -8), Vector2(39, 1),
	])
	outer_flame.color = Color("#ff9b32") if blocked else Color("#ff5b2d")
	outer_flame.scale = Vector2(0.42, 0.22) * strength
	feedback.add_child(outer_flame)
	var outer_tween := create_tween()
	outer_tween.tween_property(outer_flame, "scale", Vector2.ONE * strength, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	outer_tween.tween_property(outer_flame, "scale", Vector2(1.22, 0.76) * strength, 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	outer_tween.parallel().tween_property(outer_flame, "modulate:a", 0.0, 0.30)

	var inner_flame := Polygon2D.new()
	inner_flame.name = "GroundFlameInner"
	inner_flame.z_index = 3
	inner_flame.material = additive
	inner_flame.polygon = PackedVector2Array([
		Vector2(-23, 0), Vector2(-15, -7), Vector2(-9, -19),
		Vector2(-3, -12), Vector2(2, -31), Vector2(8, -14),
		Vector2(16, -9), Vector2(24, 0),
	])
	inner_flame.color = Color("#ffe28a")
	inner_flame.scale = Vector2(0.34, 0.18) * strength
	feedback.add_child(inner_flame)
	var inner_tween := create_tween()
	inner_tween.tween_property(inner_flame, "scale", Vector2.ONE * strength, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	inner_tween.tween_property(inner_flame, "scale", Vector2(1.08, 0.66) * strength, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	inner_tween.parallel().tween_property(inner_flame, "modulate:a", 0.0, 0.24)

	var shockwave := Polygon2D.new()
	shockwave.name = "GroundShockwave"
	shockwave.z_index = 1
	shockwave.material = additive
	shockwave.polygon = PackedVector2Array([
		Vector2(-32, 0), Vector2(-18, -4), Vector2(0, -6), Vector2(18, -4),
		Vector2(32, 0), Vector2(18, 4), Vector2(0, 5), Vector2(-18, 4),
	])
	shockwave.color = Color(1.0, 0.66, 0.24, 0.9)
	shockwave.scale = Vector2(0.35, 0.45) * strength
	feedback.add_child(shockwave)
	var shock_tween := create_tween()
	shock_tween.tween_property(shockwave, "scale", Vector2(2.7, 0.62) * strength, 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	shock_tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.34)

	var glow := Sprite2D.new()
	glow.name = "ExplosionGlow"
	glow.z_index = 1
	glow.texture = _make_radial_light_texture()
	glow.material = additive
	glow.scale = Vector2.ONE * (3.0 if blocked else 3.7)
	glow.modulate = Color(1.0, 0.42, 0.12, 0.54 if blocked else 0.68)
	feedback.add_child(glow)
	var glow_tween := create_tween()
	glow_tween.tween_property(glow, "scale", glow.scale * 1.28, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	glow_tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.48)

	var flash_light := PointLight2D.new()
	flash_light.name = "ExplosionFlashLight"
	flash_light.texture = _make_radial_light_texture()
	# 64px 径向纹理：相较上一版将实际照明直径扩大为两倍。
	flash_light.texture_scale = 7.2 if blocked else 8.8
	flash_light.color = Color("#ff9f45") if blocked else Color("#ff7a32")
	flash_light.energy = 2.8 if blocked else 3.8
	flash_light.shadow_enabled = false
	feedback.add_child(flash_light)
	var light_tween := create_tween()
	light_tween.tween_property(flash_light, "energy", 0.0, 0.46).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var sparks := CPUParticles2D.new()
	sparks.name = "ExplosionSparks"
	sparks.z_index = 3
	sparks.amount = 20 if blocked else 32
	sparks.lifetime = 0.58
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 82.0
	sparks.gravity = Vector2(0, 230)
	sparks.initial_velocity_min = 95.0
	sparks.initial_velocity_max = 225.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.4
	sparks.color = Color("#ffd76a")
	sparks.material = additive
	feedback.add_child(sparks)
	sparks.emitting = true

	var smoke := CPUParticles2D.new()
	smoke.name = "GroundBlastSmoke"
	smoke.z_index = 0
	smoke.amount = 10 if blocked else 16
	smoke.lifetime = 0.92
	smoke.one_shot = true
	smoke.explosiveness = 0.94
	smoke.direction = Vector2(0, -1)
	smoke.spread = 46.0
	smoke.gravity = Vector2(0, -12)
	smoke.initial_velocity_min = 24.0
	smoke.initial_velocity_max = 62.0
	smoke.scale_amount_min = 2.5
	smoke.scale_amount_max = 5.5
	smoke.color = Color(0.22, 0.19, 0.17, 0.72)
	feedback.add_child(smoke)
	smoke.emitting = true

	var debris := CPUParticles2D.new()
	debris.name = "ExplosionDebris"
	debris.z_index = 0
	debris.amount = 18 if blocked else 28
	debris.lifetime = 0.85
	debris.one_shot = true
	debris.explosiveness = 0.95
	debris.direction = Vector2(0, -1)
	debris.spread = 72.0
	debris.gravity = Vector2(0, 150)
	debris.initial_velocity_min = 60.0
	debris.initial_velocity_max = 150.0
	debris.scale_amount_min = 1.5
	debris.scale_amount_max = 3.8
	debris.color = Color(0.55, 0.48, 0.4, 0.82) if blocked else Color(0.24, 0.22, 0.22, 0.9)
	feedback.add_child(debris)
	debris.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(feedback):
			feedback.queue_free()
	)
	return feedback

func _spawn_impact_flash(blocked: bool) -> void:
	# 冲击瞬间给整个洞体一次暖色曝光，让背景与挡板同时被“照亮”；随后快速恢复黑暗。
	if _flash == null:
		return
	_flash.visible = true
	_flash.color = Color("#ffc36a") if blocked else Color("#ff9a45")
	_flash.modulate.a = 0.28 if blocked else 0.42
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _flash != null and _phase != Phase.WARNING:
			_flash.visible = false
	)

func _make_radial_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.82, 0.55, 0.78),
		Color(1.0, 0.3, 0.05, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
