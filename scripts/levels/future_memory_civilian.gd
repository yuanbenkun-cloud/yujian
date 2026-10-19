extends Node2D

## 历史记忆中的未来市民。被找到前是轻微闪烁的失真人影，找到后加入队伍。

const FRAME_SIZE := 128
const FRAME_COUNT := 6
const COLUMNS := 3
const TARGET_HEIGHT := 70.0

var player: CharacterBody2D
var follower_index := 0
var recruited := false
var waiting: bool = false
var _anim: AnimatedSprite2D
var _time := 0.0
var ending_mode := ""
const CAST := ["aming", "laozhou", "refugee"]

func setup(index: int, target: CharacterBody2D) -> void:
	follower_index = index
	player = target

func reset_memory() -> void:
	recruited = false
	waiting = false
	global_position = get_meta("origin", global_position)
	modulate.a = 1.0
	if _anim != null:
		_anim.play("idle")

func _ready() -> void:
	z_index = 20
	_build_animation()

func _process(delta: float) -> void:
	_time += delta
	if player == null:
		return
	if _anim != null and _anim.material is ShaderMaterial:
		(_anim.material as ShaderMaterial).set_shader_parameter("memory_amount", 1.0 if bool(get_parent().get("history_mode")) else 0.0)
	if ending_mode != "":
		if ending_mode == "living":
			position.x += (17.0 + follower_index * 2.0) * delta
			if position.x > 3220:
				position.x = 2750.0
			_anim.flip_h = false
			_anim.play("walk")
		else:
			_anim.play("idle")
		return
	var level := get_parent()
	visible = recruited or bool(level.get("history_mode"))
	if not recruited:
		modulate.a = 0.98 + sin(_time * 3.0 + float(follower_index)) * 0.02
		if global_position.distance_to(player.global_position) < 68.0:
			if level != null and level.has_method("can_recruit_civilian") and not bool(level.call("can_recruit_civilian")):
				return
			recruited = true
			modulate.a = 1.0
			if level != null and level.has_method("recruit_civilian"):
				level.call("recruit_civilian", self)
		return
	if waiting:
		_anim.play("idle")
		return
	var target_x := player.global_position.x - 38.0 * float(follower_index + 1) * float(player.look_dir)
	var old_x := global_position.x
	global_position.x = move_toward(global_position.x, target_x, 138.0 * delta)
	global_position.y = move_toward(global_position.y, 282.0, 90.0 * delta)
	var moving := absf(global_position.x - old_x) > 0.05
	if _anim != null:
		if moving:
			_anim.flip_h = global_position.x < old_x
		_anim.play("walk" if moving else "idle")

func _build_animation() -> void:
	var directory := "res://assets/production/npc/cast_v3/%s/" % CAST[follower_index % CAST.size()]
	var path := directory + "sheet-transparent.png"
	var sheet := load(path) as Texture2D
	var idle := load(directory + "idle-transparent.png") as Texture2D
	if sheet == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.0)
	frames.set_animation_loop("idle", true)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5.5)
	frames.set_animation_loop("walk", true)
	frames.add_frame("idle", idle)
	for i in range(FRAME_COUNT):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(float(i % COLUMNS) * FRAME_SIZE, float(i / COLUMNS) * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame("walk", at)
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.centered = true
	var bounds := _first_frame_bounds(idle)
	var s := TARGET_HEIGHT / float(maxi(bounds.size.y, 1))
	_anim.scale = Vector2.ONE * s
	var bottom_padding := FRAME_SIZE - (bounds.position.y + bounds.size.y)
	_anim.position.y = -float(FRAME_SIZE) * s * 0.5 + float(bottom_padding) * s + 6.0
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/solid_memory.gdshader")
	material.set_shader_parameter("memory_amount", 0.0)
	_anim.material = material
	_anim.set_meta("visible_height_world", TARGET_HEIGHT)
	_anim.set_meta("ground_embed_world", 6.0)
	add_child(_anim)
	_anim.play("idle")

func _first_frame_bounds(sheet: Texture2D) -> Rect2i:
	var image := sheet.get_image()
	if image == null or image.is_empty():
		return Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE)
	var min_x := FRAME_SIZE
	var min_y := FRAME_SIZE
	var max_x := -1
	var max_y := -1
	for y in range(FRAME_SIZE):
		for x in range(FRAME_SIZE):
			if image.get_pixel(x, y).a >= 0.12:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

