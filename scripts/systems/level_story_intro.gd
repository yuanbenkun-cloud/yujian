extends Node
## 第四关目标提示：章节过场结束后再显示，避免与全局叙事导演重叠。

func _ready() -> void:
	call_deferred("_play_intro")

func _play_intro() -> void:
	# 全关卡引导已统一接管，避免两块操作说明同时盖住画面。
	if get_node_or_null("/root/QuestGuide") != null:
		return
	var tree := get_tree()
	if tree == null:
		return
	# 本节点的父级就是第四关根节点；不要在切换中读取可能仍指向旧关的 current_scene。
	var cur := get_parent()
	var director := get_node_or_null("/root/StoryDirector")
	while is_instance_valid(director) and bool(director.get("busy")):
		if not is_inside_tree() or not is_instance_valid(cur):
			return
		tree = get_tree()
		if tree == null:
			return
		await tree.process_frame
	if not is_inside_tree() or not is_instance_valid(cur):
		return
	tree = get_tree()
	if tree == null or tree.current_scene != cur:
		return
	var layer := CanvasLayer.new()
	layer.name = "StoryIntroLayer"
	layer.layer = 28
	cur.add_child(layer)
	var panel := ColorRect.new()
	panel.name = "StoryIntroPanel"
	panel.color = Color("#090a0dcc")
	panel.position = Vector2(110, 22)
	panel.size = Vector2(420, 72)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var title := Label.new()
	title.text = "眼前的路 · 先把大家带出去"
	title.position = Vector2(18, 10)
	title.size = Vector2(384, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#e8b04b"))
	panel.add_child(title)
	var story := Label.new()
	story.text = "沿着挡板往前走。碰见落单的人，就叫上他们一起走。"
	story.position = Vector2(18, 36)
	story.size = Vector2(384, 22)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 11)
	story.add_theme_color_override("font_color", Color("#e6dfd2"))
	panel.add_child(story)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.7)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished
	if is_instance_valid(layer):
		layer.queue_free()
