extends Node
## Task selection is event-driven. Only marker projection and hint fade run each frame.

const LEVEL_HINTS: Array[String] = [
	"A / D 移动 · SPACE 跳跃 · 靠近目标按 E\n避开人群，沿路寻找石扣和出口。",
	"靠近当前工位按 E · 鼓风连按，淬火按住\n凿击时等指针进入亮区，再按 E。",
	"靠近箭头下的人按 E · 先听交代，再护送染布\n按顺序交接，留意路上的货物风险。",
	"跟着前方发光的渝灯，沿路带上避难者\n警报响时带着整队进入挡板保护区。",
	"靠近记忆人物或物件按 E · 找齐六段记忆\n箭头会指向尚未完成的探索。",
	"A / D 移动 · SPACE 跳跃 · E 交互\n跟随当前目标，寻回记忆后再作选择。",
]
var _scene: Node
var _player: Node2D
var level: int = 0
var target: Node2D
var target_title: String = ""
var _height: float = 96.0
var _layer: CanvasLayer
var _arrow: Polygon2D
var _tag: Label
var _toast: PanelContainer
var _text: Label
var _remaining: float = 0.0
var _seen: Dictionary = {}
var _signature: String = ""
var _pending_hint: String = ""
var _elapsed: float = 0.0

func _ready() -> void:
	_build_ui()
	get_node("/root/DialogueSystem").ended.connect(request_refresh)
	RenderingServer.frame_pre_draw.connect(_project_marker)

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "QuestGuideLayer"
	_layer.layer = 19
	add_child(_layer)
	_arrow = Polygon2D.new()
	_arrow.name = "TaskArrow"
	_arrow.polygon = PackedVector2Array([Vector2(-6, -5), Vector2(6, -5), Vector2(0, 3)])
	_arrow.color = Color("#ffe298")
	_layer.add_child(_arrow)
	_tag = Label.new()
	_tag.name = "TaskTarget"
	_tag.size = Vector2(180, 17)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override("font_size", 10)
	_tag.add_theme_color_override("font_color", Color("#ffe298"))
	_tag.add_theme_color_override("font_outline_color", Color("#101923"))
	_tag.add_theme_constant_override("outline_size", 3)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tag)
	_toast = PanelContainer.new()
	_toast.name = "TemporaryOperationHint"
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -195
	_toast.offset_right = 195
	_toast.offset_top = 104
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.07, 0.88)
	style.border_color = Color("#b69353")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	_toast.add_theme_stylebox_override("panel", style)
	_layer.add_child(_toast)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(360, 30)
	_text.add_theme_font_size_override("font_size", 11)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(_text)
	_layer.hide()

func _process(delta: float) -> void:
	_elapsed += delta
	var scene: Node = get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_player = null
		level = 0
		target = null
		_seen.clear()
		_signature = ""
		_pending_hint = ""
		_remaining = 0
		if is_instance_valid(scene) and scene.scene_file_path.contains("/guanqia/"):
			for i in range(1, 7):
				if scene.scene_file_path.get_file().begins_with("%02d_" % i): level = i
			_player = scene.get_node_or_null("zhujue") as Node2D
			if level == 6 and not scene.has_node("EscortRendezvous"):
				var rendezvous := Node2D.new()
				rendezvous.name = "EscortRendezvous"
				rendezvous.position = Vector2(2460, 282)
				scene.add_child(rendezvous)
			request_refresh()
	var blocked: bool = not is_instance_valid(_player) or get_node("/root/Companion").guidance_blocked()
	var arrival := get_node_or_null("/root/ChapterArrival")
	if arrival != null and bool(arrival.call("is_presenting")):
		blocked = true
	_layer.visible = not blocked
	if blocked: return
	if not _pending_hint.is_empty():
		_text.text = _pending_hint
		_pending_hint = ""
		_remaining = 5.0
	_remaining = maxf(0.0, _remaining - delta)
	_toast.visible = _remaining > 0
	_toast.modulate.a = minf(1.0, _remaining / 0.5)

func request_refresh() -> void:
	refresh.call_deferred()

func _node(path: String) -> Node:
	return _scene.get_node_or_null(path) if is_instance_valid(_scene) else null

func _set_target(path: String, title: String, height: float = 96.0) -> void:
	target = _node(path) as Node2D
	target_title = title
	_height = height

