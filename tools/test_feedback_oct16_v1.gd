extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func settle() -> void:
	for i in range(20): await process_frame

func advance(panel: Control) -> void:
	panel._input_guard_until = 0
	panel._consume_advance_press()
	await process_frame

func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var flags: Dictionary = gs.insight_flags.duplicate(true)
	var goods: int = gs.goods_integrity
	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await settle()
	var scene: Node = current_scene
	var ds: Node = root.get_node("DialogueSystem")
	var panel: Control = scene.get_node("UI_Base/DialoguePanel")
	scene.get_node("laozhanggui").on_interact(scene.get_node("zhujue"))
	for i in range(16):
		if panel.has_options(): break
		await advance(panel)
	check(panel.has_options() and panel._opts_box.visible and panel._opts_box.get_child_count() == 2, "首次进入掌柜对话，最后一句完成立即显示两个选项")
	check(not panel._continue_lb.visible, "选择出现后不再误示继续")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/trade-first-options-oct16.png")
	ds.choose(0)
	for i in range(12):
		if not ds.active: break
		await advance(panel)
	check(scene.get_node("ChoiceSystem").stage == 1, "完成选项分支后才推进护送路线")
	var hazard: Node = scene.get_node("RouteHazard1")
	scene.get_node("zhujue").position = hazard.position + Vector2(-100, 0)
	hazard._process(0.01)
	check(hazard.get_node("CargoHazardWarning").visible, "危险挑水人附近显示黄色警示")
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/water-carrier-warning-oct16.png")
	var zhou: Node = scene.get_node("laozhou")
	gs.goods_integrity = 49
	scene.get_node("ChoiceSystem").stage = 3
	zhou.on_interact(scene.get_node("zhujue"))
	check(zhou._delivery_failed and gs.get_result_tier() == "严重受损", "49%不能签收")
	ds.cancel_for_scene_change()
	if ds.ended.is_connected(zhou._on_dialogue_ended): ds.ended.disconnect(zhou._on_dialogue_ended)
	gs.goods_integrity = 50
	zhou.on_interact(scene.get_node("zhujue"))
	check(not zhou._delivery_failed and gs.get_result_tier() == "受损", "恰好50%允许签收")
	check(scene.get_node("ChoiceSystem").stage == 3, "验货对话尚未完成不提前结算")
	for i in range(12):
		if not ds.active: break
		await advance(panel)
	check(scene.get_node("disanguan_chukou")._active and scene.get_node("ChoiceSystem").stage == 4, "50%验货完成后正常开启出口")
	var companion: Node = root.get_node("Companion")
	var avatar: Control = companion._root.get_node("CompanionAvatar")
	avatar.set_facing(1)
	check(avatar._sprite.flip_h and avatar._sprite.sprite_frames.get_frame_count("hover") == 4, "渝灯向右播放全部四帧")
	avatar.set_facing(-1)
	check(not avatar._sprite.flip_h, "渝灯向左正确恢复朝向")
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await settle()
	scene = current_scene
	scene._start_chase()
	await settle()
	var rect: Rect2 = scene._story_panel.get_global_rect()
	check(rect.end.x <= 632 and rect.position.y < 100 and rect.size.x <= 280, "第六关渝灯提示小框不溢出屏幕、不盖人物路面")
	check(scene._message_timer <= 5, "临时剧情提示最长五秒")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/future-compact-dialogue-oct16.png")
	var comic: Control = load("res://scripts/ui/story_comic.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 80
	root.add_child(layer)
	layer.add_child(comic)
	comic.configure("序章 · 抄近路的人", root.get_node("StoryDirector").PROLOGUE_COMIC, "点击进入第一章")
	comic.finish_immediately()
	check(comic._panels.size() == 4 and comic._panels[0].get_node("ComicArt1").texture.atlas.resource_path.ends_with("prologue-v3/atlas.png"), "序章四格改用重绘插画")
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/prologue-v3-oct16.png")
	gs.insight_flags = flags
	gs.goods_integrity = goods
	gs._save_story()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
