extends SceneTree
## 第三关进入第四关时的物理回调、重复触发与等待脚本存活回归。

var _failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await process_frame
	await process_frame
	var manager := root.get_node_or_null("LevelManager")
	var director := root.get_node_or_null("StoryDirector")
	_check(manager != null and director != null, "关卡与叙事管理器已加载")
	if manager == null or director == null:
		_finish()
		return
	manager.set("current_level", 3)

	# physics_frame 后的续体模拟 Area2D.body_entered 所处阶段，并连续触发两次。
	await physics_frame
	manager.call("complete")
	manager.call("complete")
	await process_frame
	await process_frame
	_check(int(manager.get("current_level")) == 4, "重复终点信号只推进一个关卡")
	_check(current_scene != null and current_scene.scene_file_path.ends_with("04_fangdong.tscn"), "物理帧触发后安全进入第四关")

	director.set("_skip_all", true)
	await create_timer(1.8).timeout
	_check(current_scene != null and current_scene.is_inside_tree(), "第四关在漫画结束后仍保持有效")
	var intro := current_scene.find_child("LevelStoryIntro", true, false) if current_scene != null else null
	_check(intro == null or intro.is_inside_tree(), "第四关目标提示未在释放后继续访问场景树")
	for _frame in range(360):
		if not bool(director.get("busy")):
			break
		await process_frame
	var follower := current_scene.find_child("GroupFollower", true, false) if current_scene != null else null
	_check(follower != null and not bool(follower.get("_enabled")) and (follower.get("followers") as Array).size() == 6 and (follower.get("active_followers") as Array).is_empty(), "第三关转入第四关后仅主角起步，六名难民留在沿途等待救援")
	_finish()

func _check(condition: bool, message: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + message)
	if not condition:
		_failed += 1

func _finish() -> void:
	print("[RESULT] %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)
