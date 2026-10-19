extends Node2D
## 顶部挡板：拦截落在水平范围内的导弹；两次命中后损毁。

@export var half_width := 92.0
@export var durability := 2
var _panel: Node2D
var _durability_label: Label
var _impact_y := 0.0
static var _visible_bounds: Dictionary = {}

func _ready() -> void:
	_panel = get_node_or_null("BarrierVisual") as Node2D
	if _panel != null:
		# 掩体保留完整轮廓，但位于人物视觉层(20)后方，屋梁不遮头部。
		_panel.z_index = 12
	_durability_label = get_node_or_null("Durability") as Label
	_fit_grounded_shelter()
	_refresh()

func _fit_grounded_shelter() -> void:
	var sprite := get_node_or_null("BarrierVisual/GeneratedBarrier") as Sprite2D
	if sprite == null or sprite.texture == null:
		_impact_y = global_position.y + 12.0
		return
	var key := sprite.texture.resource_path
	if not _visible_bounds.has(key):
		var image := sprite.texture.get_image()
		var left := image.get_width()
		var top := image.get_height()
		var right := -1
		var bottom := -1
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a >= 0.20:
					left = mini(left, x)
					right = maxi(right, x)
					top = mini(top, y)
					bottom = maxi(bottom, y)
		_visible_bounds[key] = Rect2(left, top, right - left + 1, bottom - top + 1)
	var bounds: Rect2 = _visible_bounds[key]
	# 以真实沙袋底边落脚；可见高度至少 108px，比 70px 主角高出一个头。
	var display_scale := maxf(108.0 / bounds.size.y, half_width * 2.0 / bounds.size.x)
	sprite.scale = Vector2.ONE * display_scale
	var origin := sprite.texture.get_size() * 0.5
	sprite.global_position.y = 246.0 - (bounds.end.y - origin.y) * display_scale
	_impact_y = 246.0 - bounds.size.y * display_scale + 8.0
	half_width = bounds.size.x * display_scale * 0.42
	sprite.set_meta("grounded_visible_bottom_y", 246.0)
	sprite.set_meta("visible_top_y", _impact_y - 8.0)
	if _durability_label != null:
		_durability_label.global_position.y = _impact_y - 27.0
	var safe_zone := get_node_or_null("SafeZone") as ColorRect
	if safe_zone != null:
		safe_zone.position = Vector2(-half_width, 246.0 - global_position.y)
		safe_zone.size = Vector2(half_width * 2.0, 3.0)

func covers_x(world_x: float) -> bool:
	return durability > 0 and absf(world_x - global_position.x) <= half_width

func get_impact_y() -> float:
	return _impact_y

func absorb_hit() -> void:
	durability = maxi(0, durability - 1)
	if _panel != null:
		var base_pos := _panel.position
		var tween := create_tween()
		tween.tween_property(_panel, "position", base_pos + Vector2(3, 0), 0.05)
		tween.tween_property(_panel, "position", base_pos - Vector2(3, 0), 0.05)
		tween.tween_property(_panel, "position", base_pos, 0.05)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "shield_hit", randf_range(0.9, 1.05), -1.0)
	_refresh()

func _refresh() -> void:
	if _durability_label != null:
		_durability_label.text = "%s%s" % ["◆".repeat(durability), "◇".repeat(2 - durability)]
		_durability_label.add_theme_color_override("font_color", Color("#e8b04b") if durability > 0 else Color("#b23a48"))
	var crack_one := get_node_or_null("BarrierVisual/Crack1") as CanvasItem
	var crack_two := get_node_or_null("BarrierVisual/Crack2") as CanvasItem
	if crack_one != null:
		crack_one.visible = durability <= 1
	if crack_two != null:
		crack_two.visible = durability <= 0
	if _panel != null:
		_panel.modulate = Color(0.60, 0.46, 0.38, 1.0) if durability <= 0 else Color.WHITE
		_panel.rotation = 0.035 if durability <= 0 else 0.0
	var safe_zone := get_node_or_null("SafeZone") as CanvasItem
	if safe_zone != null:
		safe_zone.visible = durability > 0

func get_checkpoint_state() -> Dictionary:
	return {"durability": durability}

func restore_checkpoint_state(state: Dictionary) -> void:
	durability = clampi(int(state.get("durability", 2)), 0, 2)
	_refresh()
