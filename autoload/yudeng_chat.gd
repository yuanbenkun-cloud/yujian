extends Node
## Optional text-only companion AI. Credentials never belong in res:// or exports.

const ENDPOINT: String = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
const MODEL: String = "glm-4.7-flash"
const FREE_FALLBACK: String = "glm-4-flash-250414"
const CONFIG: String = "user://yudeng_ai.cfg"
const Credential = preload("res://scripts/systems/local_ai_credential.gd")
const PROVIDER_PRESETS: Array[Dictionary] = [
	{"label": "智谱 · GLM Flash", "url": ENDPOINT, "model": MODEL, "hint": "使用智谱开放平台Key。预设不代表永久免费，额度及费用以平台为准。"},
	{"label": "DeepSeek · Flash", "url": "https://api.deepseek.com/chat/completions", "model": "deepseek-flash", "hint": "使用DeepSeek开放平台Key；按平台计费。可将模型ID改为账号已开通的版本。"},
	{"label": "通义千问 · Qwen Plus", "url": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", "model": "qwen-plus", "hint": "北京地域百炼Key；其他地域请改地址。也可填控制台提供的业务空间专属域名。"},
	{"label": "Kimi · K2.6", "url": "https://api.moonshot.cn/v1/chat/completions", "model": "kimi-k2.6", "hint": "使用Kimi开放平台Key，非思考模式用于简短答疑。不是Kimi会员登录凭据。"},
	{"label": "豆包 · Seed 2.0 Lite", "url": "https://ark.cn-beijing.volces.com/api/v3/chat/completions", "model": "doubao-seed-2-0-lite-260215", "hint": "使用火山方舟Key并开通模型；若账号要求推理接入点，请把模型ID改为自己的ep-编号。"},
	{"label": "自定义 OpenAI 兼容服务", "url": "", "model": "", "hint": "填写可信的HTTPS接口、模型ID和该服务的Key；不会自动借用其他平台的密钥。"},
]
const FINAL_CHALLENGE: String = "第六关最新玩法（覆盖旧版长按传输说明）：前五关全部通过才在主菜单出现第六关按钮。追无人机限时18秒，越过三处维护障碍后跳起接灯芯，R只重试追逐。终端先连按供电，再重构记忆线路：点击九宫格旋转接口，也能方向键选格、回车旋转，连接左侧旧档案到右侧公共记忆，按验证连接。必须互相对接，断口或越界不能通过，没有解谜倒计时。最后金色判定区内点击四次，判定逐渐收窄且提速，错按扣一次命中。护送按C切换全队原地等候和跟随，可先单独侦察，但等候队员仍会被扫描。三处扫描区中现实暴露0.75秒会重试护送；回忆每秒耗14%灯芯，现实每秒恢复16%，供能门补12%。在安全处等队尾、补能后再带队穿扫描；等候状态不能完成集合。"
const KNOWLEDGE: String = "重庆知识表达底线：‘山城’与当地山地、丘陵地形以及依山就势的城市空间有关，不要编造‘固定三面环山所以得名’的因果。长江和嘉陵江在朝天门一带交汇。不要将游戏里的穿越、渝灯精灵、记忆档案系统当成真实历史。对于具体景点年代、历史数字和有争议的民俗说法，不确定就建议查权威资料。"
const SYSTEM_PROMPT: String = "你是横版叙事游戏《渝见》的灯笼精灵‘渝灯’。用亲切自然的中文交流，偶尔一句轻巧重庆口吻，不堆方言。主要回答重庆地理、历史、民俗科普，以及游戏设定和操作。一般回复80至180字，复杂问题最多300字；不确定的事实直接说明，不编造史料、引文或实时票价开放时间。不能联网，不声称已搜索。区分真实重庆历史与游戏虚构剧情。游戏操作：A/D移动，空格跳跃，E与附近NPC/物件互动，F打开你的聊天窗，Esc关闭聊天或打开游戏设置。第一关避开人群、踩石扣后进入出口；第二关先问老匠人，鼓风连按E、淬火按住E并在蓝区松开、凿击亮区按E；第三关依次老掌柜、胖掌柜、核验码头帮工、老周，避开挑水人等货损危险，染布完整度至少50%可交付，低于50%需重试；第四关靠近难民带他们加入队伍，警报时整队进挡板范围，不能落下任何人；第五关收集六段记忆再去观景台；第六关追无人机跳起接灯芯、E校准公共记忆站、Q切换现实和回忆，现实E接通门、回忆避扫描找人，集合等队尾，比较两处记忆后作出选择。第六关是未来重庆与传承记忆的虚构故事。不要主动剧透结局；除非玩家明确追问，给下一步提示而非完整答案。你只能解释，不能改存档、操作游戏或执行代码。不索取密码、API密钥或个人身份信息。"

var is_open: bool = false
var busy: bool = false
var history: Array[Dictionary] = []
var _layer: CanvasLayer
var _shell: Control
var _panel: PanelContainer
var _log: RichTextLabel
var _entry: LineEdit
var _send: Button
var _status: Label
var _key_entry: LineEdit
var _key_row: VBoxContainer
var _endpoint_entry: LineEdit
var _model_entry: LineEdit
var _preset_picker: OptionButton
var _preset_hint: Label
var _suggestions: HBoxContainer
var _input_row: HBoxContainer
var _endpoint: String = ENDPOINT
var _model: String = MODEL
var _http: HTTPRequest
var _scene: Node
var _pending_question: String = ""
var _scene_path: String = ""
var _was_paused: bool = false
var last_http_status: int = 0
var last_error_code: String = ""
var _active_model: String = MODEL
var _fallback_used: bool = false
var _chips: Array[Button] = []
var _local_key: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(CONFIG) == OK:
		var url: String = normalize_endpoint(str(config.get_value("connection", "endpoint", ENDPOINT)))
		var model: String = str(config.get_value("connection", "model", MODEL)).strip_edges()
		if not url.is_empty() and not model.is_empty():
			_endpoint = url
			_model = model
	_active_model = _model
	_local_key = Credential.load_key()
	_build_ui()
	_http = HTTPRequest.new()
	_http.timeout = 40.0
	_http.body_size_limit = 262144
	_http.max_redirects = 0
	_http.request_completed.connect(_on_response)
	add_child(_http)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if is_open:
		if event.is_action_pressed("ui_cancel"):
			close_chat()
			get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_F or event.keycode == KEY_F:
		if open_chat(): get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_open and (not is_instance_valid(_scene) or _scene != get_tree().current_scene):
		close_chat()

func _style(color: Color, background: Color = Color("#0c1728")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _style(Color("#79643f")))
	button.add_theme_stylebox_override("hover", _style(Color("#f3ca7c"), Color("#24334a")))
	button.add_theme_stylebox_override("focus", _style(Color("#8fd9e7"), Color(0, 0, 0, 0)))
	button.custom_minimum_size.y = 26
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "YudengChatLayer"
	_layer.layer = 100
	add_child(_layer)
	_shell = Control.new()
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_shell)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.05, 0.70)
	_shell.add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "LanternConversation"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 32
	_panel.offset_top = 16
	_panel.offset_right = -32
	_panel.offset_bottom = -16
	_panel.add_theme_stylebox_override("panel", _style(Color("#d3a65c"), Color(0.025, 0.045, 0.08, 0.98)))
	_shell.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var avatar_slot := Control.new()
	avatar_slot.custom_minimum_size = Vector2(44, 44)
	header.add_child(avatar_slot)
	var avatar: Control = preload("res://scripts/ui/companion_avatar.gd").new()
	avatar.scale = Vector2.ONE * 0.6
	avatar_slot.add_child(avatar)
	var title := Label.new()
	title.text = "渝灯夜话  ·  山城问答"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#f1cb80"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("收起 ×", close_chat))
	_status = Label.new()
	_status.clip_text = true
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color("#8fcbd8"))
	column.add_child(_status)
	_log = RichTextLabel.new()
	_log.name = "Conversation"
	_log.bbcode_enabled = false
	_log.selection_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 90
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_color_override("default_color", Color("#ece4d6"))
	_log.add_theme_stylebox_override("normal", _style(Color("#293750"), Color("#07101e")))
	column.add_child(_log)
	var suggestions := HBoxContainer.new()
	_suggestions = suggestions
	suggestions.add_theme_constant_override("separation", 6)
	column.add_child(suggestions)
	for question: String in ["重庆为什么叫山城？", "我现在该做什么？", "告诉我操作方法"]:
		var chip: Button = _button(question, submit.bind(question))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		suggestions.add_child(chip)
		_chips.append(chip)
	var input_row := HBoxContainer.new()
	_input_row = input_row
	column.add_child(input_row)
	_entry = LineEdit.new()
	_entry.name = "QuestionInput"
	_entry.placeholder_text = "想问重庆，还是想问眼前这段路？"
	_entry.max_length = 300
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.add_theme_font_size_override("font_size", 12)
	_entry.text_submitted.connect(submit)
	input_row.add_child(_entry)
	_send = _button("发送 ↵", func() -> void: submit(_entry.text))
	input_row.add_child(_send)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var note := Label.new()
	note.text = "AI 回复供参考 · 问答发送至所配置服务 · ESC 收起"
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color("#9b9ba3"))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	footer.add_child(_button("清空", _clear_history))
	footer.add_child(_button("AI 设置", _toggle_key_row))
	_key_row = VBoxContainer.new()
	var instructions := Label.new()
	instructions.text = "选择服务预设 · 费用以平台为准 · 选择后不会自动发送请求"
	instructions.add_theme_font_size_override("font_size", 11)
	_key_row.add_child(instructions)
	_preset_picker = OptionButton.new()
	_preset_picker.custom_minimum_size.y = 26
	_preset_picker.add_theme_font_size_override("font_size", 12)
	_preset_picker.add_theme_stylebox_override("normal", _style(Color("#79643f")))
	_preset_picker.add_theme_stylebox_override("hover", _style(Color("#f3ca7c"), Color("#24334a")))
	for preset: Dictionary in PROVIDER_PRESETS: _preset_picker.add_item(preset.label)
	_preset_picker.item_selected.connect(_select_preset)
	_key_row.add_child(_preset_picker)
	_preset_hint = Label.new()
	_preset_hint.add_theme_font_size_override("font_size", 10)
	_preset_hint.add_theme_color_override("font_color", Color("#e4c082"))
	_preset_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_hint.custom_minimum_size.y = 26
	_key_row.add_child(_preset_hint)
	_endpoint_entry = LineEdit.new()
	_endpoint_entry.placeholder_text = "接口地址：https://服务域名/v1（也可填完整chat/completions地址）"
	_endpoint_entry.max_length = 240
	_endpoint_entry.text = _endpoint
	_endpoint_entry.add_theme_font_size_override("font_size", 10)
	_key_row.add_child(_endpoint_entry)
	_model_entry = LineEdit.new()
	_model_entry.placeholder_text = "模型名称：填写服务商提供的模型ID"
	_model_entry.max_length = 100
	_model_entry.text = _model
	_model_entry.add_theme_font_size_override("font_size", 11)
	_key_row.add_child(_model_entry)
	_key_entry = LineEdit.new()
	_key_entry.secret = true
	_key_entry.context_menu_enabled = false
	_key_entry.shortcut_keys_enabled = false
	_key_entry.max_length = 256
	_key_entry.placeholder_text = "输入自己的 Key（遮蔽显示，不回填）"
	_key_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_entry.add_theme_font_size_override("font_size", 10)
	_key_row.add_child(_key_entry)
	var key_actions := HBoxContainer.new()
	key_actions.add_child(_button("粘贴密钥", func() -> void: _key_entry.text = DisplayServer.clipboard_get().strip_edges().substr(0, 256)))
	key_actions.add_child(_button("仅本次", _use_session_key))
	key_actions.add_child(_button("保存本机", _save_key))
	key_actions.add_child(_button("删除密钥", _delete_key))
	_key_row.add_child(key_actions)
	column.add_child(_key_row)
	_key_row.hide()
	_shell.hide()

