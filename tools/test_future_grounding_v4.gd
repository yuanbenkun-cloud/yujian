extends SceneTree

var _ok := true

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	_ok = _ok and value

func _settle() -> void:
	for i in range(30):
		await process_frame

func _capture(filename: String) -> void:
	if "capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://codex-captures")
	root.get_texture().get_image().save_png("user://codex-captures/" + filename)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await _settle()
	var level := current_scene
	var player := level.get_node("zhujue") as CharacterBody2D
	var road := level.get_node("RoadSurface") as Node2D
	var barrier := level.get_node("MaintenanceBarrier420") as StaticBody2D
	var far := level.get_node("FutureLayers/Far") as Sprite2D
	_check(far.texture.resource_path.ends_with("city-backdrop-v6.png") and far.texture.get_size() == Vector2(1280, 720), "新都市远景已加载并与中景画布尺寸一致")
	var anchor := barrier.global_position
	_check(road.get_parent() == level, "路面属于世界，不跟随镜头背景")
	_check(barrier.get_node("AnchoredBase").polygon[2].y + barrier.position.y == 288.0, "阻挡底座与人物可见脚线均为288")
	level.call("_start_chase")
	player.position = Vector2(520, 180)
	await _settle()
	_check(road.global_position == Vector2.ZERO and barrier.global_position == anchor, "镜头横移和跳跃时路面及阻挡世界锚点不变")
	var terminal := level.get_node("MemoryTerminal")
	_check(not terminal.has_node("DeviceBacking"), "记忆站没有黑色背板")
	_check(barrier.has_node("GeneratedBarrier"), "阻挡物使用生图素材")
	terminal.call("mark_completed")
	_check(terminal.modulate == Color.WHITE, "校准完成不对整个终端和背板染色")
	player.position = Vector2(1080, 282)
	level.get("_story_panel").hide()
	await _settle()
	await _capture("codex_future_barrier_v5.png")
	await _capture("codex_future_terminal_v4.png")
	level.call("set_history_mode", true)
	for echo in level.get_node("HistoryEchoes").get_children():
		_check(echo.modulate.a >= 0.9, "历史建筑不透明度至少90%")
	_check(level.get_node("FutureLayers/Mid").modulate.r < 0.7, "历史模式未来背景退暗，旧建筑保留颜色")
	player.position = Vector2(2020, 282)
	await _settle()
	await _capture("codex_future_history_v4.png")
	level.call("set_history_mode", false)
	_check(level.get_node("FutureLayers/Mid").modulate == Color.WHITE, "回到现实恢复原背景亮度")
	print("[RESULT] ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
