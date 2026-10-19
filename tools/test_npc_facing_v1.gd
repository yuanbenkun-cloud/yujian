extends SceneTree
## NPC 静止面向玩家、追逐与跟随移动朝向回归。

var _ok := true

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + message)
	_ok = _ok and condition

func _skin(actor: Node) -> Node:
	return actor.find_child("SkinAnim", true, false) if actor != null else null

func _wait_skin(actor: Node) -> Node:
	for _i in range(20):
		var visual := _skin(actor)
		if visual != null:
			return visual
		await process_frame
	return null

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	await process_frame
	await process_frame
	var player := current_scene.find_child("zhujue", true, false) as Node2D
	var artisan := current_scene.find_child("laojiangren", true, false) as Node2D
	var visual := await _wait_skin(artisan)
	_check(visual != null, "静态 NPC 动画已加载")
	if visual == null:
		print("[RESULT] FAIL")
		quit(1)
		return
	_check(is_equal_approx((visual as AnimatedSprite2D).sprite_frames.get_animation_speed("idle"), 2.5), "NPC 待机动画降至 2.5 FPS")
	_check((visual as AnimatedSprite2D).sprite_frames.has_animation("walk"), "NPC 帧表包含独立行走动画")
	_check(is_equal_approx((visual as AnimatedSprite2D).sprite_frames.get_animation_speed("walk"), 4.0), "NPC 行走保持低帧率 4 FPS")
	var artisan_idle_frame := (visual as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
	_check(artisan_idle_frame != null and artisan_idle_frame.atlas.resource_path.ends_with("old_artisan/idle-transparent.png"), "静态 NPC 使用独立自然站立帧")
	await create_timer(0.18).timeout
	_check((visual as AnimatedSprite2D).animation == &"idle", "原地对话 NPC 始终保持待机状态")
	player.global_position.x = artisan.global_position.x - 80.0
	await process_frame
	_check(not bool(visual.get("flip_h")) and int(artisan.get_meta("facing_direction")) == -1, "玩家在左侧时 NPC 朝左")
	player.global_position.x = artisan.global_position.x + 80.0
	await process_frame
	_check(bool(visual.get("flip_h")) and int(artisan.get_meta("facing_direction")) == 1, "玩家绕到右侧时 NPC 转向右")

	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	await process_frame
	await process_frame
	player = current_scene.find_child("zhujue", true, false) as Node2D
	var flyer := current_scene.find_child("chuandanayi", true, false) as Node2D
	visual = await _wait_skin(flyer)
	_check(visual != null, "追逐 NPC 动画已加载")
	if visual == null:
		print("[RESULT] FAIL")
		quit(1)
		return
	var flyer_walk_frame := (visual as AnimatedSprite2D).sprite_frames.get_frame_texture("walk", 0) as AtlasTexture
	var flyer_idle_frame := (visual as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
	_check(flyer_walk_frame != null and flyer_walk_frame.atlas.resource_path.ends_with("npc/redesign/flyer_lady/sheet-transparent.png"), "传单阿姨使用新版六帧追逐动作")
	_check(flyer_idle_frame != null and flyer_idle_frame.atlas.resource_path.ends_with("npc/redesign/flyer_lady/idle-transparent.png"), "传单阿姨停止时使用独立站立帧")
	_check((visual as AnimatedSprite2D).modulate.a > 0.99 and (visual as AnimatedSprite2D).self_modulate.a > 0.99, "传单阿姨最终显示为不透明")
	player.global_position = Vector2(flyer.global_position.x + 180.0, flyer.global_position.y)
	flyer.call("activate", player)
	await create_timer(0.12).timeout
	_check((visual as AnimatedSprite2D).animation == &"walk", "追逐者移动时切换行走帧")
	_check(bool(visual.get("flip_h")) and int(flyer.get_meta("facing_direction")) == 1, "追逐者向右移动时朝右")
	player.global_position.x = flyer.global_position.x - 180.0
	await create_timer(0.12).timeout
	_check(not bool(visual.get("flip_h")) and int(flyer.get_meta("facing_direction")) == -1, "追逐者回头时朝左")

	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	await process_frame
	await process_frame
	var follower := current_scene.find_child("NPC_Follower1", true, false) as Node2D
	visual = await _wait_skin(follower)
	_check(visual != null, "跟随 NPC 动画已加载")
	if visual == null:
		print("[RESULT] FAIL")
		quit(1)
		return
	follower.global_position.x += 12.0
	await process_frame
	if visual is AnimatedSprite2D:
		_check((visual as AnimatedSprite2D).animation == &"walk", "队伍成员移动时切换行走帧")
	else:
		_check(visual is Sprite2D, "队伍成员使用正式单帧群众皮肤")
	_check(not bool(visual.get("flip_h")), "队伍成员向右移动时使用原始右向帧")
	follower.global_position.x -= 24.0
	await process_frame
	_check(bool(visual.get("flip_h")), "队伍成员向左移动时正确水平翻转")

	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