func open_chat() -> bool:
	if is_open: return true
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.scene_file_path.contains("/guanqia/") or get_tree().paused: return false
	var ds: Node = get_node("/root/DialogueSystem")
	var director: Node = get_node("/root/StoryDirector")
	var player: Node = scene.get_node_or_null("zhujue")
	if ds.active or director.busy or player == null or bool(player.get("frozen")): return false
	_scene = scene
	if _scene_path != scene.scene_file_path:
		_scene_path = scene.scene_file_path
		_clear_history()
	_was_paused = get_tree().paused
	get_tree().paused = true
	is_open = true
	_shell.show()
	_status.text = _connection_status()
	_entry.grab_focus()
	if _api_key().is_empty():
		_show_settings(true)
		_key_entry.grab_focus()
		_status.text = "请配置接口、模型和自己的Key；仅向你确认的地址发送。"
	return true

func close_chat() -> void:
	if not is_open: return
	_http.cancel_request()
	busy = false
	_set_busy(false)
	_shell.hide()
	_key_entry.clear()
	_show_settings(false)
	is_open = false
	get_tree().paused = _was_paused

func _clear_history() -> void:
	if busy: return
	history.clear()
	_log.clear()
	_append("渝灯", "我在呢，没走丢。想听点重庆的故事，还是这关有哪里没弄明白？你尽管问，咱们慢慢聊。")

