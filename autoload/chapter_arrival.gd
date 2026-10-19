extends Node
## 每次进入关卡：过场结束后居中显示时空坐标，再缩入左上角常驻。

const SETTINGS: Dictionary = {
	"01_hongyadong.tscn": {"place": "重庆 · 洪崖洞吊脚楼外街", "time": "当代 · 雨夜"},
	"02_ciqikou.tscn": {"place": "重庆 · 磁器口江边窑场", "time": "旧时山城 · 汛期傍晚"},
	"03_zhongshan.tscn": {"place": "江津 · 中山古镇码头街", "time": "清末民初 · 雨天"},
	"04_fangdong.tscn": {"place": "重庆 · 渝中防空洞东段", "time": "1941 年 · 警报响起时"},
	"05_hongyadong_return.tscn": {"place": "重庆 · 洪崖洞观景步道", "time": "当代 · 次日清晨"},
	"06_future_chongqing.tscn": {"place": "重庆 · 两江空中步道", "time": "2086 年 · 入夜（未来想象）"},
}
const CARD_SIZE := Vector2(480, 68)
const DOCK_SCALE := 0.5
const ENTER_TIME := 0.3
const HOLD_TIME := 1.7
const DOCK_TIME := 0.85

var _scene: Node
var _root: Control
var _card: PanelContainer
var _place: Label
var _time: Label
var _style: StyleBoxFlat
var _elapsed: float = 0.0
var _started: bool = false
var _active: bool = false
var _docked: bool = false

func _ready() -> void:
	_build_ui()
	get_tree().scene_changed.connect(_on_scene_changed)
	get_viewport().size_changed.connect(_layout_card)
	_on_scene_changed.call_deferred()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ChapterArrivalLayer"
	layer.layer = 17
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	_card = PanelContainer.new()
	_card.name = "TimeAndPlace"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = CARD_SIZE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.02, 0.035, 0.06, 0.7)
	_style.border_color = Color("#cba45d")
	_style.border_width_left = 3
	_style.content_margin_left = 14
	_style.content_margin_right = 14
	_style.content_margin_top = 7
	_style.content_margin_bottom = 7
	_card.add_theme_stylebox_override("panel", _style)
	_root.add_child(_card)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 3)
	_card.add_child(rows)
	_place = Label.new()
	_place.name = "Place"
	_place.add_theme_font_size_override("font_size", 24)
	_place.add_theme_color_override("font_color", Color("#f6d58c"))
	_time = Label.new()
	_time.name = "Time"
	_time.add_theme_font_size_override("font_size", 20)
	_time.add_theme_color_override("font_color", Color("#e0e4e9"))
	for label: Label in [_place, _time]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color("#0b1420"))
		label.add_theme_constant_override("outline_size", 2)
		rows.add_child(label)
	_root.hide()

func _on_scene_changed() -> void:
	_scene = get_tree().current_scene
	_active = false
	_started = false
	_docked = false
	_elapsed = 0.0
	_root.hide()
	if not is_instance_valid(_scene):
		return
	var filename := _scene.scene_file_path.get_file()
	if not _scene.scene_file_path.contains("/guanqia/") or not SETTINGS.has(filename):
		return
	var data: Dictionary = SETTINGS[filename]
	_place.text = str(data["place"])
	_time.text = str(data["time"])
	_style.border_color = Color("#77d7ed") if filename.begins_with("06_") else Color("#cba45d")
	_place.add_theme_color_override("font_color", Color("#a9eaff") if filename.begins_with("06_") else Color("#f6d58c"))
	_active = true
	_layout_card()

func _blocked() -> bool:
	var director := get_node_or_null("/root/StoryDirector")
	if director != null and bool(director.get("busy")):
		return true
	var chat := get_node_or_null("/root/YudengChat")
	if chat != null and bool(chat.get("is_open")):
		return true
	var dialogue := get_node_or_null("/root/DialogueSystem")
	if dialogue != null and bool(dialogue.get("active")):
		return true
	# 第六关漫画结束前不在漫画上播放字幕，也不消耗展示时间。
	return is_instance_valid(_scene) and is_instance_valid(_scene.get_node_or_null("zhujue")) and bool(_scene.get_node("zhujue").get("frozen"))

func is_presenting() -> bool:
	return _active and not _docked

func _process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_scene) or _scene != get_tree().current_scene:
		_root.hide()
		return
	if _blocked():
		_root.hide()
		return
	_root.show()
	_started = true
	_elapsed = minf(_elapsed + delta, ENTER_TIME + HOLD_TIME + DOCK_TIME)
	_layout_card()

func _layout_card() -> void:
	if not is_instance_valid(_card):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var card_size := CARD_SIZE.max(_card.get_combined_minimum_size())
	var intro_scale := minf(1.0, (viewport_size.x - 32.0) / card_size.x)
	var progress := clampf((_elapsed - ENTER_TIME - HOLD_TIME) / DOCK_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var center := (viewport_size - card_size * intro_scale) * 0.5
	_card.size = card_size
	_card.position = center.lerp(Vector2(12, 6), eased)
	_card.scale = Vector2.ONE * lerpf(intro_scale, DOCK_SCALE, eased)
	_card.modulate.a = clampf(_elapsed / ENTER_TIME, 0.0, 1.0)
	_docked = progress >= 1.0
