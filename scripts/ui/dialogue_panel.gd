class_name DialoguePanel
extends Control

## 双立绘对话框（V2）：底部文字框 + 左右两侧角色立绘。
## 说话方高亮；另一方变暗；旁白/独白等叙述行两侧变灰。

signal advance_requested
signal line_completed

const VIEW_SIZE := Vector2(640, 360)
const BOX_TOP := 248.0
const PT_W := 124.0
const PT_H := 174.0
const INPUT_GUARD_MSEC := 120

const PORTRAITS := {
	"陈默": ["res://assets/production/portraits/chenmo-v2.png", true],
	"传单阿姨": ["res://assets/production/npc/cast_v3/flyer_lady/portrait.png", false],
	"游客甲": ["res://assets/production/npc/cast_v3/tourist/portrait.png", false],
	"游客": ["res://assets/production/npc/cast_v3/tourist/portrait.png", false],
	"摊贩": ["res://assets/production/npc/cast_v3/vendor/portrait.png", false],
	"讲历史老人": ["res://assets/production/npc/cast_v3/old_man/portrait.png", false],
	"老人": ["res://assets/production/npc/cast_v3/old_man/portrait.png", false],
	"老匠人": ["res://assets/production/npc/cast_v3/old_artisan/portrait.png", false],
	"阿明": ["res://assets/production/npc/cast_v3/aming/portrait.png", false],
	"老掌柜": ["res://assets/production/npc/cast_v3/old_shopkeeper/portrait.png", false],
	"胖掌柜": ["res://assets/production/npc/cast_v3/fat_teahouse/portrait.png", false],
	"码头帮工": ["res://assets/production/npc/cast_v3/helper/portrait.png", false],
	"帮工": ["res://assets/production/npc/cast_v3/helper/portrait.png", false],
	"老周": ["res://assets/production/npc/cast_v3/laozhou/portrait.png", false],
	"避难群众": ["res://assets/production/npc/cast_v3/refugee/portrait.png", false],
}

var _typing: bool = false
var _line_full: String = ""
var _shown: int = 0
var _waiting: bool = false
var _opts_shown: bool = false
var _input_guard_until := 0

var _bg: ColorRect
var _frame: Panel
var _name_lb: Label
var _text_lb: Label
var _continue_lb: Label
var _opts_box: VBoxContainer
var _timer: Timer
var _pt_left: TextureRect      # NPC 侧
var _pt_right: TextureRect     # 陈默侧
var _pt_left_tex: Texture2D = null
var _pt_right_tex: Texture2D = null

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	position = Vector2.ZERO
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.name = "LowerShade"
	_bg.color = Color(0.015, 0.025, 0.05, 0.72)
	_bg.position = Vector2(0, 226)
	_bg.size = Vector2(640, 134)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_pt_left = _make_portrait(Vector2(4, 178), false)
	_pt_right = _make_portrait(Vector2(640.0 - 4.0 - PT_W, 178), true)
	_frame = Panel.new()
	_frame.name = "DialogueFrame"
	_frame.position = Vector2(118, BOX_TOP)
	_frame.size = Vector2(404, 102)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.025, 0.04, 0.075, 0.96)
	frame_style.border_color = Color(0.84, 0.62, 0.28, 0.82)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(5)
	_frame.add_theme_stylebox_override("panel", frame_style)
	add_child(_frame)
	_name_lb = Label.new()
	_name_lb.position = Vector2(136, 256)
	_name_lb.size = Vector2(350, 20)
	_name_lb.add_theme_font_size_override("font_size", 13)
	_name_lb.add_theme_color_override("font_color", Color("#f1bd59"))
	add_child(_name_lb)
	_text_lb = Label.new()
	_text_lb.position = Vector2(136, 279)
	_text_lb.size = Vector2(366, 55)
	_text_lb.add_theme_font_size_override("font_size", 12)
	_text_lb.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
	_text_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text_lb)
	_continue_lb = Label.new()
	_continue_lb.name = "ContinueHint"
	_continue_lb.text = "E  继续  ›"
	_continue_lb.position = Vector2(432, 329)
	_continue_lb.size = Vector2(72, 16)
	_continue_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_lb.add_theme_font_size_override("font_size", 10)
	_continue_lb.add_theme_color_override("font_color", Color(0.67, 0.73, 0.82))
	_continue_lb.visible = false
	add_child(_continue_lb)
	_opts_box = VBoxContainer.new()
	_opts_box.position = Vector2(136, 142)
	_opts_box.size = Vector2(368, 0)
	_opts_box.add_theme_constant_override("separation", 5)
	_opts_box.visible = false
	add_child(_opts_box)
	_timer = Timer.new()
	_timer.wait_time = 0.03
	_timer.one_shot = false
	_timer.timeout.connect(_type_tick)
	add_child(_timer)

