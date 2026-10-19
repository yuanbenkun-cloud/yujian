extends SceneTree
## 精灵前方跟随与世界画布照明检查，不写存档。--capture 保存照明对照图。

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
	DirAccess.make_dir_recursive_absolute("res://preview/spirit-light-oct18")
	root.get_texture().get_image().save_png("res://preview/spirit-light-oct18/" + filename)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	for _frame in range(20):
		await process_frame
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var player := current_scene.get_node("zhujue") as CharacterBody2D
	player.position = Vector2(700, 240)
	player.set("frozen", false)
	var camera := player.find_child("*", true, false) as Camera2D
	for node in player.get_children():
		if node is Camera2D:
			camera = node
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()
	var companion := root.get_node("Companion")
	companion.set_process(false)
	player.set("look_dir", 1)
	companion.set("_snap", true)
	companion.call("_process", 0.1)
	await process_frame
	companion.call("_process", 0.1)
	var light := current_scene.get_node_or_null("YudengPathLight") as PointLight2D
	_check(not player.has_node("CarriedLantern"), "第四关主角不再携带手提灯")
	_check(light != null and light.texture != null and light.energy > 1.0, "精灵拥有真实世界照明光源")
	_check(light.get_parent() == current_scene, "光源放在世界画布，不是 UI 假发光")
	var point := player.get_global_transform_with_canvas().origin
	var center: Vector2 = companion.get("_root").position + companion.AVATAR_CENTER
	_check(center.x > point.x + 35, "向右时精灵在前方")
	var projected_light := player.get_canvas_transform() * light.global_position
	_check(projected_light.distance_to(center) < 1.0, "镜头移动后光源中心与精灵重合")
	root.get_node("ChapterArrival").call("_process", 3.0)
	await _capture("04-right-lit.png")
	light.enabled = false
	await _capture("04-right-unlit.png")
	light.enabled = true
	var before_turn: Vector2 = companion.get("_root").position
	player.set("look_dir", -1)
	companion.call("_process", 0.016)
	center = companion.get("_root").position + companion.AVATAR_CENTER
	_check(companion.get("_root").position.distance_to(before_turn) < 5.0 and center.x > point.x, "转身首帧不瞬移到另一侧")
	var highest_y := center.y
	var previous: Vector2 = companion.get("_root").position
	var max_step := 0.0
	var light_tracks_flight := true
	for step in range(45):
		companion.call("_process", 0.016)
		var position: Vector2 = companion.get("_root").position
		max_step = maxf(max_step, position.distance_to(previous))
		highest_y = minf(highest_y, position.y + companion.AVATAR_CENTER.y)
		previous = position
		var light_point := player.get_canvas_transform() * light.global_position
		light_tracks_flight = light_tracks_flight and light_point.distance_to(position + companion.AVATAR_CENTER) < 1.0
		if step == 20:
			await _capture("04-turn-mid-flight.png")
	center = companion.get("_root").position + companion.AVATAR_CENTER
	_check(center.x < point.x - 35, "飞行结束后到达左前方")
	_check(highest_y < before_turn.y + companion.AVATAR_CENTER.y - 10.0, "换边时沿上拱轨迹飞过主角")
	_check(max_step < 8.0, "整段飞行无大幅跳位")
	_check(light_tracks_flight, "飞行过程中每帧光源均跟随精灵")
	player.set("look_dir", 1)
	companion.call("_process", 0.16)
	var mid_turn: Vector2 = companion.get("_root").position
	player.set("look_dir", -1)
	companion.call("_process", 0.016)
	_check(companion.get("_root").position.distance_to(mid_turn) < 5.0, "快速反向从当前飞行位置继续")
	for step in range(48):
		companion.call("_process", 0.016)
	await _capture("04-left-lit.png")
	root.get_node("DialogueSystem").set("active", true)
	companion.call("_process", 0.016)
	_check(companion.get("_root").visible and light.visible, "普通对话时精灵继续照路")
	root.get_node("DialogueSystem").set("active", false)
	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	for _frame in range(12):
		await process_frame
	companion.call("_process", 0.1)
	_check(not is_instance_valid(light) and companion.get("_world_light") == null, "离开第四关清理洞内光源")
	_check(not companion.get("_halo").visible, "其他关卡不叠加洞内强光晕")
	player = current_scene.get_node("zhujue")
	player.set("frozen", false)
	player.set("look_dir", 1)
	companion.set("_snap", true)
	companion.call("_process", 0.1)
	point = player.get_global_transform_with_canvas().origin
	center = companion.get("_root").position + companion.AVATAR_CENTER
	_check(center.x > point.x, "其他关卡也统一为前方跟随")
	print("[RESULT] " + ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
