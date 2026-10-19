extends SceneTree

const OUT := "user://codex-captures"

func _init() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUT, name]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("[CAPTURE] " + path)

func _settle(frames := 30) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await _settle()
	var level := current_scene
	var player := level.get_node("zhujue") as CharacterBody2D
	await _shot("codex_future_intro_v2")
	level.call("_start_chase")
	player.global_position = Vector2(520, 282)
	await _settle(24)
	await _shot("codex_future_chase_v2")
	level.call("on_drone_caught", Vector2(790, 150))
	player.global_position = Vector2(1080, 282)
	await _settle(24)
	await _shot("codex_future_terminal_v2")
	level.call("begin_terminal_calibration", level.get_node("MemoryTerminal"))
	await _settle(8)
	await _shot("codex_future_calibration_v2")
	level.call("_complete_calibration")
	player.global_position = Vector2(1510, 282)
	await _settle(40)
	await _shot("codex_future_history_escort_v2")
	var civilians := level.get("_civilians") as Array
	for civilian in civilians:
		civilian.set("recruited", true)
		level.call("recruit_civilian", civilian)
		civilian.position.x = 2340.0
	for gate in level.get("_power_gates"):
		gate.set("powered", true)
	player.global_position = Vector2(2500, 282)
	await _settle(20)
	player.global_position = Vector2(2865, 282)
	await _settle(30)
	await _shot("codex_future_final_gates_v2")
	quit()

