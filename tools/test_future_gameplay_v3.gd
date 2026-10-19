extends SceneTree
## 通过真实鼠标/键盘输入完成操作；不直接调用追逐成功或校准完成。

var _ok := true
var _saved_flags: Dictionary
var level: Node
var player: CharacterBody2D

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + label)
	_ok = _ok and condition

func _click(at := Vector2(282, 225)) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	Engine.time_scale = 2.0
	var gs := root.get_node("GameState")
	_saved_flags = gs.get("insight_flags").duplicate(true)
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	for i in range(12):
		await process_frame
	level = current_scene
	player = level.get_node("zhujue")
	await create_timer(0.6).timeout
	for i in range(4):
		await _click(Vector2(180, 280))
		await create_timer(0.6).timeout
	_check(int(level.get("stage")) == 1, "在序章面板内部点击四次能开始追逐")
	Input.action_press("move_right")
	var jump_latched := false
	for i in range(800):
		await physics_frame
		if jump_latched:
			Input.action_release("jump")
			jump_latched = false
			continue
		if int(level.get("memory_shards")) > 0:
			break
		if player.position.x > 788:
			Input.action_release("move_right")
		if player.is_on_floor() and player.position.x > 350:
			Input.action_press("jump")
			jump_latched = true
		if i % 120 == 0:
			print("CHASE x=", player.position.x, " y=", player.position.y, " drone=", level.get("_drone").position)
	Input.action_release("jump")
	Input.action_release("move_right")
	_check(int(level.get("memory_shards")) == 1, "实际走跳越过维护障碍并跳近无人机获得碎片")
	if not _ok:
		quit(1)
		return
	Input.action_press("move_right")
	for i in range(400):
		await physics_frame
		if player.position.x >= 1080:
			break
	Input.action_release("move_right")
	await _action("interact")
	await physics_frame
	await process_frame
	_check(int(level.get("stage")) == 2, "实际 E 交互进入终端校准")
	for i in range(20):
		if int(level.get("_calibration_mode")) != 0:
			break
		await _click()
		await create_timer(0.06).timeout
	_check(int(level.get("_calibration_mode")) == 1, "鼠标连按完成供电阶段")
	await process_frame
	var circuit: Node = level.get("_memory_circuit")
	_check(circuit != null and not circuit.has_memory_route(), "终端打开真实线路重构谜题，而非长按传输")
	for index in range(9):
		var tile: Button = circuit.tiles[index]
		for turn in range((4 - circuit.SCRAMBLE[index]) % 4):
			await _click(tile.get_global_rect().get_center())
	var verify_button: Button = circuit.find_children("*", "Button", true, false)[9]
	await _click(verify_button.get_global_rect().get_center())
	_check(int(level.get("_calibration_mode")) == 2, "实际鼠标旋转线路并验证后进入同步")
	for i in range(1400):
		await physics_frame
		if int(level.get("stage")) != 2:
			break
		var target: ColorRect = level.get("_calibration_target")
		var center := (target.position.x - 8.0 + target.size.x * 0.5) / 424.0
		if absf(float(level.get("_calibration_value")) - center) < 0.035:
			await _click()
			await create_timer(0.10).timeout
	_check(int(level.get("stage")) == 3, "移动指针实操四次逐渐收窄命中后开始护送")
	Input.action_press("move_right")
	var recharged: bool = false
	for i in range(1500):
		await physics_frame
		if int(level.get("stage")) == 4:
			break
		# 第二道门后的安全间隔补满灯芯，再连过最后两道扫描带。
		if not recharged and player.position.x >= 1915 and player.position.x < 1990:
			Input.action_release("move_right")
			await create_timer(0.7).timeout
			level.call("set_history_mode", false)
			await create_timer(6.4).timeout
			level.call("set_history_mode", true)
			recharged = true
			Input.action_press("move_right")
		var operated := false
		for gate in level.get("_power_gates"):
			if not gate.get("powered") and absf(player.position.x - (gate.position.x - 45)) < 30:
				Input.action_release("move_right")
				level.call("set_history_mode", false)
				await _action("interact")
				await physics_frame
				level.call("set_history_mode", true)
				Input.action_press("move_right")
				operated = true
				break
		if not operated and not bool(level.get("history_mode")):
			level.call("set_history_mode", true)
		if player.position.x > 2480:
			Input.action_release("move_right")
	Input.action_release("move_right")
	_check(int(level.get("stage")) == 4, "现实开两道门、历史避扫描、三名市民全部到集合点")
	for civilian in level.get("_civilians"):
		var animation: AnimatedSprite2D = civilian.get("_anim")
		_check(animation.sprite_frames.get_frame_texture("idle", 0).resource_path.ends_with("idle-transparent.png"), "记忆市民使用独立站立帧")
	# 比较阶段需要分别观察两边，不能第一次选择直接结算。
	level.call("choose_memory_gate", "real")
	_check(int(level.get("stage")) == 4, "只观察单个节点不能直接结束")
	level.call("choose_memory_gate", "fake")
	await create_timer(0.4, true, false, true).timeout
	level.call("choose_memory_gate", "real")
	await create_timer(0.4, true, false, true).timeout
	level.call("choose_memory_gate", "real")
	_check(int(level.get("stage")) == 5, "对比线索并确认真实节点后才出现结局选择")
	level.set("_message_timer", 0.05)
	level.call("_finish_future", "living")
	await create_timer(1.0, true, false, true).timeout
	_check(level.get("_story_panel").visible, "结局文字不受临时提示计时器影响")
	_check(level.get("_return_button") != null, "结局有明确且持续有效的返回按钮")
	# 测试结局会写入存档；立即恢复玩家原有标记。
	gs.set("insight_flags", _saved_flags)
	gs.call("_save_story")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(180, 235)
	root.push_input(motion, true)
	await _click(Vector2(290, 329))
	await create_timer(0.8, true, false, true).timeout
	_check(current_scene.scene_file_path == "res://scenes/kaishi.tscn", "鼠标先移动再点击仍能返回主界面")
	print("[RESULT] ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
