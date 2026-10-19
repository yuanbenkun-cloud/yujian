extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/kaishi.tscn")
	await process_frame
	await process_frame
	var title := current_scene.find_child("Title", true, false) as Label
	var valid := title != null and title.text == "渝  见"
	print("[PASS] 开始界面标题已改为渝见" if valid else "[FAIL] 开始界面标题未正确替换")
	quit(0 if valid else 1)
