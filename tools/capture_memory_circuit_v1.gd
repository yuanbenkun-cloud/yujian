extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(0.5).timeout
	var level: Node = current_scene
	level.call("_start_chase")
	level.call("on_drone_caught", Vector2(790, 193))
	level.call("begin_terminal_calibration", level._terminal)
	level.call("_next_calibration_mode")
	await create_timer(0.4).timeout
	var board: Node = level._memory_circuit
	var tile: Button = board.tiles[3]
	tile.grab_focus()
	var old: int = tile.ports
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key, true)
	await process_frame
	print("[PASS] 键盘回车可旋转线路" if tile.ports != old else "[FAIL] 键盘旋转")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/future-memory-circuit-v1.png")
	var okay: bool = tile.ports != old
	quit(0 if okay else 1)
