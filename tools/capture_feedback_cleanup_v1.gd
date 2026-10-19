extends SceneTree
## 本轮反馈：第一关画面收敛、第二关无矩形叠色、第三关去旧灯笼、第四关新群众。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare(scene_path: String, player_x: float) -> Node:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(player_x, 240)
	player.velocity = Vector2.ZERO
	for _i in range(30):
		await process_frame
	return current_scene

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))
	await _prepare("res://scenes/guanqia/01_hongyadong.tscn", 1450.0)
	await _capture("res://Build/Game/codex_level1_clean_night_v2.png")

	var level2 := await _prepare("res://scenes/guanqia/02_ciqikou.tscn", 2400.0)
	var wall := level2.find_child("di_erguan_yanbi", true, false)
	wall.call("mark_heat")
	for _i in range(14):
		await process_frame
	await _capture("res://Build/Game/codex_level2_wall_heat_no_rectangle_v2.png")

	await _prepare("res://scenes/guanqia/03_zhongshan.tscn", 980.0)
	await _capture("res://Build/Game/codex_level3_npc_idle_proportion_v3.png")

	await _prepare("res://scenes/guanqia/04_fangdong.tscn", 520.0)
	await _capture("res://Build/Game/codex_level4_wartime_crowd_proportion_v3.png")
	quit()
