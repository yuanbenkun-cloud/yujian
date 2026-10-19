extends SceneTree
## 阿姨专用播放节奏、左右朝向与脚线回归，不修改玩家存档。

var _ok: bool = true

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_ok = _ok and value
	print(("[PASS] " if value else "[FAIL] ") + label)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	for _frame in range(12):
		await process_frame
	var actor := current_scene.find_child("chuandanayi", true, false) as Node2D
	var visual := actor.find_child("SkinAnim", true, false) as AnimatedSprite2D
	var skinner := root.get_node("Skinner")
	_check(visual != null, "阿姨动画加载")
	if visual == null:
		quit(1)
		return
	actor.set_physics_process(false)
	skinner.set_process(false)
	var original_y := actor.position.y
	var original_scale := visual.scale
	var original_offset := visual.position
	_check(is_equal_approx(visual.sprite_frames.get_animation_speed("walk"), 12.0), "专用 12 FPS，不再使用 4 FPS")
	_check(visual.sprite_frames.get_frame_count("walk") == 8, "八帧完整左右脚交替步态")
	actor.set_meta("locomotion_speed", 150.0)
	var seen_frames: Dictionary = {}
	for _frame in range(24):
		actor.position.x += 6.0
		skinner.call("_update_facing_and_motion", current_scene, 0.04)
		await create_timer(0.04).timeout
		seen_frames[visual.frame] = true
	_check(seen_frames.size() >= 5, "连续行走实际播放至少五个不同动作帧")
	_check(visual.animation == &"walk" and not visual.flip_h, "向右行走使用右向动作")
	_check(visual.position.is_equal_approx(original_offset) and visual.scale.is_equal_approx(original_scale), "行走不叠加抖动与拉伸")
	_check(is_equal_approx(actor.position.y, original_y), "根节点保持路面高度")
	actor.set_meta("locomotion_speed", 72.0)
	actor.position.x -= 3.0
	skinner.call("_update_facing_and_motion", current_scene, 0.04)
	_check(visual.flip_h, "向左行走正确翻转")
	_check(is_equal_approx(visual.speed_scale, 0.48), "人群减速时步频同步降低")
	for _frame in range(6):
		skinner.call("_update_facing_and_motion", current_scene, 0.04)
	_check(visual.animation == &"idle" and is_equal_approx(visual.speed_scale, 1.0), "停止后恢复待机与默认播放速度")
	print("[RESULT] " + ("PASS" if _ok else "FAIL"))
	current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	quit(0 if _ok else 1)
