extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func read_current(ds: Node, panel: Control, expected: Array) -> void:
	for line: Dictionary in expected:
		check(ds.active and panel.visible and panel._line_full == line.text, "对话逐句保留：" + str(line.speaker))
		panel._input_guard_until = 0
		panel._consume_advance_press()
		panel._input_guard_until = 0
		panel._consume_advance_press()
	check(not ds.active, "最后一句确认后才结束")

func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var flags: Dictionary = gs.insight_flags.duplicate(true)
	change_scene_to_file("res://scenes/guanqia/05_hongyadong_return.tscn")
	await create_timer(0.4).timeout
	var ds: Node = root.get_node("DialogueSystem")
	var panel: Control = current_scene.get_node("UI_Base/DialoguePanel")
	var route: Node = current_scene.get_node("MemoryRoute")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue_level5.json"))
	var count: int = 0
	for npc: Node in current_scene.get_children():
		if npc.get_script() != load("res://scripts/npc/memory_interactable.gd"): continue
		count += 1
		# Simulate inherited empty export values on both NPCs.
		if npc.memory_id in ["old_man", "flyer"]: npc.dialogue_file = ""
		npc.on_interact(current_scene.get_node("zhujue"))
		check(ds.active and panel.visible, "记忆对话正常打开：" + str(npc.memory_id))
		await read_current(ds, panel, data[npc.dialogue_node].lines)
		check(route.collected.has(npc.memory_id) and npc._completed, "完整读完才收集记忆")
		npc.on_interact(current_scene.get_node("zhujue"))
		check(ds.active and panel.visible, "已读记忆可以重新交谈")
		await read_current(ds, panel, data[npc.dialogue_node].lines)
	check(count == 6 and route.can_finish(), "六处记忆全部可读并完成收集")
	ds.load_data("res://assets/dialogue_level5.json")
	ds.start_dialogue("photo")
	ds.choose(1)
	await create_timer(2.5).timeout
	check(ds.active and panel.visible and panel._line_full == data.photo_not.lines[0].text, "结局插图结束后恢复对话，不丢失后续文字")
	ds.cancel_for_scene_change()
	gs.insight_flags = flags
	gs._save_story()
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
