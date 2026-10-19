extends SceneTree

const ERAS := ["modern", "wartime"]
const FRAME_COUNT := 6
var _ok := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for era in ERAS:
		for i in range(1, 7):
			var key := "%s-%02d" % [era, i]
			var path := "res://assets/production/npc/crowd_walk/%s/%s.png" % [era, key]
			var texture := load(path) as Texture2D
			_check(texture != null and texture.get_size() == Vector2(384, 256), "%s 六帧表可加载" % key)

	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	await process_frame
	await process_frame
	var crowd := current_scene.find_child("diyiguan_renqun_01", true, false)
	var actors: Array[Node] = []
	if crowd != null:
		actors = crowd.find_children("CrowdActor*", "AnimatedSprite2D", false, false)
	_check(actors.size() == 5, "第一关流动人群使用动画角色")
	for actor_value in actors:
		var actor := actor_value as AnimatedSprite2D
		_check(actor.sprite_frames.get_frame_count("walk") == FRAME_COUNT, "%s 使用六帧步行" % actor.name)
	var ambient := current_scene.find_child("AmbientLife", true, false)
	var distant := ambient.find_child("DistantWalker01", true, false) as AnimatedSprite2D if ambient != null else null
	_check(distant != null and distant.sprite_frames.get_frame_count("walk") == FRAME_COUNT and distant.animation == &"walk", "远景行人持续播放六帧步行")

	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	await process_frame
	await process_frame
	var follower := current_scene.find_child("NPC_Follower1", true, false) as Node2D
	var visual := follower.find_child("SkinAnim", true, false) as AnimatedSprite2D if follower != null else null
	_check(visual != null and visual.sprite_frames.get_frame_count("walk") == FRAME_COUNT, "第四关难民使用六帧步行")
	if follower != null and visual != null:
		var idle_frame := visual.sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
		_check(idle_frame != null and idle_frame.atlas.resource_path.ends_with("wartime-01-idle.png"), "第四关难民等待时使用独立站立帧")
		follower.global_position.x += 14.0
		await process_frame
		_check(visual.animation == &"walk" and not visual.flip_h, "第四关难民右行显示原始右向帧")
		follower.global_position.x -= 28.0
		await process_frame
		_check(visual.flip_h, "第四关难民左行正确翻转")

	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_ok = false
		push_error("[FAIL] %s" % label)
