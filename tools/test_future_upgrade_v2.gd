extends SceneTree

class IsolatedState extends "res://autoload/game_state.gd":
	func _ready() -> void: pass
	func _save_story() -> void: pass

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	var isolated := IsolatedState.new()
	isolated.story_completed = true
	check(not isolated.can_enter_future(), "单独的结局标记不能解锁第六关")
	isolated.record_level_completed(5)
	check(not isolated.can_enter_future(), "只过第五关不能代替全通")
	for level in range(1, 5): isolated.record_level_completed(level)
	check(isolated.can_enter_future(), "五关全部有记录才解锁")
	isolated.record_level_completed(1)
	check(isolated.completed_levels.size() == 5, "重复通关不会重复计数")
	isolated.begin_from_chapter(2)
	check(isolated.can_enter_future(), "通关后重玩章节保留已解锁资格")
	isolated.free()
	var gs: Node = root.get_node("GameState")
	var old: Array = gs.completed_levels.duplicate()
	var story: bool = gs.story_completed
	gs.completed_levels.clear()
	gs.story_completed = true
	var menu: Node = load("res://scenes/kaishi.tscn").instantiate()
	root.add_child(menu)
	check(menu.find_child("FutureButton", true, false) == null, "未全通时标题不创建第六关按钮")
	check(not root.get_node("LevelManager").start_future_bonus(), "绕过菜单直接请求也拒绝未解锁玩家")
	menu.queue_free()
	await process_frame
	gs.completed_levels.assign([1, 2, 3, 4, 5])
	menu = load("res://scenes/kaishi.tscn").instantiate()
	root.add_child(menu)
	check(menu.find_child("FutureButton", true, false) != null, "全通时标题创建第六关按钮")
	menu.queue_free()
	gs.completed_levels.assign(old)
	gs.story_completed = story
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(0.4).timeout
	var level: Node = current_scene
	level.call("_start_chase")
	level.call("on_drone_caught", Vector2(790, 193))
	level.call("begin_terminal_calibration", level._terminal)
	level.call("_complete_calibration")
	var npc: Node2D = level._civilians[0]
	npc.recruited = true
	level.call("recruit_civilian", npc)
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	check(npc.waiting and level._escort_waiting, "实际C键让队伍原地等候")
	var origin: float = npc.position.x
	level.player.position.x += 180
	await create_timer(0.3).timeout
	check(is_equal_approx(npc.position.x, origin), "主角侦察时等候队员不跟随")
	root.push_input(key, true)
	await process_frame
	check(not npc.waiting and not level._escort_waiting, "再次C键恢复跟随")
	level.call("toggle_escort_waiting")
	level.call("_reset_escort")
	check(not level._escort_waiting and not npc.waiting, "失败重试清理等候状态")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
