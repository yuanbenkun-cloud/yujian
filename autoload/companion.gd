extends Node
## 渝灯在主角前方引路；第四关提供洞内照明，不占用 E 或鼠标输入。

const AVATAR_CENTER := Vector2(36, 38) * 0.46
const LEAD_DISTANCE := 56.0
const TURN_DURATION := 0.7
const TURN_ARC_HEIGHT := 18.0

var _layer: CanvasLayer
var _root: Control
var _player: Node2D
var _scene: Node
var _visible_state: bool = false
var _time: float = 0.0
var _snap: bool = true
var _last_direction: int = 0
var _turn_elapsed: float = TURN_DURATION
var _turn_start_offset: Vector2 = Vector2.ZERO
var _cave_lighting: bool = false
var _world_light: PointLight2D
var _halo: Sprite2D
var _light_texture: GradientTexture2D

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CompanionLayer"
	_layer.layer = 18
	add_child(_layer)
	_root = Control.new()
	_root.name = "YudengCompanion"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	_layer.add_child(_root)
	_build_glow()
	var avatar: Control = preload("res://scripts/ui/companion_avatar.gd").new()
	avatar.name = "CompanionAvatar"
	avatar.scale = Vector2.ONE * 0.46
	_root.add_child(avatar)
	RenderingServer.frame_pre_draw.connect(_sync_world_light)

func _build_glow() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 0.85, 0.57, 0.6), Color(1, 0.56, 0.20, 0.16), Color(1, 0.42, 0.12, 0)])
	_light_texture = GradientTexture2D.new()
	_light_texture.gradient = gradient
	_light_texture.width = 128
	_light_texture.height = 128
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5, 0.5)
	_light_texture.fill_to = Vector2(1, 0.5)
	_halo = Sprite2D.new()
	_halo.name = "SpiritGlow"
	_halo.texture = _light_texture
	_halo.position = AVATAR_CENTER
	_halo.scale = Vector2.ONE * 0.65
	_halo.modulate = Color(1, 0.76, 0.38, 0.48)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = additive
	_halo.hide()
	_root.add_child(_halo)

func _setup_cave_light() -> void:
	if is_instance_valid(_world_light):
		_world_light.queue_free()
	_world_light = null
	_cave_lighting = is_instance_valid(_scene) and _scene.scene_file_path.ends_with("04_fangdong.tscn")
	_halo.visible = _cave_lighting
	if not _cave_lighting:
		return
	# 放在场景世界画布中，才能真正照亮洞壁和路面，而不是只照亮 UI。
	_world_light = PointLight2D.new()
	_world_light.name = "YudengPathLight"
	_world_light.texture = _light_texture
	_world_light.texture_scale = 3.5
	_world_light.color = Color("#ffc674")
	_world_light.energy = 1.6
	_world_light.shadow_enabled = false
	_scene.add_child(_world_light)

func _sync_world_light() -> void:
	if not is_instance_valid(_world_light) or not is_instance_valid(_player):
		return
	_world_light.visible = _root.visible
	_world_light.global_position = _player.get_canvas_transform().affine_inverse() * (_root.position + AVATAR_CENTER)
	_world_light.energy = 1.6 + sin(_time * 2.8) * 0.07

func _process(delta: float) -> void:
	_time += delta
	var scene: Node = get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_player = null
		_snap = true
		_last_direction = 0
		_turn_elapsed = TURN_DURATION
		_setup_cave_light()
		if is_instance_valid(scene) and scene.scene_file_path.contains("/guanqia/"):
			_player = scene.get_node_or_null("zhujue") as Node2D
	_visible_state = is_instance_valid(_player) and not guidance_blocked()
	# 普通对话时渝灯仍在洞内照路；漫画、AI与暂停菜单保持原有遮挡规则。
	if _cave_lighting and is_instance_valid(_player):
		var director := get_node_or_null("/root/StoryDirector")
		var chat := get_node_or_null("/root/YudengChat")
		_visible_state = not get_tree().paused and not (director != null and bool(director.get("busy"))) and not (chat != null and bool(chat.get("is_open")))
	_root.visible = _visible_state
	if _visible_state:
		var point: Vector2 = _player.get_global_transform_with_canvas().origin
		var direction: float = float(_player.get("look_dir"))
		_root.get_node("CompanionAvatar").call("set_facing", int(direction))
		var height := -88.0 if _cave_lighting else -112.0
		var desired: Vector2 = point + Vector2(direction * LEAD_DISTANCE - AVATAR_CENTER.x, height + sin(_time * 2.0) * 3.0)
		var bounds: Vector2 = get_viewport().get_visible_rect().size
		desired = Vector2(clampf(desired.x, 8, bounds.x - 42), clampf(desired.y, 35, bounds.y - 75))
		if _snap or _root.position.distance_to(desired) > 200:
			_root.position = desired
			_snap = false
			_turn_elapsed = TURN_DURATION
		else:
			if int(direction) != _last_direction:
				# 记录实际当前位置；快速反向时从半空接续，不重置到任一侧。
				_turn_start_offset = _root.position - point
				_turn_elapsed = 0.0
			if _turn_elapsed < TURN_DURATION:
				_turn_elapsed = minf(TURN_DURATION, _turn_elapsed + delta)
				var progress := _turn_elapsed / TURN_DURATION
				var eased := smoothstep(0.0, 1.0, progress)
				var flight_offset := _turn_start_offset.lerp(desired - point, eased)
				flight_offset.y -= sin(progress * PI) * TURN_ARC_HEIGHT
				_root.position = point + flight_offset
			else:
				_root.position = _root.position.lerp(desired, 1.0 - exp(-delta * 7.0))
		_last_direction = int(direction)
		_halo.scale = Vector2.ONE * (0.65 + sin(_time * 2.8) * 0.025)
	_sync_world_light()

func guidance_blocked() -> bool:
	if get_tree().paused: return true
	var dialogue: Node = get_node_or_null("/root/DialogueSystem")
	var director: Node = get_node_or_null("/root/StoryDirector")
	if (dialogue != null and bool(dialogue.get("active"))) or (director != null and bool(director.get("busy"))):
		return true
	if is_instance_valid(_scene) and _scene.scene_file_path.contains("06_future"):
		var story: Control = _scene.get("_story_panel") as Control
		if is_instance_valid(story) and story.visible: return true
	return is_instance_valid(_player) and bool(_player.get("frozen"))
