extends SceneTree

var _ok := true

func _check(condition: bool, message: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + message)
	_ok = _ok and condition

func _capture(filename: String) -> void:
	if "capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://preview/feedback-v3"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/feedback-v3/" + filename))

func _level(path: String) -> void:
	change_scene_to_file(path)
	for i in range(12):
		await process_frame
	paused = false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	for i in range(10):
		await process_frame
	var crowds := current_scene.find_children("diyiguan_renqun*", "AnimatableBody2D", true, false)
	print("CROWDS ", crowds.size())
	var actor := crowds[0].get_node("CrowdActor1") as AnimatedSprite2D
	var seen := {}
	for i in range(90):
		await physics_frame
		seen[actor.frame] = true
		if i % 15 == 0:
			print("CROWD ", i, " x=", crowds[0].position.x, " animation=", actor.animation, " frame=", actor.frame, " playing=", actor.is_playing())
	_check(seen.size() >= 4, "第一关移动人群实际播放多个行走帧")
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(730, 240)
	await _capture("crowd.png")
	var dialogue := current_scene.find_child("DialoguePanel", true, false)
	dialogue.show()
	dialogue.call("play_line", "陈默", "阿姨，前面这条路怎么走？")
	dialogue.call("play_line", "传单阿姨", "前面石板滑，你慢点跑。")
	await _capture("dialogue.png")
	await _level("res://scenes/guanqia/03_zhongshan.tscn")
	player = current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(550, 240)
	var carrier := current_scene.get_node("RouteHazard1/HazardVisual/WaterCarrierAnimation") as AnimatedSprite2D
	seen.clear()
	for i in range(90):
		await physics_frame
		seen[carrier.frame] = true
	_check(seen.size() >= 4, "第三关挑水人播放专用六帧动画")
	var image := carrier.sprite_frames.get_frame_texture("walk", carrier.frame).get_image()
	var bounds := image.get_used_rect()
	var actual_bottom := carrier.global_position.y + float(bounds.end.y) * carrier.global_scale.y
	_check(absf(actual_bottom - 246.0) < 1.5, "挑水人与主角脚线相同：y=246")
	await _capture("water-carrier.png")
	await _level("res://scenes/guanqia/04_fangdong.tscn")
	player = current_scene.find_child("zhujue", true, false) as CharacterBody2D
	player.global_position = Vector2(315, 240)
	var shield := current_scene.get_node("BlastShield1")
	var shield_sprite := shield.get_node("BarrierVisual/GeneratedBarrier")
	_check(float(shield_sprite.get_meta("visible_top_y")) < 176.0, "挡板顶端高于主角头顶")
	_check(float(shield_sprite.get_meta("grounded_visible_bottom_y")) == 246.0, "挡板放大后底部仍贴地")
	_check(shield_sprite.get_parent().z_index < 20, "第四关挡板绘制在主角和NPC后方")
	_check(not player.has_node("CarriedLantern") and current_scene.has_node("YudengPathLight"), "第四关移除手提灯，由前方渝灯照明")
	await _capture("shelter.png")
	print("[RESULT] ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
