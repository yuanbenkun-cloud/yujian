extends SceneTree
## 剧情回归：第四关开场、护送启动、结局去向与跨关领悟记录。

var failed := 0

func _check(condition: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failed += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	await process_frame
	await process_frame
	var player := current_scene.find_child("zhujue", true, false)
	var intro := current_scene.find_child("StoryIntroPanel", true, false)
	var follower := current_scene.find_child("GroupFollower", true, false)
	_check(intro != null and not bool(player.get("frozen")), "第四关：章节过场后出现非阻塞目标提示")
	await create_timer(2.5).timeout
	_check(not bool(player.get("frozen")) and not bool(follower.get("_enabled")), "第四关：开场只有主角，尚无难民跟随")
	var members: Array = follower.get("followers")
	var active: Array = follower.get("active_followers")
	_check(members.size() == 6 and active.is_empty() and follower.get("_leader") == player, "第四关：六名难民分布在沿途三个救援点")
	if not members.is_empty():
		var warning := current_scene.find_child("BombWarning", true, false)
		if warning != null:
			warning.call("stop")
		player.global_position.x = 520.0
		await create_timer(0.35).timeout
		active = follower.get("active_followers")
		_check(active.size() == 1 and bool(follower.get("_enabled")), "第四关：抵达第一救援点后首名难民加入")
		player.global_position.x = 1480.0
		await create_timer(0.35).timeout
		active = follower.get("active_followers")
		_check(active.size() == 3, "第四关：抵达第二救援点后队伍增至三人")
		player.global_position.x = 2440.0
		await create_timer(0.35).timeout
		active = follower.get("active_followers")
		_check(active.size() == 6 and bool(follower.call("all_rescued")), "第四关：后段三人加入后形成完整六人长队")
	var gs: Node = root.get_node_or_null("GameState")
	gs.call("reset_story")
	gs.call("record_insight", "labor", 720)
	gs.call("record_insight", "trust", "完好")
	gs.call("record_insight", "responsibility", true)
	_check(gs.get("insight_flags").size() == 3, "跨关剧情领悟被记录")
	_check(root.get_node("LevelManager").has_method("finish_story"), "结局返回标题页接口存在")
	print("[RESULT] %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)