func _make_portrait(pos: Vector2, hero_side: bool) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.position = pos
	portrait.size = Vector2(PT_W, PT_H)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = hero_side
	portrait.modulate = Color(1, 1, 1, 0.45)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	return portrait

func set_name_label(s: String) -> void:
	if _name_lb != null:
		_name_lb.text = s

func reset_portraits() -> void:
	_pt_left_tex = null
	_pt_right_tex = null
	_pt_left.texture = null
	_pt_right.texture = null
	_pt_left.modulate = Color(1, 1, 1, 0)
	_pt_right.modulate = Color(1, 1, 1, 0)

func play_line(speaker: String, text: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("set_dialogue_active", true)
	if _name_lb != null:
		_name_lb.text = speaker
	_set_portraits(speaker)
	_line_full = text
	_shown = 0
	_waiting = false
	_opts_shown = false
	# 对话在物理帧中开启，开启它的那次 E 不会再次进入这里；短保护期只拦同帧重复事件。
	# 键盘长按由 InputEventKey.echo 拦截，不再要求玩家额外松开、再按一次。
	_input_guard_until = Time.get_ticks_msec() + INPUT_GUARD_MSEC
	if _opts_box != null:
		_opts_box.visible = false
	if _continue_lb != null:
		_continue_lb.visible = false
	_text_lb.text = ""
	_typing = true
	_timer.start()

func _set_portraits(speaker: String) -> void:
	var info: Array = PORTRAITS.get(speaker, [])
	if info.is_empty():
		_pt_left.texture = null
		_pt_right.texture = null
		_pt_left.modulate = Color(1, 1, 1, 0)
		_pt_right.modulate = Color(1, 1, 1, 0)
		return
	var tex: Texture2D = load(str(info[0]))
	var is_hero: bool = info[1]
	if is_hero:
		_pt_right_tex = tex
		if tex != null:
			_pt_right.texture = tex
		_pt_right.modulate = Color(1, 1, 1, 1.0)
		_pt_left.modulate = Color(1, 1, 1, 0.45)
	else:
		_pt_left_tex = tex
		if tex != null:
			_pt_left.texture = tex
		_pt_left.modulate = Color(1, 1, 1, 1.0)
		_pt_right.modulate = Color(1, 1, 1, 0.45)
	if _pt_left.texture == null and _pt_left_tex != null:
		_pt_left.texture = _pt_left_tex
	if _pt_right.texture == null and _pt_right_tex != null:
		_pt_right.texture = _pt_right_tex

func _type_tick() -> void:
	_shown += 1
	_text_lb.text = _line_full.substr(0, _shown)
	if _shown >= _line_full.length():
		_timer.stop()
		_typing = false
		_waiting = true
		_continue_lb.visible = true
		line_completed.emit()

func show_options(opts: Array) -> void:
	_opts_shown = true
	_continue_lb.visible = false
	for c in _opts_box.get_children():
		_opts_box.remove_child(c)
		c.queue_free()
	var idx := 0
	for opt: Dictionary in opts:
		var btn := Button.new()
		btn.text = str(opt.get("label", ""))
		btn.custom_minimum_size = Vector2(368, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var i := idx
		btn.pressed.connect(func() -> void:
			var ds := get_node_or_null("/root/DialogueSystem")
			if ds != null:
				ds.call("choose", i))
		_opts_box.add_child(btn)
		idx += 1
	_opts_box.visible = true
	_opts_box.move_to_front()
	if _opts_box.get_child_count() > 0:
		(_opts_box.get_child(0) as Button).grab_focus()

func has_options() -> bool:
	return _opts_shown

func hide_panel() -> void:
	_timer.stop()
	_opts_shown = false
	_waiting = false
	_input_guard_until = 0
	_continue_lb.visible = false
	visible = false
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("set_dialogue_active", false)

func _input(event: InputEvent) -> void:
	# 对话属于模态 UI，必须在普通控件和场景节点之前取得推进键；
	# 使用 _unhandled_input 会在某个 Control 持有焦点时收不到键盘事件。
	if not visible or _opts_shown or Time.get_ticks_msec() < _input_guard_until:
		return
	if event is InputEventKey and event.echo:
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if click or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _consume_advance_press():
			get_viewport().set_input_as_handled()

func _consume_advance_press() -> bool:
	## 返回是否真的消费了一次推进；测试也用它验证一次按下最多改变一个状态。
	if not visible or _opts_shown or Time.get_ticks_msec() < _input_guard_until:
		return false
	_input_guard_until = Time.get_ticks_msec() + INPUT_GUARD_MSEC
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_tick", 1.0, -9.0)
	if _typing:
		_timer.stop()
		_text_lb.text = _line_full
		_shown = _line_full.length()
		_typing = false
		_waiting = true
		_continue_lb.visible = true
		line_completed.emit()
		return true
	if _waiting:
		_waiting = false
		advance_requested.emit()
		return true
	return false
