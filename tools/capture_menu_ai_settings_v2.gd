extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _capture(path: String) -> void:
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)

func _run() -> void:
	change_scene_to_file("res://scenes/kaishi.tscn")
	await create_timer(0.2).timeout
	var locked: bool = current_scene.find_child("FutureButton", true, false) == null
	print("[PASS] 当前旧存档不再展示第六关" if locked else "[FAIL] 当前存档仍解锁")
	await _capture("res://preview/menu-verified-clears-v2.png")
	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await create_timer(0.3).timeout
	current_scene.get_node("zhujue").frozen = false
	var chat: Node = root.get_node("YudengChat")
	chat.open_chat()
	chat._show_settings(true)
	await _capture("res://preview/ai-provider-settings-v2.png")
	var fits: bool = chat._key_row.get_global_rect().end.y <= 344.0
	print("[PASS] AI设置在640x360视口范围内" if fits else "[FAIL] AI设置超出视口")
	chat.close_chat()
	quit(0 if locked and fits else 1)