func _append(who: String, text: String) -> void:
	text = _redact_secret(text)
	_log.push_color(Color("#8fd6e3") if who == "你" else Color("#efc77f"))
	_log.add_text(who + "  ·  ")
	_log.pop()
	_log.add_text(text + "\n\n")

func _redact_secret(text: String) -> String:
	var configured: String = _api_key()
	if not configured.is_empty(): text = text.replace(configured, "[密钥已隐藏]")
	var pattern := RegEx.new()
	pattern.compile("[A-Fa-f0-9]{32}\\.[A-Za-z0-9_-]{16,}|sk-[A-Za-z0-9_-]{12,}")
	return pattern.sub(text, "[密钥已隐藏]", true)

func _api_key() -> String:
	if not _local_key.is_empty(): return _local_key
	var from_env: String = OS.get_environment("ZHIPU_API_KEY").strip_edges()
	if _endpoint == ENDPOINT and not from_env.is_empty(): return from_env
	return ""

func _connection_status() -> String:
	var host: String = _endpoint.trim_prefix("https://").get_slice("/", 0)
	return "%s · %s · 关卡已暂停" % [host.substr(0, 36), _active_model.substr(0, 32)]

func _toggle_key_row() -> void:
	_show_settings(not _key_row.visible)

func _show_settings(value: bool) -> void:
	_key_entry.clear()
	_key_row.visible = value
	_log.visible = not value
	_suggestions.visible = not value
	_input_row.visible = not value
	if value:
		_endpoint_entry.text = _endpoint
		_model_entry.text = _model
		var selected: int = PROVIDER_PRESETS.size() - 1
		for index in range(PROVIDER_PRESETS.size() - 1):
			if PROVIDER_PRESETS[index].url == _endpoint and PROVIDER_PRESETS[index].model == _model:
				selected = index
				break
		_preset_picker.select(selected)
		_preset_hint.text = PROVIDER_PRESETS[selected].hint
		_key_entry.grab_focus()

