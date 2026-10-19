extends SceneTree
## 第二、三、五关流程延长后的实机视觉审查。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare_scene(scene_path: String, player_x: float) -> CharacterBody2D:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(player_x, 252.0)
	player.velocity = Vector2.ZERO
	for _i in range(24):
		await process_frame
	return player

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))

	var player := await _prepare_scene("res://scenes/guanqia/02_ciqikou.tscn", 1040.0)
	await _capture("res://Build/Game/codex_level2_heat_station_v2.png")
	player.global_position = Vector2(1710.0, 252.0)
	for _i in range(18): await process_frame
	await _capture("res://Build/Game/codex_level2_quench_station_v2.png")
	player.global_position = Vector2(2380.0, 252.0)
	for _i in range(18): await process_frame
	await _capture("res://Build/Game/codex_level2_chisel_wall_v2.png")

	player = await _prepare_scene("res://scenes/guanqia/03_zhongshan.tscn", 1420.0)
	var trade := current_scene.find_child("ChoiceSystem", true, false)
	trade.call("advance_stage", 1)
	for _i in range(4):
		await process_frame
	await _capture("res://Build/Game/codex_level3_extended_route_v1.png")

	player = await _prepare_scene("res://scenes/guanqia/05_hongyadong_return.tscn", 1180.0)
	await _capture("res://Build/Game/codex_level5_old_wall_v1.png")
	player.global_position = Vector2(2760.0, 252.0)
	player.velocity = Vector2.ZERO
	for _i in range(10):
		await process_frame
	await _capture("res://Build/Game/codex_level5_city_lights_v1.png")
	quit()
