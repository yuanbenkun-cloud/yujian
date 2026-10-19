class_name PlayerAnimator
extends Node

## 角色表现层：方向、起跳/落地压缩回弹与交互反馈。
## AnimationPlayer 只驱动 VisualPivot，不接触碰撞体与物理位置。

var _face: ColorRect = null
var _hero: Node2D = null
var _player: CharacterBody2D = null
var _feedback: AnimationPlayer = null
var _was_on_floor := false
var _trail_cooldown := 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_face = _player.get_node_or_null("FaceRect") as ColorRect
	_hero = _player.get_node_or_null("VisualPivot/zhujue_donghua") as Node2D
	if _hero == null:
		_hero = _player.get_node_or_null("KenneyHero") as Node2D
	_feedback = _player.get_node_or_null("FeedbackAnimationPlayer") as AnimationPlayer
	_was_on_floor = _player.is_on_floor()

func _physics_process(delta: float) -> void:
	if _player == null or _feedback == null:
		return
	var on_floor := _player.is_on_floor()
	if _was_on_floor and not on_floor and _player.velocity.y < 0.0:
		_feedback.play("jump_takeoff")
		_spawn_dust(false)
	elif not _was_on_floor and on_floor:
		_feedback.play("land")
		_spawn_dust(true)
		_spawn_landing_ring()
	_trail_cooldown -= delta
	if not on_floor and _trail_cooldown <= 0.0 and absf(_player.velocity.y) > 45.0:
		_trail_cooldown = 0.065
		_spawn_air_trail()
	_was_on_floor = on_floor

func set_look(dir: int) -> void:
	if _hero is AnimatedSprite2D:
		(_hero as AnimatedSprite2D).flip_h = dir < 0
		return
	if _hero is Sprite2D:
		(_hero as Sprite2D).flip_h = dir < 0
		return
	if _face != null:
		_face.position.x = 10.0 if dir > 0 else -14.0

func play_interact_feedback() -> void:
	if _feedback != null:
		_feedback.play("interact")

func _spawn_dust(landing: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dust := CPUParticles2D.new()
	dust.name = "LandingDust" if landing else "TakeoffDust"
	dust.global_position = _player.global_position + Vector2(0, -1)
	dust.z_index = 24
	dust.amount = 12 if landing else 7
	dust.lifetime = 0.52 if landing else 0.38
	dust.one_shot = true
	dust.explosiveness = 0.96
	dust.direction = Vector2(0, -1)
	dust.spread = 72.0 if landing else 48.0
	dust.gravity = Vector2(0, 92)
	dust.initial_velocity_min = 24.0 if landing else 18.0
	dust.initial_velocity_max = 68.0 if landing else 44.0
	dust.scale_amount_min = 0.55
	dust.scale_amount_max = 1.65 if landing else 1.2
	dust.color = Color(0.76, 0.69, 0.56, 0.52)
	dust.texture = _make_particle_texture()
	scene.add_child(dust)
	dust.emitting = true
	get_tree().create_timer(dust.lifetime + 0.15).timeout.connect(dust.queue_free)

func _spawn_landing_ring() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ring := Line2D.new()
	ring.name = "LandingRing"
	ring.global_position = _player.global_position + Vector2(0, -1)
	ring.points = PackedVector2Array([Vector2(-10, 0), Vector2(-4, -1), Vector2(4, -1), Vector2(10, 0)])
	ring.width = 2.6
	ring.default_color = Color(0.92, 0.79, 0.57, 0.76)
	ring.z_index = 23
	scene.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.2, 1.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ring.queue_free)

func _spawn_air_trail() -> void:
	if _hero == null or not (_hero is AnimatedSprite2D):
		return
	var animated := _hero as AnimatedSprite2D
	if animated.sprite_frames == null:
		return
	var frame_texture := animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	if frame_texture == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "HeroTrailGhost"
	ghost.texture = frame_texture
	ghost.centered = animated.centered
	ghost.flip_h = animated.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index = 18
	ghost.modulate = Color(0.48, 0.72, 0.92, 0.22)
	scene.add_child(ghost)
	ghost.global_transform = animated.global_transform
	var target_scale := ghost.scale * 0.94
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "scale", target_scale, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.19)
	tween.parallel().tween_property(ghost, "position:y", ghost.position.y + 3.0, 0.19)
	tween.tween_callback(ghost.queue_free)

func _make_particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.78), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