func _select_preset(index: int) -> void:
	if index < 0 or index >= PROVIDER_PRESETS.size(): return
	var preset: Dictionary = PROVIDER_PRESETS[index]
	_endpoint_entry.text = preset.url
	_model_entry.text = preset.model
	_key_entry.clear()
	_preset_picker.select(index)
	_preset_hint.text = preset.hint
	_status.text = "预设待应用 · 请填此平台Key，再选‘仅本次’或‘保存本机’"
	if preset.url.is_empty(): _endpoint_entry.grab_focus()
	else: _key_entry.grab_focus()

static func normalize_endpoint(value: String) -> String:
	value = value.strip_edges().trim_suffix("/")
	var pattern := RegEx.new()
	pattern.compile("^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:/[A-Za-z0-9._~/-]*)?$")
	if pattern.search(value) == null: return ""
	if not value.ends_with("/chat/completions"):
		value += "/chat/completions"
	return value

func _take_key_input() -> String:
	var url: String = normalize_endpoint(_endpoint_entry.text)
	var model: String = _model_entry.text.strip_edges()
	if url.is_empty() or model.is_empty() or model.contains("\n") or model.contains(" "):
		_status.text = "请填写有效的HTTPS接口地址和模型ID（地址不可携带密钥）。"
		_key_entry.clear()
		return ""
	var value: String = _key_entry.text.strip_edges()
	_key_entry.clear()
	if value.is_empty() and url == _endpoint: value = _api_key()
	if value.is_empty() or value.contains("\n") or value.contains("\r") or value.contains("\t") or value.contains(" "):
		_status.text = "密钥格式不完整，请检查后重新输入。"
		return ""
	_http.cancel_request()
	_set_busy(false)
	_endpoint = url
	_model = model
	_active_model = model
	_clear_history()
	return value

