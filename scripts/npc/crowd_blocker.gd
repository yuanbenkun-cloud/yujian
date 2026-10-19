extends AnimatableBody2D
## 第一关移动人流：平时在街面缓慢穿行，追逐中预警后逆向切入玩家路线。

enum State { STROLL, WARN, INTERCEPT, HOLD, LEAVE, PASSED }

const PEOPLE := [
	"res://assets/production/npc/crowd_walk/modern/modern-01.png",
	"res://assets/production/npc/crowd_walk/modern/modern-02.png",
	"res://assets/production/npc/crowd_walk/modern/modern-03.png",
	"res://assets/production/npc/crowd_walk/modern/modern-04.png",
	"res://assets/production/npc/crowd_walk/modern/modern-05.png",
	"res://assets/production/npc/crowd_walk/modern/modern-06.png",
]
const WALK_FRAME_SIZE := 128
const WALK_FRAME_COUNT := 6
const WALK_COLUMNS := 3
const CROWD_VISIBLE_HEIGHT := 70.0
const STREET_SURFACE_Y := 246.0

@export var trigger_distance := 190.0
@export var warning_time := 0.48
@export var block_time := 0.92
@export var stroll_span := 24.0
@export var stroll_speed := 0.58
@export var intercept_distance := 74.0
@export var intercept_speed := 62.0
@export var chaser_slow_radius := 66.0

var _state: int = State.STROLL
var _player: Node2D
var _manager: Node
var _origin_x := 0.0
var _timer := 0.0
var _phase := 0.0
var _warning: Label
var _visuals: Array[AnimatedSprite2D] = []
var _visual_base_y: Array[float] = []
var _last_motion_x := 0.0
var _walk_grace := 0.0

func _ready() -> void:
	_origin_x = position.x
	_last_motion_x = position.x
	_phase = float(_crowd_index()) * 1.37
	var cur := get_tree().current_scene
	if cur == null:
		cur = get_parent()
	_player = cur.find_child("zhujue", true, false) as Node2D
	_manager = cur.find_child("ChaseManager", true, false)
	_build_crowd_model()
	_build_warning()
	_update_facing(-1)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var frame_start_x := position.x
	match _state:
		State.STROLL:
			_phase += delta * stroll_speed
			var previous_x := position.x
			position.x = _origin_x + sin(_phase) * stroll_span
			_update_facing(1 if position.x > previous_x else -1)
			if _manager != null and bool(_manager.get("chasing")) and global_position.x - _player.global_position.x < trigger_distance:
				_state = State.WARN
				_timer = warning_time
				_warning.visible = true
		State.WARN:
			_timer -= delta
			_warning.modulate.a = 0.5 + absf(sin(Time.get_ticks_msec() * 0.015)) * 0.5
			if _timer <= 0.0:
				_state = State.INTERCEPT
				_warning.visible = false
		State.INTERCEPT:
			_update_facing(-1)
			position.x = move_toward(position.x, _origin_x - intercept_distance, intercept_speed * delta)
			if is_equal_approx(position.x, _origin_x - intercept_distance):
				_state = State.HOLD
				_timer = block_time
		State.HOLD:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.LEAVE
		State.LEAVE:
			_update_facing(-1)
			position.x = move_toward(position.x, _origin_x - intercept_distance - 54.0, intercept_speed * 1.15 * delta)
			if is_equal_approx(position.x, _origin_x - intercept_distance - 54.0):
				_state = State.PASSED
				_phase = PI
		State.PASSED:
			_phase += delta * stroll_speed * 0.72
			var previous_x := position.x
			position.x = _origin_x - intercept_distance - 54.0 + sin(_phase) * 14.0
			_update_facing(1 if position.x > previous_x else -1)
	# AnimatableBody2D 的 sync_to_physics 会延迟应用位置；同帧写入后读取
	# 得到的仍可能是旧位置，原来的检测因此一直把移动角色切回 idle。
	# 比较两个物理帧的已提交位置，并给转向留一点连续步态时间。
	if absf(frame_start_x - _last_motion_x) > 0.004:
		_walk_grace = 0.18
	else:
		_walk_grace = maxf(0.0, _walk_grace - delta)
	_last_motion_x = frame_start_x
	_set_walking(_walk_grace > 0.0)

