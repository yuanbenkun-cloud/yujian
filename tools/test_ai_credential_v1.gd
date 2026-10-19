extends SceneTree

const Store = preload("res://scripts/systems/local_ai_credential.gd")
const TEST_PATH: String = "user://credential-security-test.cfg"
var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	var dummy: String = "TEST-ONLY-credential-not-a-real-api-key"
	check(Store.save_key(dummy, TEST_PATH), "Windows用户加密保存")
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var stored: String = file.get_as_text() if file != null else ""
	file = null
	check(not stored.contains(dummy) and stored.contains("dpapi_current_user"), "文件不含明文密钥")
	check(Store.load_key(TEST_PATH) == dummy, "当前用户可解密回读")
	var cfg := ConfigFile.new()
	cfg.load(TEST_PATH)
	cfg.set_value("connection", "endpoint", "https://another.example/v1/chat/completions")
	cfg.save(TEST_PATH)
	check(Store.load_key(TEST_PATH).is_empty(), "修改配置地址不能将旧Key转发到另一个服务")
	check(Store.delete_key(TEST_PATH) and not FileAccess.file_exists(TEST_PATH), "可删除测试密钥")
	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await create_timer(0.4).timeout
	current_scene.get_node("zhujue").frozen = false
	var chat: Node = root.get_node("YudengChat")
	check(chat.open_chat(), "聊天可打开")
	check(chat._key_entry.secret and not chat._key_entry.context_menu_enabled and not chat._key_entry.shortcut_keys_enabled, "遮蔽输入并禁用复制快捷键和右键菜单")
	chat._toggle_key_row()
	chat._key_entry.text = dummy
	chat._toggle_key_row()
	check(chat._key_entry.text.is_empty(), "收起密钥设置立即清空输入")
	var previous: String = chat._local_key
	chat._key_entry.text = dummy
	chat._use_session_key()
	check(chat._api_key() == dummy and chat._key_entry.text.is_empty(), "仅本次使用且清空输入")
	chat.submit(dummy)
	check(not chat.busy and chat.history.is_empty() and not chat._log.get_parsed_text().contains(dummy), "误发密钥会被拦截且不显示")
	chat._local_key = previous
	chat.close_chat()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
