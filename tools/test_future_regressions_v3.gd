extends SceneTree

var _ok := true
var _original_flags: Dictionary

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	_ok = _ok and value

func _open() -> Node:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	for i in range(8):
		await process_frame
	return current_scene

func _run() -> void:
	var gs := root.get_node("GameState")
	_original_flags = gs.get("insight_flags").duplicate(true)
	var level := await _open()
	var player := level.get_node("zhujue") as CharacterBody2D
	_check(player.get_node("zhujue_shexiangji").offset == Vector2.ZERO, "第六关不继承向上偏移，背景覆盖画面")
	var frame: AnimatedSprite2D = player.get_node("VisualPivot/zhujue_donghua")
	for i in range(3):
		await physics_frame
	_check(frame.animation == &"idle", "序章冻结的主角保持站立")
	level.call("_start_chase")
	player.position = Vector2(-120, 282)
	await process_frame
	await process_frame
	_check(player.position.x > 0 and player.position.y < 300, "越界自动恢复，避免无限坠落")
	var drone := level.get("_drone") as Node
	drone.set("remaining", 0.001)
	await process_frame
	await process_frame
	_check(float(drone.get("remaining")) > 17.0, "追机超时恢复本段而非卡死")
	level.call("on_drone_caught", Vector2(790, 151))
	level.call("begin_terminal_calibration", level.get_node("MemoryTerminal"))
	level.call("_complete_calibration")
	var gates: Array = level.get("_power_gates")
	gates[0].call("on_interact", player)
	_check(not bool(gates[0].get("powered")), "历史层不能打开现实供能门")
	level.call("set_history_mode", false)
	gates[0].call("on_interact", player)
	await process_frame
	_check(bool(gates[0].get("powered")), "现实层可接通供能门")
	level.set("_history_energy", 2.0)
	level.call("set_history_mode", true)
	_check(not bool(level.get("history_mode")), "低灯芯时不能反复开启历史层")
	level.call("_update_history_energy", 2.0)
	_check(float(level.get("_history_energy")) >= 33.0, "现实层可恢复灯芯")
	for civilian in level.get("_civilians"):
		civilian.set("recruited", true)
		civilian.set_process(false)
		level.call("recruit_civilian", civilian)
	player.position = Vector2(2500, 282)
	_check(not bool(level.call("_escort_arrived")), "主角单独到终点，队尾未到不能完成护送")
	for civilian in level.get("_civilians"):
		civilian.position.x = 2340
	gates[1].set("powered", true)
	_check(bool(level.call("_escort_arrived")), "三人和两道供能门都满足条件才能完成护送")
	for choice in ["archive", "overwrite", "living"]:
		level = await _open()
		level.set("stage", 4)
		level.call("_confirm_memory_gate", "real")
		level.set("_message_timer", 0.01)
		level.call("_finish_future", choice)
		await create_timer(0.10).timeout
		_check(level.get("_story_panel").visible and level.get("_return_button") != null, "%s 结局文本保持显示并提供返回按钮" % choice)
		_check(str(level.get("_ending_choice")) == choice, "%s 结局具有独立城市演出状态" % choice)
	gs.set("insight_flags", _original_flags)
	gs.call("_save_story")
	print("[RESULT] ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
