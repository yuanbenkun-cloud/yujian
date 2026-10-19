extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _prepare(scene_path: String, player_position: Vector2) -> Node:
	change_scene_to_file(scene_path)
	await process_frame
	await process_frame
	paused = false
	var intro := current_scene.find_child("StoryIntroLayer", true, false)
	if intro != null:
		intro.visible = false
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	if player != null:
		player.global_position = player_position
		player.velocity = Vector2.ZERO
	for _frame in range(24):
		await process_frame
	return current_scene

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://codex-captures"))
	await _prepare("res://scenes/guanqia/06_future_chongqing.tscn", Vector2(100, 260))
	await _capture("user://codex-captures/codex_future_level_v1.png")

	await _prepare("res://scenes/guanqia/01_hongyadong.tscn", Vector2(150, 240))
	var scale_player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	var scale_npc := current_scene.find_child("chuandanayi", true, false) as Node2D
	var scale_walker := current_scene.find_child("DistantWalker01", true, false) as Node2D
	if scale_player != null:
		scale_player.global_position = Vector2(300, 240)
		scale_player.velocity = Vector2.ZERO
	if scale_npc != null:
		scale_npc.global_position = Vector2(220, 240)
	if scale_walker != null:
		scale_walker.global_position.x = 400
	for _frame in range(20):
		await process_frame
	await _capture("user://codex-captures/codex_character_scale_right_v1.png")

	var dialogue := root.get_node_or_null("DialogueSystem")
	if dialogue != null:
		dialogue.call("load_data", "res://assets/dialogue_level1.json")
		dialogue.call("start_dialogue", "flyer_lady")
	for _frame in range(16):
		await process_frame
	await _capture("user://codex-captures/codex_npc_dialogue_v2.png")

	if dialogue != null and dialogue.has_method("cancel_for_scene_change"):
		dialogue.call("cancel_for_scene_change")
	await _prepare("res://scenes/guanqia/04_fangdong.tscn", Vector2(315, 240))
	await _capture("user://codex-captures/codex_level4_grounded_v4.png")

	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.set("story_completed", true)
	change_scene_to_file("res://scenes/kaishi.tscn")
	for _frame in range(30):
		await process_frame
	await _capture("user://codex-captures/codex_future_unlock_menu_v1.png")
	quit()
