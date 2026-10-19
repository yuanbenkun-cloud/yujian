extends "res://scripts/npc/interactable.gd"

## 岩壁（第二关）：E 开始移动条锻造；火/水覆盖与三道裂纹反馈结果。

var _rounds_shown: int = 0

func on_interact(_player: Node) -> void:
	var fs := get_tree().current_scene.find_child("ForgeSequence", true, false)
	if fs != null:
		fs.call("open_station", 2)

func mark_heat() -> void:
	_tint_wall(Color(1.0, 0.68, 0.43, 1.0), 0.16)

func mark_quench() -> void:
	_tint_wall(Color(0.58, 0.82, 1.0, 1.0), 0.10)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_tint_wall(Color(0.92, 0.82, 0.72, 1.0), 0.24))

func crack() -> void:
	_rounds_shown += 1
	var crack_line := get_node_or_null("Crack%d" % _rounds_shown)
	if crack_line != null:
		crack_line.visible = true
		crack_line.modulate.a = 0.0
		create_tween().tween_property(crack_line, "modulate:a", 1.0, 0.18)
	_tint_wall(Color.WHITE, 0.16)
	_spawn_chisel_sparks()

func _tint_wall(color: Color, duration: float) -> void:
	var wall := get_node_or_null("WallVisual") as CanvasItem
	if wall == null:
		return
	create_tween().tween_property(wall, "self_modulate", color, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_chisel_sparks() -> void:
	var sparks := CPUParticles2D.new()
	sparks.name = "ChiselSparks"
	sparks.position = Vector2(-8 + _rounds_shown * 12, -54)
	sparks.z_index = 25
	sparks.amount = 12
	sparks.lifetime = 0.48
	sparks.one_shot = true
	sparks.explosiveness = 0.96
	sparks.direction = Vector2(1, -1)
	sparks.spread = 64.0
	sparks.gravity = Vector2(0, 110)
	sparks.initial_velocity_min = 36.0
	sparks.initial_velocity_max = 92.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.35
	sparks.color = Color(1.0, 0.72, 0.28, 0.95)
	sparks.texture = _make_spark_texture()
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.7).timeout.connect(sparks.queue_free)

func _make_spark_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 4
	texture.height = 4
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func celebrate_breakthrough() -> void:
	set_prompt_visible(false)
	# 裂纹是独立的 Line2D，不能只淡出 WallVisual，否则墙消失后会留下发光条纹。
	for crack_line in find_children("Crack*", "Line2D", false, false):
		(crack_line as Line2D).visible = false
	_tint_wall(Color.WHITE, 0.08)
	for shape in find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).set_deferred("disabled", true)
	var scene := get_tree().current_scene
	if scene != null:
		var blocking_wall := scene.find_child("di_erguan_yanbi_qiangti", true, false)
		if blocking_wall != null:
			for shape in blocking_wall.find_children("*", "CollisionShape2D", true, false):
				(shape as CollisionShape2D).set_deferred("disabled", true)
	var wall := get_node_or_null("WallVisual") as CanvasItem
	if wall != null:
		var tween := create_tween()
		tween.tween_property(wall, "scale", Vector2(0.54, 0.46), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(wall, "position:y", 22.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(wall, "modulate:a", 0.0, 0.55)
	_spawn_break_dust()

func _spawn_break_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.name = "BreakthroughDust"
	dust.position = Vector2(0, -42)
	dust.amount = 28
	dust.lifetime = 1.15
	dust.one_shot = true
	dust.explosiveness = 0.92
	dust.direction = Vector2(0, -1)
	dust.spread = 78.0
	dust.gravity = Vector2(0, 86)
	dust.initial_velocity_min = 42.0
	dust.initial_velocity_max = 105.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 5.5
	dust.color = Color(0.68, 0.58, 0.45, 0.82)
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)

