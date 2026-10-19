extends SceneTree
## Ctrl+Enter treats the current level as a test clear.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gs := root.get_node("GameState")
	var previous := {
		"saved_level": int(gs.get("saved_level")),
		"highest": int(gs.get("highest_unlocked_level")),
		"completed": gs.get("story_completed"),
		"choice": str(gs.get("ending_choice")),
		"clears": gs.completed_levels.duplicate(),
		"flags": gs.insight_flags.duplicate(true),
		"goods": gs.goods_integrity,
		"photo": gs.photo_timestamp,
	}
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	await process_frame
	await process_frame
	var manager := root.get_node("LevelManager")
	manager.set("current_level", 1)
	var event := InputEventKey.new()
	event.pressed = true
	event.ctrl_pressed = true
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	var chat: Node = root.get_node("YudengChat")
	chat.is_open = true
	manager.call("_input", event)
	var blocked: bool = current_scene.scene_file_path == "res://scenes/guanqia/01_hongyadong.tscn" and not manager._debug_skip_pending
	chat.is_open = false
	print("[PASS] 聊天期间不误触跳关" if blocked else "[FAIL] 聊天输入触发跳关")
	root.push_input(event, true)
	for _i in range(20):
		await process_frame
	var first_passed: bool = current_scene != null \
		and current_scene.scene_file_path == "res://scenes/guanqia/02_ciqikou.tscn" \
		and int(manager.get("current_level")) == 2
	first_passed = first_passed and gs.completed_levels.has(1)
	print("[PASS] Ctrl+Enter 进入第二关并登记当前关为测试通过" if first_passed else "[FAIL] 隐藏跳关输入或切场景失败")

	change_scene_to_file("res://scenes/guanqia/05_hongyadong_return.tscn")
	await process_frame
	await process_frame
	manager.set("current_level", 5)
	manager.call("_input", event)
	for _i in range(20):
		await process_frame
	var finale_passed: bool = current_scene != null \
		and current_scene.scene_file_path == "res://scenes/jieju.tscn" \
		and gs.get("story_completed") == true
	print("[PASS] 第五关跳过后进入片尾" if finale_passed else "[FAIL] 第五关跳过未正确完成主线")

	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await process_frame
	await process_frame
	manager.set("current_level", 6)
	event.physical_keycode = KEY_KP_ENTER
	event.keycode = KEY_KP_ENTER
	manager.call("_input", event)
	for _i in range(20):
		await process_frame
	var future_passed: bool = current_scene != null and current_scene.scene_file_path == "res://scenes/kaishi.tscn"
	print("[PASS] 第六关跳过后返回主界面" if future_passed else "[FAIL] 第六关跳过未返回主界面")
	var passed: bool = blocked and first_passed and finale_passed and future_passed
	gs.set("saved_level", previous["saved_level"])
	gs.set("highest_unlocked_level", previous["highest"])
	gs.set("story_completed", previous["completed"])
	gs.set("ending_choice", previous["choice"])
	gs.completed_levels.assign(previous["clears"])
	gs.insight_flags = previous["flags"]
	gs.goods_integrity = previous["goods"]
	gs.photo_timestamp = previous["photo"]
	gs.call("_save_story")
	quit(0 if passed else 1)
