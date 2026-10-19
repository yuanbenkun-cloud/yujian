class_name PlayerController
extends CharacterBody2D

## 主角控制器（SPEC 6.1）：占位块人物，可走可跳可交互。

@export var move_speed: float = 130.0
@export var jump_velocity: float = -320.0
const GRAVITY: float = 700.0

var frozen: bool = false
var look_dir: int = 1
var nearby: Array[Area2D] = []
var _hit_stun: float = 0.0
var _interaction_hint: PanelContainer = null
var _interaction_hint_time: float = 0.0

@onready var _animator: Node = get_node_or_null("PlayerAnimator")
@onready var _zone: Area2D = (
	get_node_or_null("InteractZone") as Area2D
	if has_node("InteractZone")
	else get_node_or_null("zhujue_jiaohuquyu") as Area2D
)

func _ready() -> void:
	_build_interaction_hint()
	if _zone != null:
		_zone.area_entered.connect(_on_zone_entered)
		_zone.area_exited.connect(_on_zone_exited)

func _physics_process(delta: float) -> void:
	_interaction_hint_time = maxf(0.0, _interaction_hint_time - delta)
	if is_instance_valid(_interaction_hint):
		_interaction_hint.visible = _interaction_hint_time > 0.0 and not frozen
		_interaction_hint.modulate.a = minf(1.0, _interaction_hint_time / 0.4)
	if frozen:
		velocity = Vector2.ZERO
		return
	if _hit_stun > 0.0:
		_hit_stun -= delta
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		set_look_dir(1 if dir > 0 else -1)
	velocity.x = dir * move_speed
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_audio("jump", randf_range(0.96, 1.05), -7.0)
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# 场景交互使用离散事件，不依赖物理帧轮询；对话框可在更早的 _input 阶段优先消费推进键。
	if frozen or not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return
	if _try_interact():
		get_viewport().set_input_as_handled()

func _play_audio(event_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", event_name, pitch, volume_db)

func set_look_dir(dir: int) -> void:
	look_dir = dir
	if _animator != null and _animator.has_method("set_look"):
		_animator.call("set_look", dir)

func freeze(v: bool) -> void:
	frozen = v
	velocity = Vector2.ZERO

func _on_zone_entered(area: Area2D) -> void:
	var available := not area.has_method("is_interaction_available") or bool(area.call("is_interaction_available"))
	if available and area.has_method("on_interact") and not nearby.has(area):
		nearby.append(area)
		if area.has_method("set_prompt_visible"):
			area.call("set_prompt_visible", true)
		_refresh_interaction_hint()

func _on_zone_exited(area: Area2D) -> void:
	nearby.erase(area)
	if area.has_method("set_prompt_visible"):
		area.call("set_prompt_visible", false)
	_refresh_interaction_hint()

func remove_nearby_interaction(area: Area2D) -> void:
	nearby.erase(area)
	_refresh_interaction_hint()


func knock(vx: float) -> void:
	if not frozen:
		velocity.x = vx
		velocity.y = -115.0
		_hit_stun = 0.24

func _try_interact() -> bool:
	for a: Area2D in nearby.duplicate():
		if not is_instance_valid(a):
			nearby.erase(a)
			continue
		if a.has_method("is_interaction_available") and not bool(a.call("is_interaction_available")):
			nearby.erase(a)
			continue
		if a.has_method("on_interact"):
			_interaction_hint_time = 0.0
			if _interaction_hint != null:
				_interaction_hint.visible = false
			_play_audio("ui_confirm", 1.0, -5.0)
			var hero := get_node_or_null("VisualPivot/zhujue_donghua")
			if hero != null and hero.has_method("trigger_interact"):
				hero.call("trigger_interact")
			a.call("on_interact", self)
			return true
	return false

func _build_interaction_hint() -> void:
	var scene := get_parent()
	if scene == null:
		return
	var ui := scene.find_child("UI_Base", true, false)
	if ui == null:
		return
	var existing := ui.find_child("InteractionHint", false, false) as PanelContainer
	if existing != null:
		_interaction_hint = existing
		return
	_interaction_hint = PanelContainer.new()
	_interaction_hint.name = "InteractionHint"
	_interaction_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_hint.offset_left = -72
	_interaction_hint.offset_right = 72
	_interaction_hint.offset_top = -41
	_interaction_hint.offset_bottom = -12
	_interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.035, 0.06, 0.92)
	box.border_color = Color("#d5a65d")
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 3
	_interaction_hint.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "E  互动"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#f6ddb0"))
	_interaction_hint.add_child(label)
	_interaction_hint.visible = false
	ui.add_child.call_deferred(_interaction_hint)

func _refresh_interaction_hint() -> void:
	if _interaction_hint != null:
		var available := false
		for area: Area2D in nearby:
			if is_instance_valid(area) and (not area.has_method("is_interaction_available") or bool(area.call("is_interaction_available"))):
				available = true
				break
		_interaction_hint_time = 3.5 if available else 0.0
		_interaction_hint.visible = available and not frozen
