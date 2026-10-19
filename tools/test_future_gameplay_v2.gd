extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("[FAIL] " + message)
	quit(1)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	for _i in range(12):
		await process_frame
	var level := current_scene
	var player := level.get_node_or_null("zhujue") as CharacterBody2D
	if player == null or int(level.get("stage")) != 0:
		_fail("第六关序章或主角未初始化")
		return
	level.call("_start_chase")
	level.call("on_drone_caught", Vector2(790, 150))
	if int(level.get("memory_shards")) != 1:
		_fail("追逐阶段未获得第一枚记忆")
		return
	var terminal := level.get_node_or_null("MemoryTerminal") as Area2D
	player.global_position = Vector2(1110, 282)
	player.frozen = false
	for _i in range(8):
		await physics_frame
	if not bool(player.call("_try_interact")):
		_fail("主角交互区没有识别到记忆终端")
		return
	if int(level.get("stage")) != 2 or not bool(player.get("frozen")):
		_fail("三段校准未冻结主角或未进入正确状态")
		return
	level.call("_complete_calibration")
	if int(level.get("stage")) != 3 or int(level.get("memory_shards")) != 2:
		_fail("校准完成后未进入护送阶段")
		return
	level.call("set_history_mode", true)
	var civilians := level.get("_civilians") as Array
	for civilian in civilians:
		civilian.set("recruited", true)
		level.call("recruit_civilian", civilian)
		civilian.position.x = 2340.0
	for gate in level.get("_power_gates"):
		gate.set("powered", true)
	if int(level.get("memory_shards")) != 5:
		_fail("三名记忆市民未补全五枚记忆")
		return
	player.global_position = Vector2(2500, 282)
	for _i in range(4):
		await process_frame
	if int(level.get("stage")) != 4:
		_fail("护送完成后未进入真假洪崖洞阶段")
		return
	level.call("choose_memory_gate", "fake")
	if int(level.get("stage")) != 4:
		_fail("错误节点不应直接结束关卡")
		return
	level.call("choose_memory_gate", "real")
	await create_timer(0.4).timeout
	level.call("choose_memory_gate", "real")
	if int(level.get("stage")) != 5 or not bool(player.get("frozen")):
		_fail("真实节点未打开最终选择")
		return
	print("[PASS] 第六关流程结构通过；真实输入操作见 test_future_gameplay_v3.gd")
	quit(0)

