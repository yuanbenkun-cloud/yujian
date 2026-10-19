extends SceneTree

class TestManager extends "res://autoload/level_manager.gd":
	var destination: String = ""
	func _ready() -> void: pass
	func _go(path: String, _caption: String = "") -> void:
		destination = path

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var previous: Dictionary = {}
	for property: String in ["saved_level", "highest_unlocked_level", "story_completed", "ending_choice", "photo_timestamp", "goods_integrity", "insight_flags", "completed_levels"]:
		var value: Variant = gs.get(property)
		previous[property] = value.duplicate(true) if value is Array or value is Dictionary else value
	gs.completed_levels.clear()
	var manager := TestManager.new()
	root.add_child(manager)
	for index in range(4):
		change_scene_to_file(manager.SCENES[index])
		await process_frame
		await process_frame
		manager.current_level = 5 # Simulate a stale manager after editor/resume launches.
		manager.complete()
		check(gs.completed_levels.has(index + 1) and manager.current_level == index + 2, "正常出口按当前场景登记第%d关，不依赖过期关号" % (index + 1))
		check(manager.destination == manager.SCENES[index + 1], "出口前往正确下一关")
	gs.mark_story_complete("observe")
	check(gs.can_enter_future(), "正常五关通过后可进入第六关")
	gs._load_story()
	check(gs.can_enter_future(), "重新读取存档仍保留五关通关资格")
	change_scene_to_file("res://scenes/kaishi.tscn")
	await process_frame
	check(current_scene.find_child("FutureButton", true, false) != null, "返回标题实际显示第六关按钮")
	for property: String in previous:
		if property == "completed_levels": gs.completed_levels.assign(previous[property])
		else: gs.set(property, previous[property])
	gs._save_story()
	manager.queue_free()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
