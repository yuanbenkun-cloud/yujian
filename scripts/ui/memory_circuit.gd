extends PanelContainer
## A real connectivity puzzle: only reciprocal ports carry the recovered memory.
signal reconstructed
const Tile = preload("res://scripts/ui/memory_circuit_tile.gd")
const SOLVED: Array[int] = [6, 10, 12, 9, 5, 3, 6, 10, 9]
const SCRAMBLE: Array[int] = [1, 0, 2, 1, 1, 3, 2, 1, 0]
var tiles: Array[Button] = []
var hint: Label
var moves: int = 0
var finished: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -230
	offset_right = 230
	offset_top = -148
	offset_bottom = 148
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081523")
	style.border_color = Color("#d7b16e")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var title := Label.new()
	title.text = "记忆线路重构 · 不是每段档案都已接通"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 34
	column.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for side in range(3):
		if side != 1:
			var endpoint := Label.new()
			endpoint.text = "旧档案 →" if side == 0 else "→ 公共记忆"
			endpoint.add_theme_font_size_override("font_size", 11)
			row.add_child(endpoint)
			continue
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		row.add_child(grid)
		for i in range(9):
			var button: Button = Tile.new()
			button.custom_minimum_size = Vector2(64, 44)
			button.tooltip_text = "旋转线路 %d · 点击或回车" % (i + 1)
			button.pressed.connect(rotate_tile.bind(i))
			grid.add_child(button)
			tiles.append(button)
	for index in range(9):
		var button: Button = tiles[index]
		button.focus_neighbor_left = tiles[index - 1 if index % 3 > 0 else index].get_path()
		button.focus_neighbor_right = tiles[index + 1 if index % 3 < 2 else index].get_path()
		button.focus_neighbor_top = tiles[maxi(0, index - 3)].get_path()
		if index < 6: button.focus_neighbor_bottom = tiles[index + 3].get_path()
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	for text: String in ["验证连接", "重置线路"]:
		var button := Button.new()
		button.text = text
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(110, 28)
		button.pressed.connect(verify if text == "验证连接" else reset_board)
		actions.add_child(button)
	reset_board()
	tiles[3].grab_focus.call_deferred()

static func rotated(mask: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3)

func reset_board() -> void:
	if finished: return
	moves = 0
	for i in range(9):
		var mask: int = SOLVED[i]
		for turn in range(SCRAMBLE[i]): mask = rotated(mask)
		tiles[i].ports = mask
	hint.text = "点击旋转；方向键选格，回车旋转。接通左侧档案与右侧出口，再验证。"

func rotate_tile(index: int) -> void:
	if finished: return
	tiles[index].ports = rotated(tiles[index].ports)
	moves += 1
	hint.text = "已调整 %d 次 · 相邻接口必须对齐；没有倒计时，观察后再验证。" % moves

func has_memory_route() -> bool:
	if not (tiles[3].ports & 8) or not (tiles[5].ports & 2): return false
	var visited: Array[int] = [3]
	var pending: Array[int] = [3]
	while not pending.is_empty():
		var index: int = pending.pop_front()
		for side in range(4):
			if not (tiles[index].ports & (1 << side)): continue
			if (index == 3 and side == 3) or (index == 5 and side == 1): continue
			var x: int = index % 3 + [0, 1, 0, -1][side]
			var y: int = index / 3 + [-1, 0, 1, 0][side]
			if x < 0 or x > 2 or y < 0 or y > 2: return false
			var neighbor: int = y * 3 + x
			if not (tiles[neighbor].ports & (1 << ((side + 2) % 4))): return false
			if not visited.has(neighbor):
				visited.append(neighbor)
				pending.append(neighbor)
	return visited.has(5)

func verify() -> void:
	if finished: return
	if not has_memory_route():
		hint.text = "信号在断口处消失了。先从左侧入口沿线检查，空接和越界都会中断。"
		return
	finished = true
	reconstructed.emit()