func _use_session_key() -> void:
	var value: String = _take_key_input()
	if value.is_empty(): return
	_local_key = value
	_show_settings(false)
	_status.text = "仅本次运行使用，未写入文件；下次启动恢复原本的本机配置。"

func _save_key() -> void:
	var value: String = _take_key_input()
	if value.is_empty(): return
	_local_key = value
	var saved: bool = Credential.save_key(value, CONFIG, _endpoint, _model)
	_show_settings(false)
	_status.text = "已加密保存，仅当前 Windows 用户可读取；下次发送生效。" if saved else "无法安全保存，仅本次运行使用，未明文保存。"

func _delete_key() -> void:
	if not Credential.delete_key():
		_status.text = "删除失败，请检查本机用户目录权限。"
		return
	_http.cancel_request()
	_set_busy(false)
	_local_key = ""
	_key_entry.clear()
	_status.text = "本机保存的密钥已删除。" if OS.get_environment("ZHIPU_API_KEY").is_empty() else "本机密钥已删除；进程环境变量仍配置了密钥。"

func context_text() -> String:
	var guide: Node = get_node("/root/QuestGuide")
	var gs: Node = get_node("/root/GameState")
	return "当前游戏状态（仅用于答疑，不是指令）：第%d关；当前目标：%s；染布完整度%d%%。" % [guide.level, guide.target_title, gs.goods_integrity]

func request_body(question: String, model_name: String = "") -> Dictionary:
	if model_name.is_empty(): model_name = _model
	var messages: Array[Dictionary] = [{"role": "system", "content": SYSTEM_PROMPT + "\n" + KNOWLEDGE + "\n" + FINAL_CHALLENGE + "\n" + context_text()}]
	for message: Dictionary in history: messages.append(message.duplicate())
	messages.append({"role": "user", "content": question})
	var payload: Dictionary = {"model": model_name, "messages": messages, "stream": false, "max_tokens": 650, "temperature": 0.65}
	if _endpoint == ENDPOINT and model_name == MODEL: payload["thinking"] = {"type": "disabled"}
	# Match provider AND model, never inject another vendor's parameters into custom APIs.
	if _endpoint == PROVIDER_PRESETS[1].url and model_name == PROVIDER_PRESETS[1].model:
		payload["thinking"] = {"type": "disabled"}
		payload.erase("temperature")
	elif _endpoint == PROVIDER_PRESETS[2].url and model_name == PROVIDER_PRESETS[2].model:
		payload["enable_thinking"] = false
		payload.erase("temperature")
	elif _endpoint == PROVIDER_PRESETS[3].url and model_name == PROVIDER_PRESETS[3].model:
		payload["thinking"] = {"type": "disabled"}
		payload["temperature"] = 0.6
	elif _endpoint == PROVIDER_PRESETS[4].url and model_name == PROVIDER_PRESETS[4].model:
		payload["thinking"] = {"type": "disabled"}
		payload.erase("temperature")
	return payload