func _build_crowd_model() -> void:
	for child in get_children():
		if child is Sprite2D:
			(child as Sprite2D).visible = false
	var offsets := [-50.0, -25.0, 0.0, 25.0, 50.0]
	var seed := _crowd_index()
	# 每股人群的根节点会随碰撞高度而变化，不能使用固定的局部脚线。
	# 直接反算洪崖洞街面的世界坐标，保证所有人的鞋底都落在 y=240。
	var local_foot_y := STREET_SURFACE_Y - global_position.y
	for i in range(5):
		var texture: Texture2D = load(PEOPLE[(seed + i) % PEOPLE.size()])
		if texture == null:
			continue
		var actor := AnimatedSprite2D.new()
		actor.name = "CrowdActor%d" % (i + 1)
		actor.sprite_frames = _make_walk_frames(texture)
		actor.centered = true
		actor.z_index = 20 + i
		actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var visible_height := _visible_height(texture)
		var bottom_padding := _bottom_padding(texture)
		var display_scale := CROWD_VISIBLE_HEIGHT / float(maxi(visible_height, 1))
		actor.scale = Vector2.ONE * display_scale
		actor.position = Vector2(offsets[i], local_foot_y - (float(WALK_FRAME_SIZE) * 0.5 - float(bottom_padding)) * display_scale)
		actor.set_meta("visible_height_world", CROWD_VISIBLE_HEIGHT)
		actor.set_meta("local_visible_bottom_y", local_foot_y)
		actor.set_meta("grounded_visible_bottom_y", STREET_SURFACE_Y)
		add_child(actor)
		actor.play("walk")
		_visuals.append(actor)
		_visual_base_y.append(actor.position.y)
		_add_shadow(Vector2(offsets[i], local_foot_y), i)

func _make_walk_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.0)
	frames.set_animation_loop("idle", true)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 4.5)
	frames.set_animation_loop("walk", true)
	for i in range(WALK_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(float(i % WALK_COLUMNS) * WALK_FRAME_SIZE, float(i / WALK_COLUMNS) * WALK_FRAME_SIZE, WALK_FRAME_SIZE, WALK_FRAME_SIZE)
		frames.add_frame("walk", frame)
		if i == 0:
			frames.add_frame("idle", frame)
	return frames

func _set_walking(moving: bool) -> void:
	var animation := &"walk" if moving else &"idle"
	for actor in _visuals:
		if actor.animation != animation:
			actor.play(animation)

func _visible_height(texture: Texture2D) -> int:
	var image := texture.get_image()
	var top := WALK_FRAME_SIZE
	var bottom := -1
	for y in range(WALK_FRAME_SIZE):
		for x in range(WALK_FRAME_SIZE):
			if image.get_pixel(x, y).a >= 0.12:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return WALK_FRAME_SIZE if bottom < top else bottom - top + 1

func _bottom_padding(texture: Texture2D) -> int:
	var image := texture.get_image()
	for y in range(WALK_FRAME_SIZE - 1, -1, -1):
		for x in range(WALK_FRAME_SIZE):
			if image.get_pixel(x, y).a >= 0.12:
				return WALK_FRAME_SIZE - 1 - y
	return 0

func _build_warning() -> void:
	_warning = Label.new()
	_warning.name = "FlowWarning"
	_warning.text = "人流!"
	_warning.position = Vector2(-23, -51)
	_warning.size = Vector2(46, 18)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 10)
	_warning.add_theme_color_override("font_color", Color("#fff0bd"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#8f342f")
	box.border_color = Color("#ffd27b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	_warning.add_theme_stylebox_override("normal", box)
	_warning.visible = false
	_warning.z_index = 30
	add_child(_warning)

func _add_shadow(at: Vector2, index: int) -> void:
	var shadow := Polygon2D.new()
	shadow.name = "CrowdShadow%d" % index
	shadow.position = at
	shadow.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(-7, -2), Vector2(7, -2), Vector2(10, 0), Vector2(7, 2), Vector2(-7, 2)])
	shadow.color = Color(0.01, 0.015, 0.025, 0.3)
	shadow.z_index = 19
	add_child(shadow)

func _update_facing(direction: int) -> void:
	for actor in _visuals:
		# 新帧表原始朝右，向左时才翻转。
		actor.flip_h = direction < 0

func _crowd_index() -> int:
	var suffix := str(name).get_slice("_", str(name).count("_"))
	return maxi(int(suffix), 1)

func get_state_name() -> String:
	return State.keys()[_state]

func slows_chaser_at(world_position: Vector2) -> bool:
	## 五个人形成的拥挤区域；阿姨穿入时被人流拖慢，离开边界立即恢复追速。
	return absf(world_position.x - global_position.x) <= chaser_slow_radius \
		and absf(world_position.y - global_position.y) <= 62.0
