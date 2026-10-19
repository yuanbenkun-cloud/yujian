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
	var chat: Node = root.get_node("YudengChat")
	var player: Node = current_scene.get_node("zhujue")
	player.frozen = false
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	check(chat.is_open and paused, "F打开聊天并暂停关卡")
	check(chat._log.get_parsed_text().contains("我在呢"), "渝灯主动问候并询问问题")
	check(chat._entry.has_focus(), "输入框自动聚焦")
	var request: Dictionary = chat.request_body("这一关怎么过？")
	check(request.model == "glm-4.7-flash" and request.messages[0].content.contains("至少50%"), "固定免费模型并注入最新游戏规则")
	check(not JSON.stringify(request).contains("api_key"), "密钥不进入对话正文")
	if "live" in OS.get_cmdline_user_args():
		chat.submit("重庆为什么叫山城？用两句中文回答。")
		check(chat.busy, "真实接口请求已发起")
		var elapsed: float = 0.0
		while chat.busy and elapsed < 45:
			await create_timer(0.2, true).timeout
			elapsed += 0.2
		check(chat.history.size() == 2, "智谱真实回答已返回并进入会话上下文")
		if chat.history.size() != 2: print("API_DIAGNOSTIC status=", chat.last_http_status, " code=", chat.last_error_code)
		if chat.history.size() == 2: print("LIVE_REPLY: ", chat.history[1].content)
	else:
		chat._pending_question = "测试问题"
		chat._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"choices": [{"message": {"content": "测试回答：E交互，空格跳跃。"}}]}).to_utf8_buffer())
		check(chat.history.size() == 2, "模拟响应正确显示并维护上下文")
		chat._on_response(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), "{}".to_utf8_buffer())
		check(chat._log.get_parsed_text().contains("限流"), "限流给出友好说明，不切付费模型")
	await create_timer(0.2, true).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview/yudeng-ai-chat-v1.png")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	check(not chat.is_open and not paused, "Esc只关闭聊天并恢复关卡，不打开设置")
	check(root.get_node("Accessibility")._layer == null, "设置菜单未被同时触发")
	player.frozen = true
	check(not chat.open_chat(), "剧情冻结期间不抢占对话")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