func refresh() -> void:
	if not is_instance_valid(_scene) or not _scene.is_inside_tree() or _scene != get_tree().current_scene or level == 0: return
	target = null
	var hint: String = LEVEL_HINTS[level - 1]
	match level:
		1:
			var stone: Node = _node("diyiguan_husongdizhuan")
			if stone != null and not bool(stone.get("_triggered")):
				_set_target("diyiguan_husongdizhuan", "路边石扣", 45)
			else:
				_set_target("FirstExitPortal", "向前寻找出口", 100)
		2:
			var artisan: Node = _node("laojiangren")
			var forge: Node = _node("ForgeSequence")
			if artisan != null and not bool(artisan.get("_completed")):
				_set_target("laojiangren", "先问问老匠人")
				hint = "先靠近老匠人，按 E 听听他的办法\n对话结束后，箭头会指向当前工位。"
			elif forge != null:
				var step: int = int(forge.get("current_step"))
				if step < 3:
					_set_target(["HeatStation", "QuenchStation", "di_erguan_yanbi"][step], ["鼓风工位", "淬火工位", "凿开岩壁"][step], 125)
					hint = ["鼓风：靠近窑炉按 E，再连续按 E\n把炉温推入橙区，留意过热。", "淬火：靠近水槽按 E，随后按住 E\n进入蓝区及时松开，水阻会变化。", "凿击：靠近岩壁按 E\n等指针进入裂纹亮区，再按 E。 "][step]
				else:
					_set_target("dierguan_chukou", "岩壁已通 · 前往出口")
		3:
			var route: Node = _node("ChoiceSystem")
			var step: int = int(route.get("stage")) if route != null else 0
			_set_target(["laozhanggui", "pangzhanggui", "banggong", "laozhou", "disanguan_chukou"][clampi(step, 0, 4)], ["听老掌柜交代", "经过茶馆街口", "核验码头帮工", "把染布交给老周", "托付完成 · 出口"][clampi(step, 0, 4)])
		4:
			var group: Node = _node("NPC_Group")
			if group != null:
				for npc in group.get_children():
					if npc is Node2D and npc.has_meta("rescue_stage") and not bool(npc.get_meta("rescued", false)):
						target = npc
						target_title = "带上避难者"
						_height = 96
						break
			if target == null: _set_target("disiguan_chukou", "带整队走向洞口")
			for i in range(1, 4):
				var old: CanvasItem = _node("RescueMarker%d" % i) as CanvasItem
				if old != null: old.hide()
		5:
			var route: Node = _node("MemoryRoute")
			var collected: Dictionary = route.get("collected") if route != null else {}
			var ids: Array[String] = ["board", "old_man", "wall", "flyer", "view", "lights"]
			var paths: Array[String] = ["diwuguan_mupai", "jianglishilaoren", "diwuguan_jiuchengqiang", "chuandanayi", "diwuguan_jingguandian", "diwuguan_denghuo"]
			for i in range(ids.size()):
				if not collected.has(ids[i]):
					_set_target(paths[i], "未寻回的城市记忆", 110)
					break
			if target == null: _set_target("diwuguan_zhaoxiangdian", "记忆齐了 · 前往观景台", 110)
		6:
			var stage: int = int(_scene.get("stage"))
			match stage:
				1:
					if int(_scene.get("memory_shards")) == 0: _set_target("MemoryDrone", "跳起接回灯芯", 35)
					else: _set_target("MemoryTerminal", "E · 公共记忆站", 140)
				3:
					var candidates: Array[Node2D] = []
					for npc: Node2D in _scene.get("_civilians"):
						if not bool(npc.get("recruited")): candidates.append(npc)
					for gate: Area2D in _scene.get("_power_gates"):
						if not bool(gate.get("powered")): candidates.append(gate)
					for candidate in candidates:
						if target == null or candidate.position.x < target.position.x: target = candidate
					if target != null:
						var is_gate: bool = target.has_method("is_interaction_available")
						target_title = "现实区 E · 接通门" if is_gate else "回忆区 · 找到记忆中的人"
						_height = 185 if is_gate else 96
						hint = "Q 切换现实／回忆 · 现实区 E 接通门\nC 队伍等候／跟随 · 在安全处补能再带队穿扫描。"
					else:
						_set_target("EscortRendezvous", "集合点 · 等待队尾")
				4:
					var observed: Dictionary = _scene.get("_visited_gates")
					_set_target("PerfectReplica" if not observed.has("fake") else "LivingMemory", "观察两处记忆，再作选择", 140)
	var signature: String = str(target.get_instance_id()) if is_instance_valid(target) else "none"
	if signature != _signature:
		_signature = signature
		if not _seen.has(signature) and target != null:
			_seen[signature] = true
			_pending_hint = hint if _seen.size() == 1 or level in [2, 4, 6] else "当前目标：%s\n靠近目标进行下一步操作。" % target_title
			if _seen.size() == 1:
				_pending_hint += "\nF 召唤渝灯 · 重庆科普 / 玩法答疑"

func _project_marker() -> void:
	if not is_instance_valid(_layer) or not _layer.visible: return
	var valid: bool = is_instance_valid(target) and target.is_inside_tree() and (target.is_visible_in_tree() or level == 6)
	_arrow.visible = valid
	_tag.visible = valid
	if not valid: return
	var size: Vector2 = get_viewport().get_visible_rect().size
	var point: Vector2 = target.get_global_transform_with_canvas() * Vector2(0, -_height)
	var offscreen: bool = point.x < 18 or point.x > size.x - 18
	_arrow.rotation = (-PI / 2 if point.x > size.x - 18 else PI / 2) if offscreen else 0.0
	_arrow.position = Vector2(clampf(point.x, 18, size.x - 18), clampf(point.y, 125, size.y - 88))
	_arrow.position.y += sin(_elapsed * 3) * 2
	_tag.position = Vector2(clampf(_arrow.position.x - 90, 8, size.x - 188), _arrow.position.y - 25)
	_tag.text = target_title

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_project_marker):
		RenderingServer.frame_pre_draw.disconnect(_project_marker)
