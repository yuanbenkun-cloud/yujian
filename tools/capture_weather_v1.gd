extends SceneTree
## 五关天气、岩壁去橙边与移动条命中反馈的视觉回归截图。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare(scene_path: String, x: float, y := 240.0) -> Node:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	for _i in range(30):
		await process_frame
	return current_scene

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))

	await _prepare("res://scenes/guanqia/01_hongyadong.tscn", 1450.0)
	await _capture("res://Build/Game/codex_weather_level1_night_drizzle_v1.png")

	var level2 := await _prepare("res://scenes/guanqia/02_ciqikou.tscn", 2400.0)
	await _capture("res://Build/Game/codex_weather_level2_wall_clean_v1.png")
	var forge := level2.find_child("ForgeSequence", true, false)
	forge.set("current_step", 2)
	forge.call("open_station", 2)
	forge.set("_cursor_value", forge.get("_target_center"))
	forge.call("_layout_cursor")
	forge.call("_judge")
	await process_frame
	await process_frame
	await _capture("res://Build/Game/codex_timing_bar_impact_v1.png")

	await _prepare("res://scenes/guanqia/03_zhongshan.tscn", 1400.0)
	await _capture("res://Build/Game/codex_weather_level3_drizzle_v1.png")

	await _prepare("res://scenes/guanqia/04_fangdong.tscn", 1680.0)
	await _capture("res://Build/Game/codex_weather_level4_cave_dust_v1.png")

	await _prepare("res://scenes/guanqia/05_hongyadong_return.tscn", 1750.0)
	await _capture("res://Build/Game/codex_weather_level5_morning_light_v1.png")
	quit()
