extends SceneTree

const EXPECTED_HEIGHT := 70.0
const EXPECTED_FOOT_Y := 246.0
const LEVELS := [
	{"path": "res://scenes/guanqia/01_hongyadong.tscn", "npcs": ["chuandanayi"], "focus": "chuandanayi", "player_x": 300.0, "npc_x": 220.0},
	{"path": "res://scenes/guanqia/02_ciqikou.tscn", "npcs": ["laojiangren", "aming"], "focus": "laojiangren", "player_x": 380.0, "npc_x": 300.0},
	{"path": "res://scenes/guanqia/03_zhongshan.tscn", "npcs": ["laozhanggui", "pangzhanggui", "banggong", "laozhou"], "focus": "pangzhanggui", "player_x": 1060.0, "npc_x": 980.0},
	{"path": "res://scenes/guanqia/04_fangdong.tscn", "npcs": ["NPC_Follower1", "NPC_Follower2", "NPC_Follower3", "NPC_Follower4", "NPC_Follower5", "NPC_Follower6"], "focus": "NPC_Follower1", "player_x": 600.0, "npc_x": 520.0},
	{"path": "res://scenes/guanqia/05_hongyadong_return.tscn", "npcs": ["jianglishilaoren", "chuandanayi"], "focus": "jianglishilaoren", "player_x": 800.0, "npc_x": 720.0},
]

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("[FAIL] " + message)
	quit(1)

func _find_actor(actor_name: String) -> Node2D:
	for candidate in current_scene.find_children(actor_name, "", true, false):
		if candidate is Node2D and candidate.has_node("VisualPivot"):
			return candidate as Node2D
	return null

func _actual_visible_height(sprite: AnimatedSprite2D, animation_name: StringName, frame_index: int = 0) -> float:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return 0.0
	var texture := sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
	if texture == null:
		return 0.0
	var image := texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var used := image.get_used_rect()
	# 角色的 VisualPivot 会在落地瞬间做 0.22 秒挤压反馈；尺寸规范检查应测
	# 稳态素材缩放，不应把临时的 game-feel 形变算成模型身高。
	return float(used.size.y) * absf(sprite.scale.y)

func _run() -> void:
	for level: Dictionary in LEVELS:
		change_scene_to_file(str(level["path"]))
		for _frame in range(10):
			await process_frame
		var intro := current_scene.find_child("StoryIntroLayer", true, false)
		if intro != null:
			intro.visible = false
		var player := current_scene.find_child("zhujue", true, false) as CharacterBody2D
		var hero := current_scene.find_child("zhujue_donghua", true, false) as AnimatedSprite2D
		if player == null or hero == null:
			_fail("%s 缺少主角节点" % level["path"])
			return
		player.set("frozen", false)
		player.global_position = Vector2(float(level["player_x"]), 240.0)
		player.velocity = Vector2.ZERO
		for _frame in range(4):
			await physics_frame
		player.set("frozen", true)
		if not is_equal_approx(float(hero.get_meta("visible_height_world", 0.0)), EXPECTED_HEIGHT):
			_fail("%s 主角不是 70px" % level["path"])
			return
		# 强制测量落地待机帧。审计脚本会瞬移角色，物理接触缓存刷新前可能短暂
		# 播放 jump；拿当前帧会把跳跃姿势误当成站立身高。
		var actual_hero_height := _actual_visible_height(hero, &"idle", 0)
		if absf(actual_hero_height - EXPECTED_HEIGHT) > 1.5:
			_fail("%s 主角实际高度 %.2fpx，不是 70px" % [level["path"], actual_hero_height])
			return

		for npc_name: String in level["npcs"]:
			var npc := _find_actor(npc_name)
			var visual := npc.find_child("SkinAnim", true, false) as AnimatedSprite2D if npc != null else null
			if npc == null or visual == null:
				_fail("%s 缺少 %s 的新模型" % [level["path"], npc_name])
				return
			if not is_equal_approx(float(visual.get_meta("visible_height_world", 0.0)), EXPECTED_HEIGHT):
				_fail("%s/%s 不是 70px" % [level["path"], npc_name])
				return
			var foot_y := npc.global_position.y + float(visual.get_meta("ground_embed_world", 0.0))
			if not is_equal_approx(foot_y, EXPECTED_FOOT_Y):
				_fail("%s/%s 脚线 %.2f，不是 %.2f" % [level["path"], npc_name, foot_y, EXPECTED_FOOT_Y])
				return

		var focus := _find_actor(str(level["focus"]))
		if focus != null:
			focus.global_position = Vector2(float(level["npc_x"]), 240.0)
		for _frame in range(12):
			await process_frame
		if str(level["path"]).contains("01_") or str(level["path"]).contains("05_"):
			var walker := current_scene.find_child("DistantWalker01", true, false) as AnimatedSprite2D
			if walker == null:
				_fail("%s 缺少背景人影" % level["path"])
				return
			if not is_equal_approx(float(walker.get_meta("visible_height_world", 0.0)), EXPECTED_HEIGHT):
				_fail("%s 背景人影不是 70px" % level["path"])
				return
			if not is_equal_approx(float(walker.get_meta("grounded_visible_bottom_y", 0.0)), EXPECTED_FOOT_Y):
				_fail("%s 背景人影脚线错误" % level["path"])
				return

	print("[PASS] 五关主角、NPC、护送群众和背景人影统一为 70px / 246px 脚线")
	quit(0)
