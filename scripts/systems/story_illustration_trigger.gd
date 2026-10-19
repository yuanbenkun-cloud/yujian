extends Area2D
## 场景内叙事插画：玩家走近关键地点时，用一幅可跳过的画面先说明处境与玩法因果。

@export var illustration: Texture2D
@export var eyebrow := "磁器口 · 旧窑道"
@export var title := "石壁后，水声越来越近"
@export_multiline var caption := "热浪烤得陈默睁不开眼，岩缝里却还在往外渗水。老匠人把锤柄塞进他手里。\n‘别急着砸。先烧透，再过水，听见石头发脆了再下锤。照我说的来。’"

var _played := false
var _showing := false
var _can_close_at := 0
var _auto_close_at := 0
var _layer: CanvasLayer
var _root: Control
var _image: TextureRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if _showing and Time.get_ticks_msec() >= _auto_close_at:
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not _showing or Time.get_ticks_msec() < _can_close_at:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_close()

func _on_body_entered(body: Node) -> void:
	if _played or not body is CharacterBody2D:
		return
	if body.name != "zhujue":
		return
	_played = true
	set_deferred("monitoring", false)
	_play(body)

func _play(player: Node) -> void:
	_showing = true
	_can_close_at = Time.get_ticks_msec() + 700
	_auto_close_at = Time.get_ticks_msec() + 8200
	if player.has_method("freeze"):
		player.call("freeze", true)
	var scene := get_tree().current_scene
	if scene == null:
		_showing = false
		return
	var forge := scene.find_child("ForgeSequence", true, false)
	if forge != null and forge.has_method("set_story_paused"):
		forge.call("set_story_paused", true)
	_build_overlay()
	var reveal := create_tween()
	reveal.tween_property(_root, "modulate:a", 1.0, 0.35)
	reveal.parallel().tween_property(_image, "position:x", -20.0, 7.8).set_trans(Tween.TRANS_SINE)

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "StoryIllustrationLayer"
	_layer.layer = 64
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(_layer)
	_root = Control.new()
	_root.name = "StoryIllustration"
	_root.size = Vector2(640, 360)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	_layer.add_child(_root)

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.position = Vector2(-2, -2)
	_image.size = Vector2(664, 364)
	_image.texture = illustration
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_image)

	var shade := ColorRect.new()
	shade.position = Vector2(0, 249)
	shade.size = Vector2(640, 111)
	shade.color = Color(0.018, 0.014, 0.012, 0.90)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var accent := ColorRect.new()
	accent.position = Vector2(28, 17)
	accent.size = Vector2(4, 58)
	accent.color = Color("#e29a4f")
	shade.add_child(accent)

	var eyebrow_label := _label(Vector2(44, 10), Vector2(370, 18), 10, Color("#e5a65f"))
	eyebrow_label.text = eyebrow
	shade.add_child(eyebrow_label)
	var title_label := _label(Vector2(44, 27), Vector2(370, 28), 19, Color("#fff1db"))
	title_label.text = title
	shade.add_child(title_label)
	var caption_label := _label(Vector2(264, 14), Vector2(340, 60), 11, Color("#e7dfd5"))
	caption_label.text = caption
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_constant_override("line_spacing", 4)
	shade.add_child(caption_label)
	var hint := _label(Vector2(454, 83), Vector2(150, 16), 9, Color(0.76, 0.72, 0.67, 0.85))
	hint.text = "E / SPACE 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shade.add_child(hint)

func _label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _close() -> void:
	if not _showing:
		return
	_showing = false
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.25)
	await fade.finished
	if is_instance_valid(_layer):
		_layer.queue_free()
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player := tree.current_scene.find_child("zhujue", true, false)
	if player != null and player.has_method("freeze"):
		player.call("freeze", false)
	var forge := tree.current_scene.find_child("ForgeSequence", true, false)
	if forge != null and forge.has_method("set_story_paused"):
		forge.call("set_story_paused", false)
