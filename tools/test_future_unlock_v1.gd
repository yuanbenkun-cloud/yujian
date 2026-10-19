extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		push_error("[FAIL] GameState autoload missing")
		quit(1)
		return
	var previous_completed := bool(game_state.get("story_completed"))
	var previous_levels: Array = game_state.completed_levels.duplicate()
	game_state.completed_levels.assign([1, 2, 3, 4, 5])
	game_state.set("story_completed", true)
	var menu_scene := load("res://scenes/kaishi.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var future_button := menu.find_child("FutureButton", true, false)
	var future_scene := load("res://scenes/guanqia/06_future_chongqing.tscn") as PackedScene
	var generated := future_button != null and future_scene != null
	var level_manager := root.get_node_or_null("LevelManager")
	var director := root.get_node_or_null("StoryDirector")
	# 复现真实故障：片尾刚回到标题时，上一转场仍持有 busy/transitioning 锁。
	if level_manager != null:
		level_manager.set("_transitioning", true)
	if director != null:
		director.set("busy", true)
	if future_button != null:
		future_button.grab_focus()
		future_button.pressed.emit()
	await process_frame
	var queued: bool = level_manager != null and bool(level_manager.get("_future_launch_pending")) and future_button.disabled
	if level_manager != null:
		level_manager.set("_transitioning", false)
	if director != null:
		director.set("busy", false)
	await create_timer(0.85).timeout
	var routed: bool = level_manager != null and int(level_manager.get("current_level")) == 6
	var future_loaded: bool = current_scene != null and current_scene.scene_file_path == "res://scenes/guanqia/06_future_chongqing.tscn"
	var passed: bool = generated and queued and routed and future_loaded
	print("[INFO] generated=%s queued=%s routed=%s scene=%s" % [generated, queued, routed, current_scene.scene_file_path if current_scene != null else "<null>"])
	print("[PASS] 第六关按钮在转场锁期间可排队，并能进入未来重庆" if passed else "[FAIL] 第六关按钮解锁、排队或输入路由")
	game_state.set("story_completed", previous_completed)
	game_state.completed_levels.assign(previous_levels)
	quit(0 if passed else 1)
