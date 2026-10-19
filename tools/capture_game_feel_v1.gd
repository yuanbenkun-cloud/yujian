extends SceneTree
## 跳跃/落地与第二关工位特效的视觉回归截图。

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare(scene_path: String, x: float) -> CharacterBody2D:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(x, 240)
	player.velocity = Vector2.ZERO
	await process_frame
	return player

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))
	var player := await _prepare("res://scenes/guanqia/01_hongyadong.tscn", 1450.0)
	var animator := player.find_child("zhujue_anim_kongzhi", true, false)
	player.velocity = Vector2(115, -210)
	animator.call("_spawn_air_trail")
	animator.call("_spawn_dust", false)
	for _i in range(4): await process_frame
	await _capture("res://Build/Game/codex_jump_trail_v1.png")
	player.velocity = Vector2.ZERO
	animator.call("_spawn_dust", true)
	animator.call("_spawn_landing_ring")
	for _i in range(4): await process_frame
	await _capture("res://Build/Game/codex_landing_fx_v1.png")

	player = await _prepare("res://scenes/guanqia/02_ciqikou.tscn", 1040.0)
	var forge := current_scene.find_child("ForgeSequence", true, false)
	forge.call("open_station", 0)
	for _i in range(5):
		forge.call("_heat_tap")
	for _i in range(6): await process_frame
	await _capture("res://Build/Game/codex_forge_heat_fx_v1.png")
	forge.set("_timing", false)
	forge.call("_set_station_effect", 0, false)
	forge.set("current_step", 1)
	player.set("frozen", false)
	player.global_position = Vector2(1710, 240)
	forge.call("open_station", 1)
	forge.set("_holding", true)
	forge.set("_cursor_value", 0.64)
	forge.call("_update_quench_resistance")
	for _i in range(6): await process_frame
	await _capture("res://Build/Game/codex_forge_quench_fx_v1.png")
	quit()
