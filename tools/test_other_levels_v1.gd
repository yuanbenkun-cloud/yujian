extends SceneTree
## 第一/二关增强与第三/五关重构回归。

var failed := 0
func _check(condition: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	if not condition: failed += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	await process_frame
	await process_frame
	var forge := current_scene.find_child("ForgeSequence", true, false)
	var speed_round_1: float = forge.call("_current_speed")
	var width_round_1: float = forge.call("_current_width")
	var perfect_round_1: float = forge.call("_perfect_half_width")
	forge.set("current_round", 2)
	_check(float(forge.call("_current_speed")) > speed_round_1 and float(forge.call("_current_width")) < width_round_1, "第二关：后续轮次加速并缩窄判定区")
	_check(float(forge.call("_current_speed")) >= speed_round_1 * 1.39 and float(forge.call("_perfect_half_width")) < perfect_round_1, "第二关：强化后续轮次额外加速 40% 且完美区继续缩窄")
	var forge_constants: Dictionary = forge.get_script().get_script_constant_map()
	_check(float(forge_constants.get("TIME_LIMIT", 0.0)) == 120.0 and float(forge_constants.get("MISS_TIME_PENALTY", 0.0)) == 7.0, "第二关：总时限 120 秒，失误扣时提高到 7 秒")

	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await process_frame
	await process_frame
	var trade := current_scene.find_child("ChoiceSystem", true, false)
	var laozhou := current_scene.find_child("laozhou", true, false)
	laozhou.call("on_interact", current_scene.find_child("zhujue", true, false))
	_check(int(trade.get("stage")) == 0 and not bool(root.get_node("DialogueSystem").get("active")), "第三关：不能跳过护货路线直接交货")
	trade.call("advance_stage", 1)
	root.get_node("GameState").call("reset_goods")
	root.get_node("GameState").call("apply_goods_event", "stolen")
	await process_frame
	var cargo_bar := current_scene.find_child("UI_CargoIntegrity", true, false) as ProgressBar
	_check(int(cargo_bar.value) == 70, "第三关：货损即时同步到完整度 HUD")
	trade.call("advance_stage", 3)
	_check(bool(trade.call("can_use", 3)), "第三关：完成前置节点后解锁老周")

	change_scene_to_file("res://scenes/guanqia/05_hongyadong_return.tscn")
	await process_frame
	await process_frame
	var memory := current_scene.find_child("MemoryRoute", true, false)
	var photo := current_scene.find_child("diwuguan_zhaoxiangdian", true, false)
	photo.call("on_interact", current_scene.find_child("zhujue", true, false))
	_check(not bool(root.get_node("DialogueSystem").get("active")), "第五关：记忆未集齐时观景台保持锁定")
	for memory_id in ["board", "old_man", "wall", "flyer", "view", "lights"]:
		memory.call("collect", memory_id)
	_check(bool(memory.call("can_finish")), "第五关：六段城市记忆全部点亮后解锁拍照选择")
	var memory_label := current_scene.find_child("UI_MemoryProgress", true, false) as Label
	_check(memory_label.text.contains("6/6"), "第五关：记忆 HUD 显示完整进度")
	photo.call("on_interact", current_scene.find_child("zhujue", true, false))
	_check(current_scene.find_child("PhotoFocusPanel", true, false) == null and bool(root.get_node("DialogueSystem").get("active")), "第五关：移除取景小游戏，直接进入原拍照选择")
	print("[RESULT] %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)
