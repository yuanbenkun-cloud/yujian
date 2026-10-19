extends SceneTree
## Capture actual moving frames on level five without activating gameplay or saves.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://preview/hero-jog-v3-oct18")
	change_scene_to_file("res://scenes/guanqia/05_hongyadong_return.tscn")
	for _frame in range(12):
		await process_frame
	var arrival := root.get_node("ChapterArrival")
	arrival.set_process(false)
	arrival.get("_root").hide()
	var guide := root.get_node("QuestGuide")
	guide.set_process(false)
	guide.get("_layer").hide()
	var player := current_scene.get_node("zhujue") as CharacterBody2D
	for node in current_scene.find_children("*", "", true, false):
		if node == player or player.is_ancestor_of(node):
			continue
		node.set_process(false)
		node.set_physics_process(false)
	player.position = Vector2(800, 240)
	player.frozen = false
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var camera := player.get_node("zhujue_shexiangji") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	var hero := player.get_node("VisualPivot/zhujue_donghua") as AnimatedSprite2D
	var seen: Dictionary = {}
	Input.action_press("move_right")
	for _frame in range(100):
		await physics_frame
		if hero.animation == &"walk" and not seen.has(hero.frame):
			seen[hero.frame] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://preview/hero-jog-v3-oct18/frame-%02d.png" % hero.frame)
			if seen.size() == 8:
				break
	Input.action_release("move_right")
	print("[CAPTURE] moving frames: ", seen.size())
	quit(0 if seen.size() == 8 else 1)
