extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func advance(key: bool = false) -> void:
	if key:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		root.push_input(event, true)
		event = InputEventAction.new()
		event.action = "interact"
		root.push_input(event, true)
	else:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = Vector2(180, 280)
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
	await create_timer(0.35).timeout

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(0.5).timeout
	var level: Node = current_scene
	var comic: Control = level.get_node("UI_Base/FutureIntroComic")
	check(comic.get("_revealed") == 1, "开场自动揭开第一格")
	check(level.player.frozen and level.stage == level.Stage.INTRO, "阅读期间冻结主角，不开始追逐")
	for i in range(4):
		var panel: Control = comic.get("_panels")[i]
		var art: TextureRect = panel.get_node("ComicArt%d" % (i + 1))
		check(art.texture != null and art.texture is AtlasTexture, "漫画%d使用生成图的独立裁切" % (i + 1))
	for i in range(3):
		await advance(i == 1)
	check(comic.get("_revealed") == 4 and level.stage == level.Stage.INTRO, "鼠标和E逐格揭开，四格读完仍等待确认")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/future-intro-comic-v1.png")
	await advance()
	check(level.stage == level.Stage.CHASE and not level.player.frozen, "最终确认后进入可玩的追逐")
	check(not level.has_node("UI_Base/FutureIntroComic"), "漫画关闭后不残留输入遮罩")
	check(level._story_label.text.contains("待清理档案"), "追逐提示衔接寻回记忆的剧情动机")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
