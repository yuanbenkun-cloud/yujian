extends SceneTree

const KEYS := [
	"flyer_lady", "old_artisan", "aming", "old_shopkeeper", "fat_teahouse",
	"helper", "laozhou", "old_man", "tourist", "vendor", "refugee",
]

var _ok := true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for key: String in KEYS:
		var base := "res://assets/production/npc/cast_v3/%s/" % key
		var idle := load(base + "idle-transparent.png") as Texture2D
		var walk := load(base + "sheet-transparent.png") as Texture2D
		var portrait := load(base + "portrait.png") as Texture2D
		_check(idle != null and idle.get_size() == Vector2(128, 128), "%s idle 128x128" % key)
		_check(walk != null and walk.get_size() == Vector2(384, 256), "%s walk 3x2" % key)
		_check(portrait != null and portrait.get_size() == Vector2(384, 512), "%s portrait 384x512" % key)

	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	for _frame in range(10):
		await process_frame
	var walkers := current_scene.find_children("DistantWalker*", "AnimatedSprite2D", true, false)
	_check(walkers.size() >= 8, "第二关生成至少 8 名移动背景工人")
	for walker in walkers:
		_check(walker.is_playing() and walker.animation == &"walk", "%s 正在播放 walk" % walker.name)

	var aming := current_scene.find_child("aming", true, false) as Node2D
	var aming_visual := aming.find_child("SkinAnim", true, false) as AnimatedSprite2D if aming != null else null
	_check(aming_visual != null and aming_visual.sprite_frames.has_animation(&"walk"), "阿明接入六帧行走动画")
	if aming != null and aming_visual != null:
		aming.position.x += 12.0
		await process_frame
		await process_frame
		_check(aming_visual.animation == &"walk", "剧情 NPC 实际移动时自动切换 walk")

	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_ok = false
		push_error("[FAIL] %s" % label)
