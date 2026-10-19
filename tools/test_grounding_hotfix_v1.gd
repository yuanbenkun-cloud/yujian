extends SceneTree
## 2026-10 视觉落地回归：人群脚线、挑担人比例、挡板真实透明底边。

var _ok := true

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	_ok = _ok and condition

func _load(path: String) -> void:
	change_scene_to_file(path)
	await process_frame
	await process_frame

func _run() -> void:
	await _load("res://scenes/guanqia/01_hongyadong.tscn")
	var crowd := current_scene.find_child("diyiguan_renqun_01", true, false)
	var actors := crowd.find_children("CrowdActor*", "AnimatedSprite2D", false, false) if crowd != null else []
	var crowd_grounded := actors.size() == 5
	for actor in actors:
		crowd_grounded = crowd_grounded and absf(float(actor.get_meta("grounded_visible_bottom_y", 0.0)) - 240.0) < 0.1
	_check(crowd_grounded, "第一关五人流动人群统一落在街面 y=240")

	await _load("res://scenes/guanqia/03_zhongshan.tscn")
	var carriers := current_scene.find_children("Carrier", "Sprite2D", true, false)
	var carrier_scaled := carriers.size() == 3
	for carrier in carriers:
		carrier_scaled = carrier_scaled and absf((carrier as Sprite2D).scale.x - 0.15) < 0.001 and absf((carrier as Sprite2D).position.y + 42.0) < 0.1
	_check(carrier_scaled, "第三关三名挑担人按主角 70px 身高缩放并校准脚线")

	await _load("res://scenes/guanqia/04_fangdong.tscn")
	var barriers := current_scene.find_children("GeneratedBarrier", "Sprite2D", true, false)
	var barrier_grounded := barriers.size() == 6
	for barrier in barriers:
		barrier_grounded = barrier_grounded and absf((barrier as Sprite2D).position.y - 80.4) < 0.2
	_check(barrier_grounded, "第四关六块挡板上移并以真实像素底边贴地")

	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
