extends SceneTree

const EXPECTED_HEIGHT := 70.0
const EXPECTED_FOOT_Y := 246.0

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("[FAIL] " + message)
	quit(1)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	for _frame in range(8):
		await process_frame
	var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
	var npc := current_scene.find_child("chuandanayi", true, false) as Node2D
	var npc_visual := npc.find_child("SkinAnim", true, false) as AnimatedSprite2D if npc != null else null
	var walker := current_scene.find_child("DistantWalker01", true, false) as AnimatedSprite2D
	if player == null or npc == null or npc_visual == null or walker == null:
		_fail("第一关角色节点未完整生成")
		return

	player.global_position = Vector2(300.0, 240.0)
	npc.global_position = Vector2(220.0, 240.0)
	for _frame in range(4):
		await process_frame
	if npc_visual.flip_h:
		_fail("NPC 面向右侧时仍被错误翻转")
		return

	player.global_position.x = 140.0
	for _frame in range(4):
		await process_frame
	if not npc_visual.flip_h:
		_fail("NPC 面向左侧时没有生成镜像朝向")
		return

	if not is_equal_approx(float(npc_visual.get_meta("visible_height_world", 0.0)), EXPECTED_HEIGHT):
		_fail("NPC 可见高度不是 70px")
		return
	if not is_equal_approx(float(walker.get_meta("visible_height_world", 0.0)), EXPECTED_HEIGHT):
		_fail("背景人影可见高度不是 70px")
		return
	if not is_equal_approx(float(walker.get_meta("grounded_visible_bottom_y", 0.0)), EXPECTED_FOOT_Y):
		_fail("背景人影脚线未对齐主角脚线")
		return
	if not is_equal_approx(npc.global_position.y + float(npc_visual.get_meta("ground_embed_world", 0.0)), EXPECTED_FOOT_Y):
		_fail("NPC 脚线未对齐主角脚线")
		return

	print("[PASS] NPC 左右朝向、70px 统一身高与 246px 统一脚线")
	quit(0)