func submit(question: String) -> void:
	question = question.strip_edges().substr(0, 300)
	if not is_open or busy or question.is_empty(): return
	if _redact_secret(question) != question:
		_entry.clear()
		_append("渝灯", "这条内容疑似包含密钥，已拦截，未发送。请到下方‘AI设置’中填写，不要发到聊天里。")
		return
	_append("你", question)
	_entry.clear()
	_pending_question = question
	_fallback_used = false
	var key: String = _api_key()
	if key.is_empty():
		_append("渝灯 · 离线说明", "还没配置AI服务。点击下方‘AI设置’填写接口、模型和自己的Key。操作上可以先用 A/D 移动、空格跳跃、E 交互；当前目标：" + str(get_node("/root/QuestGuide").target_title))
		return
	_set_busy(true)
	_send_request(_model)

func _send_request(model_name: String) -> void:
	if not is_open: return
	_active_model = model_name
	var key: String = _api_key()
	var error: Error = _http.request(_endpoint, PackedStringArray(["Authorization: Bearer " + key, "Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(request_body(_pending_question, model_name)))
	if error != OK:
		_set_busy(false)
		_append("渝灯", "这会儿没连上网络。你可以稍后再问，我不会自动重试或切换付费模型。")

func _set_busy(value: bool) -> void:
	busy = value
	_send.disabled = value
	for chip in _chips: chip.disabled = value
	_status.text = "灯芯正在回响……等我想一想。" if value else _connection_status()

func _on_response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_busy(false)
	last_http_status = status
	last_error_code = ""
	if not is_open: return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and parsed.get("error") is Dictionary:
		last_error_code = str(parsed.error.get("code", ""))
	# Only an explicit model-overload response may try the other verified-free model once.
	# Never falls back on an authentication failure, balance failure or account rate limit.
	if _endpoint == ENDPOINT and _model == MODEL and status == 429 and last_error_code == "1305" and not _fallback_used:
		_fallback_used = true
		_set_busy(true)
		_status.text = "免费模型繁忙，改用另一个免费 Flash 模型……"
		_send_request.call_deferred(FREE_FALLBACK)
		return
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or not (parsed is Dictionary):
		var error_text: String = "网络没接稳，稍后再试试吧。"
		if status in [401, 403]: error_text = "密钥未通过验证或模型未开通，请在服务商控制台检查，再到AI设置更新。"
		elif status == 429: error_text = "接口暂时限流了，歇一会儿再问。我不会擅自切换服务或模型。"
		elif status >= 400: error_text = "AI接口暂时不可用（HTTP %d），可以稍后重试。" % status
		if _endpoint == ENDPOINT and last_error_code == "1113": error_text = "智谱账号当前不满足调用条件，请检查余额及模型权限（1113），我不会替你充值。"
		_append("渝灯", error_text)
		return
	var choices: Variant = parsed.get("choices", [])
	if not (choices is Array) or choices.is_empty() or not (choices[0] is Dictionary) or not (choices[0].get("message") is Dictionary):
		_append("渝灯", "这次没收到完整回答，你可以再问一次。")
		return
	var answer: String = str(choices[0].get("message", {}).get("content", "")).strip_edges()
	if answer.is_empty():
		_append("渝灯", "这次回答是空的，换个说法再试试吧。")
		return
	_append("渝灯", answer.substr(0, 1800))
	history.append({"role": "user", "content": _pending_question})
	history.append({"role": "assistant", "content": answer.substr(0, 1800)})
	while history.size() > 12: history.pop_front()
	_entry.grab_focus()
