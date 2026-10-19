extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await create_timer(0.4).timeout
	current_scene.get_node("zhujue").frozen = false
	var chat: Node = root.get_node("YudengChat")
	chat.open_chat()
	var old: Dictionary = {"url": chat._endpoint, "model": chat._model, "key": chat._local_key}
	for index in range(chat.PROVIDER_PRESETS.size() - 1):
		chat._show_settings(true)
		var prior_url: String = chat._endpoint
		chat._key_entry.text = "TEST-DRAFT-key"
		chat._preset_picker.item_selected.emit(index)
		var preset: Dictionary = chat.PROVIDER_PRESETS[index]
		check(chat._endpoint_entry.text == preset.url and chat._model_entry.text == preset.model, "自动填写官方地址和模型：" + str(preset.label))
		check(chat._key_entry.text.is_empty() and chat._endpoint == prior_url and not chat.busy, "选预设清空输入、不立即生效或发请求")
		chat._key_entry.text = "TEST-ONLY-provider-credential"
		chat._use_session_key()
		var payload: Dictionary = chat.request_body("测试")
		check(payload.model == preset.model and chat._endpoint == preset.url, "应用后请求使用所选服务：" + str(preset.label))
		if index == 2: check(payload.get("enable_thinking") == false, "千问使用非思考答疑")
		if index == 3: check(is_equal_approx(payload.temperature, 0.6), "Kimi使用官方允许的非思考温度")
		if index in [1, 4]: check(not payload.has("temperature"), "避免不兼容采样参数")
	chat._show_settings(true)
	chat._select_preset(chat.PROVIDER_PRESETS.size() - 1)
	check(chat._endpoint_entry.text.is_empty() and chat._model_entry.text.is_empty(), "自定义仍可填写其他兼容服务")
	chat._select_preset(1)
	await create_timer(0.25).timeout
	check(chat._key_row.get_global_rect().end.y <= 344, "预设及平台提示在640x360视口范围内")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/ai-mainstream-presets-v3.png")
	chat._endpoint = old.url
	chat._model = old.model
	chat._local_key = old.key
	chat.close_chat()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
