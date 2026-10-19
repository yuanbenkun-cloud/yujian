extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var original_flags: Dictionary = state.insight_flags.duplicate(true)
	var textures: Array[String] = []
	var choices: Array[String] = ["archive", "overwrite", "living"]
	if OS.get_cmdline_user_args().size() > 0:
		choices.assign(OS.get_cmdline_user_args())
	for choice: String in choices:
		change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
		await create_timer(0.3).timeout
		var level: Node = current_scene
		level._start_chase()
		level.stage = level.Stage.FINALE
		level._confirm_memory_gate("real")
		check(level._ending_panel.visible and level._ending_art_layer == null, "选择前不泄露结局插图")
		level._finish_future(choice)
		await create_timer(0.7).timeout
		var art: TextureRect = level._ending_art
		check(art.texture != null and art.texture.resource_path.ends_with("/%s.png" % choice), "%s 加载对应独立插图" % choice)
		textures.append(art.texture.resource_path if art.texture != null else "")
		check(level._ending_art_layer.layer > 20 and art.modulate == Color.WHITE, "%s 插图不受历史蓝幕染色" % choice)
		check(art.get_global_rect().encloses(root.get_visible_rect()), "%s 插图覆盖完整视口" % choice)
		check(level._story_panel.visible and not level._story_label.text.is_empty(), "%s 结局文案持续可见" % choice)
		check(level._return_button.get_parent() == level._ending_art_layer, "%s 返回按钮在插图上方" % choice)
		check(not level._story_label.text.contains("E / ENTER"), "文字与返回按钮分开排版")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://preview/future-ending-%s-v1.png" % choice)
	if choices.size() == 3:
		check(textures.size() == 3 and textures[0] != textures[1] and textures[1] != textures[2], "三个结局具有不同插图资源")
	state.insight_flags = original_flags
	state._save_story()
	current_scene._ending_shown_at = Time.get_ticks_msec() - 1000
	current_scene._return_button.pressed.emit()
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path == "res://scenes/kaishi.tscn", "结局返回主界面正常")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
