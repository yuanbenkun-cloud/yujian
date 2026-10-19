extends AnimatedSprite2D

signal foot_contact(frame_index: int)

## 陈默正式角色动画。每组动作由独立多行原图生成、严格 QC 后拆成 128×128 透明帧；
## Godot 只读取单帧文件，避免依赖不规则旧图集的手工切片尺寸。

const ANIMATIONS := {
	"idle": {
		"dir": "res://assets/production/hero/v2/idle",
		"prefix": "idle",
		"count": 6,
		"fps": 6.0,
		"loop": true,
		"origin_y": 125.0,
	},
	"walk": {
		"dir": "res://assets/production/hero/v3/jog",
		"prefix": "jog",
		"count": 8,
		"fps": 12.0,
		"loop": true,
		"origin_y": 125.0,
	},
	"jump": {
		"dir": "res://assets/production/hero/jump",
		"prefix": "jump",
		"count": 4,
		"fps": 5.0,
		"loop": false,
		"origin_y": 104.0,
	},
	"interact": {
		"dir": "res://assets/production/hero/v2/interact",
		"prefix": "interact",
		"count": 6,
		"fps": 12.0,
		"loop": false,
		"origin_y": 125.0,
	},
}

const FRAME_SIZE := 128.0
# 待机帧真实透明像素高度为 88px；旧值 102 把透明留白误算进角色，
# 导致标称 70px 实际只有约 60px。
const REFERENCE_SUBJECT_HEIGHT := 88.0
const TARGET_HEIGHT := 70.0
const DISPLAY_SCALE := TARGET_HEIGHT / REFERENCE_SUBJECT_HEIGHT

var _current_animation := "idle"
var _interacting := 0.0
var _last_contact_frame: int = -1

func _ready() -> void:
	centered = false
	material = null
	set_meta("visible_height_world", TARGET_HEIGHT)
	set_meta("ground_embed_world", 6.0)
	_add_ground_shadow()
	_build_frames()
	frame_changed.connect(_on_locomotion_frame_changed)
	_apply_animation("idle")

func _on_locomotion_frame_changed() -> void:
	if _current_animation != "walk" or frame not in [0, 4] or frame == _last_contact_frame:
		return
	var player := get_parent().get_parent() as CharacterBody2D
	if player == null or player.frozen or not player.is_on_floor() or absf(player.velocity.x) <= 12.0:
		return
	_last_contact_frame = frame
	foot_contact.emit(frame)
	# 接触帧驱动脚步声，变速、停步或撞墙时不再独立按计时器播放。
	player.call("_play_audio", "step", randf_range(0.92, 1.08), -8.0)

func _add_ground_shadow() -> void:
	var actor := get_parent().get_parent() as Node2D
	if actor == null or actor.has_node("GroundShadow"):
		return
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(-10, -2), Vector2(-5, -3), Vector2(5, -3),
		Vector2(10, -2), Vector2(13, 0), Vector2(10, 2), Vector2(5, 3),
		Vector2(-5, 3), Vector2(-10, 2),
	])
	shadow.color = Color(0.015, 0.02, 0.03, 0.28)
	shadow.z_index = 19
	actor.add_child.call_deferred(shadow)

func _build_frames() -> void:
	var frames := SpriteFrames.new()
	for animation_name: String in ANIMATIONS:
		var config: Dictionary = ANIMATIONS[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(config["fps"]))
		frames.set_animation_loop(animation_name, bool(config["loop"]))
		for frame_index in range(1, int(config["count"]) + 1):
			var source_index := frame_index + int(config.get("source_first", 1)) - 1
			var frame_path := "%s/%s-%d.png" % [config["dir"], config["prefix"], source_index]
			var texture: Texture2D = load(frame_path)
			if texture != null:
				frames.add_frame(animation_name, texture)
	sprite_frames = frames

func _physics_process(delta: float) -> void:
	var player := get_parent().get_parent() as CharacterBody2D
	if player == null:
		return
	# 过场冻结时尚未运行贴地物理，is_on_floor 可能为 false；保持站立，
	# 避免第六关序章和结局把静止主角误显示成空中动作。
	if player.frozen:
		_interacting = 0.0
		_apply_animation("idle")
		return
	var moving := absf(player.velocity.x) > 12.0
	flip_h = player.look_dir < 0
	var on_floor := player.is_on_floor()
	if _interacting > 0.0:
		_interacting -= delta
		if moving or not on_floor:
			_interacting = 0.0
		elif _interacting > 0.0:
			return
	var target := "idle"
	if not on_floor:
		target = "jump"
	elif moving:
		target = "walk"
	if target != _current_animation:
		_apply_animation(target)
	if target == "walk":
		speed_scale = clampf(absf(player.velocity.x) / 130.0, 0.45, 1.8)

func trigger_interact() -> void:
	_interacting = float(ANIMATIONS["interact"]["count"]) / float(ANIMATIONS["interact"]["fps"])
	_apply_animation("interact")
	var feedback := get_parent().get_parent().get_node_or_null("FeedbackAnimationPlayer")
	if feedback != null:
		feedback.play("interact")

func _apply_animation(animation_name: String) -> void:
	if not ANIMATIONS.has(animation_name):
		return
	_current_animation = animation_name
	_last_contact_frame = -1
	speed_scale = 1.0
	var config: Dictionary = ANIMATIONS[animation_name]
	scale = Vector2.ONE * DISPLAY_SCALE
	# 鞋底压入地面 6px，让角色真正站进路面而非贴在背景边缘上。
	position = Vector2(-FRAME_SIZE * 0.5 * DISPLAY_SCALE, -float(config["origin_y"]) * DISPLAY_SCALE + 6.0)
	if sprite_frames != null and sprite_frames.has_animation(animation_name):
		play(animation_name)
		if animation_name == "walk":
			_on_locomotion_frame_changed()
