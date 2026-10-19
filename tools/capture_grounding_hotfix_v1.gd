extends SceneTree
## 四处热修后的实机截图，只用于视觉验收。

func _init() -> void:
	call_deferred("_run")

func _hide_intro() -> void:
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false

func _capture(file_name: String) -> void:
	for _i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://Build/Game/" + file_name))

func _show_level(path: String, player_position: Vector2, output: String) -> void:
	change_scene_to_file(path)
	await process_frame
	await process_frame
	_hide_intro()
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	if player != null:
		player.global_position = player_position
		player.velocity = Vector2.ZERO
	await _capture(output)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Build/Game"))
	await _show_level("res://scenes/guanqia/01_hongyadong.tscn", Vector2(1280, 200), "codex_hotfix_level1.png")
	await _show_level("res://scenes/guanqia/03_zhongshan.tscn", Vector2(650, 200), "codex_hotfix_level3.png")
	await _show_level("res://scenes/guanqia/04_fangdong.tscn", Vector2(315, 200), "codex_hotfix_level4.png")
	quit()
