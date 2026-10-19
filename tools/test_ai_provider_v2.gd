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
	check(chat.open_chat(), "聊天正常打开")
	chat._show_settings(true)
	check(chat._key_row.visible and not chat._log.visible, "AI设置独立显示，不挤压聊天界面")
	check(chat.normalize_endpoint("https://api.example.com/v1/") == "https://api.example.com/v1/chat/completions", "兼容基础地址自动补全")
	for invalid: String in ["http://api.example.com/v1", "https://user:password@api.example.com/v1", "https://api.example.com/v1?key=secret", "file:///key"]:
		check(chat.normalize_endpoint(invalid).is_empty(), "拒绝明文HTTP或携带凭据的地址")
	var old_key: String = chat._local_key
	var old_url: String = chat._endpoint
	chat._endpoint_entry.text = "https://api.example.com/v1"
	chat._model_entry.text = "custom-model-id"
	chat._key_entry.clear()
	chat._use_session_key()
	check(chat._endpoint == old_url, "换服务不填写新Key时不沿用旧服务密钥")
	chat._endpoint_entry.text = "https://api.example.com/v1"
	chat._model_entry.text = "custom-model-id"
	chat._key_entry.text = "TEST-ONLY-custom-credential-123"
	chat._use_session_key()
	check(chat._endpoint == "https://api.example.com/v1/chat/completions" and chat._model == "custom-model-id", "接口、模型、密钥作为一组仅本次生效")
	var payload: Dictionary = chat.request_body("现在该做什么？")
	check(payload.model == "custom-model-id" and not payload.has("thinking"), "自定义请求使用所选模型且不附加智谱专用字段")
	check(not chat._status.text.contains("智谱") and not chat._status.text.contains("免费"), "状态不冒称智谱或免费")
	chat._pending_question = "测试"
	chat._on_response(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), '{"error":{"code":"1305"}}'.to_utf8_buffer())
	check(not chat.busy and not chat._fallback_used, "自定义服务不触发智谱模型回退")
	chat._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), '{"choices":[{"message":{"content":"兼容响应"}}]}'.to_utf8_buffer())
	check(chat.history.size() == 2, "兼容响应可显示并保留上下文")
	chat._local_key = old_key
	chat._endpoint = old_url
	chat._model = chat.MODEL
	chat.close_chat()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
