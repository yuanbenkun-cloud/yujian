extends SceneTree
## One-time repair, only for this user-confirmed five-level completion.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if not "repair-confirmed" in OS.get_cmdline_user_args():
		quit(1)
		return
	var gs: Node = root.get_node("GameState")
	if not gs.story_completed or not gs.completed_levels.has(5):
		print("[SKIP] 当前存档不符合本次已确认通关的修复条件")
		quit(1)
		return
	for memory: String in ["board", "flyer", "lights", "old_man", "view", "wall"]:
		if not bool(gs.insight_flags.get("memory_" + memory, false)):
			print("[SKIP] 第五关记忆记录不完整，不修改存档")
			quit(1)
			return
	var backup: String = gs.SAVE_PATH + ".confirmed_clear_oct17.bak"
	if not FileAccess.file_exists(backup):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH), ProjectSettings.globalize_path(backup)) != OK:
			quit(1)
			return
	for level in range(1, 6): gs.record_level_completed(level)
	change_scene_to_file("res://scenes/kaishi.tscn")
	await process_frame
	await process_frame
	var visible: bool = current_scene != null and current_scene.find_child("FutureButton", true, false) != null
	print("[PASS] 已备份并修复本次确认的全通记录，标题显示第六章" if visible else "[FAIL] 修复后按钮未显示")
	quit(0 if visible else 1)
