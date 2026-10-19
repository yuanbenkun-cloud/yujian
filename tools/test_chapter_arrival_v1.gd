extends SceneTree
## 六关时空字幕、过场等待、缩放停靠与切场景清理检查。--capture 可保存实际画面。

var _ok: bool = true

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_ok = _ok and value
	print(("[PASS] " if value else "[FAIL] ") + label)

func _capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://preview/chapter-arrival-oct18")
	root.get_texture().get_image().save_png("res://preview/chapter-arrival-oct18/" + filename)

func _run() -> void:
	var arrival := root.get_node("ChapterArrival")
	arrival.set_process(false)
	var manager := root.get_node("LevelManager")
	var paths: Array[String] = []
	paths.assign(manager.get("SCENES"))
	paths.append(str(manager.get("FUTURE_SCENE")))
	for index in range(paths.size()):
		change_scene_to_file(paths[index])
		for _frame in range(12):
			await process_frame
		# 禁用测试场景的玩法计时，不改变存档或过关记录。
		current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		var player := current_scene.find_child("zhujue", true, false)
		player.set("frozen", false)
		root.get_node("DialogueSystem").call("cancel_for_scene_change")
		arrival.call("_on_scene_changed")
		var director := root.get_node("StoryDirector")
		director.set("busy", true)
		arrival.call("_process", 5.0)
		_check(is_zero_approx(float(arrival.get("_elapsed"))) and not bool(arrival.get("_root").visible), "%d：漫画期间不消耗字幕展示时间" % (index + 1))
		director.set("busy", false)
		arrival.call("_process", 0.4)
		await process_frame
		var card := arrival.get("_card") as Control
		var place := arrival.get("_place") as Label
		var time_label := arrival.get("_time") as Label
		_check(not place.text.is_empty() and not time_label.text.is_empty(), "%d：具体地点与时间完整" % (index + 1))
		var actual_center := card.position + card.size * card.scale * 0.5
		_check(actual_center.distance_to(root.get_visible_rect().size * 0.5) < 2.0, "%d：字幕首先居中" % (index + 1))
		_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%d：字幕不拦截操作" % (index + 1))
		if index == 5:
			_check(time_label.text.contains("2086") and time_label.text.contains("未来想象"), "第六关标明 2086 年为未来想象")
			var drone: Node = current_scene.get("_drone")
			drone.call("begin", player)
			var remaining := float(drone.get("remaining"))
			drone.call("_process", 0.2)
			_check(is_equal_approx(float(drone.get("remaining")), remaining), "字幕展示时不扣第六关追逐时间")
			var comic: Node = current_scene.get("_intro_comic")
			if is_instance_valid(comic):
				comic.hide()
		if index in [0, 5]:
			await _capture("%02d-center.png" % (index + 1))
		arrival.call("_process", 2.6)
		await process_frame
		_check(bool(arrival.get("_docked")) and card.position.is_equal_approx(Vector2(12, 6)) and card.scale.is_equal_approx(Vector2(0.5, 0.5)), "%d：缩小停靠到左上角" % (index + 1))
		_check(card.get_global_rect().end.x < root.get_visible_rect().size.x, "%d：停靠后不超出屏幕" % (index + 1))
		if index in [0, 5]:
			await _capture("%02d-docked.png" % (index + 1))
	change_scene_to_file("res://scenes/kaishi.tscn")
	await process_frame
	await process_frame
	_check(not bool(arrival.get("_active")) and not bool(arrival.get("_root").visible), "返回菜单后无字幕残留")
	print("[RESULT] " + ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
