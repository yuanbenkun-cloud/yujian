extends SceneTree
## 新动态背景与第四关爆炸照明实机审查。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare(scene_path: String, x: float) -> Node:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(x, 252)
	player.velocity = Vector2.ZERO
	for _i in range(35):
		await process_frame
	return current_scene

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))
	await _prepare("res://scenes/guanqia/01_hongyadong.tscn", 1450.0)
	await _capture("res://Build/Game/codex_level1_lantern_flock_v1.png")

	await _prepare("res://scenes/guanqia/02_ciqikou.tscn", 1650.0)
	await _capture("res://Build/Game/codex_level2_smoke_visible_v1.png")

	await _prepare("res://scenes/guanqia/03_zhongshan.tscn", 1400.0)
	await _capture("res://Build/Game/codex_level3_waterfront_no_boat_v1.png")

	var level4 := await _prepare("res://scenes/guanqia/04_fangdong.tscn", 1680.0)
	await _capture("res://Build/Game/codex_level4_rats_visible_v1.png")
	var bomb := level4.find_child("BombWarning", true, false)
	bomb.call("_spawn_explosion", Vector2(1760, 226), false)
	bomb.call("_spawn_impact_flash", false)
	await process_frame
	await _capture("res://Build/Game/codex_level4_rats_explosion_light_v1.png")
	quit()
