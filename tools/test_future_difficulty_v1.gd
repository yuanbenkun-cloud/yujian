extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(0.5).timeout
	var level: Node = current_scene
	level.set_process(false)
	level.call("_start_chase")
	check(level._drone.remaining == 18.0, "追逐限时缩短至18秒")
	level._drone.active = false
	level.call("on_drone_caught", Vector2(790, 193))
	level.call("begin_terminal_calibration", level._terminal)
	level.call("_next_calibration_mode")
	Input.action_press("interact")
	level.call("_update_calibration", 10.0)
	check(level._calibration_mode == 1, "持续长按不能跳过线路谜题")
	Input.action_release("interact")
	var circuit: Node = level._memory_circuit
	circuit.verify()
	check(level._calibration_mode == 1, "断路验证失败不能进入下一段")
	for index in range(9):
		for turn in range((4 - circuit.SCRAMBLE[index]) % 4): circuit.rotate_tile(index)
	circuit.verify()
	check(level._calibration_mode == 2, "接通线路后进入四次同步")
	for i in range(4):
		level.call("_layout_sync_target")
		check(level._calibration_target.size.x <= 424.0 * 0.12 + 0.01, "同步判定比原版收窄")
		level._calibration_value = level.SYNC_CENTERS[i]
		level.call("_attempt_timing_hit")
		if i < 3: check(level.stage == 2, "前三次命中不能提前通过")
	check(level.stage == 3, "四次精准命中完成校准")
	level._history_energy = 100.0
	level.call("_update_history_energy", 5.0)
	check(is_equal_approx(level._history_energy, 30.0), "回忆层消耗迫使管理补能时机")
	check(level._scanner_zones.size() == 3, "三处扫描区检查主角及队尾")
	level._civilians[0].recruited = true
	level._recruited.append(level._civilians[0])
	level.player.position.x = 1720
	level.history_mode = false
	level.call("_update_scanners", 0.8)
	check(level._recruited.is_empty() and level.stage == 3 and level.memory_shards == 2, "扫描失败仅重试护送，不重做追逐校准")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
