extends SceneTree
## 加长关卡、重制群众和动态背景的实机视觉审查。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _hide_intro() -> void:
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	await process_frame
	await process_frame
	_hide_intro()
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(1280, 200)
	player.velocity = Vector2.ZERO
	for _i in range(8):
		await process_frame
	await _capture("res://Build/Game/codex_level1_expanded_crowd_v1.png")
	player.global_position = Vector2(2440, 200)
	player.velocity = Vector2.ZERO
	for _i in range(8):
		await process_frame
	await _capture("res://Build/Game/codex_level1_expanded_late_v1.png")

	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	await process_frame
	await process_frame
	_hide_intro()
	player = current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(1750, 200)
	player.velocity = Vector2.ZERO
	for _i in range(8):
		await process_frame
	await _capture("res://Build/Game/codex_level4_expanded_v1.png")
	quit()
