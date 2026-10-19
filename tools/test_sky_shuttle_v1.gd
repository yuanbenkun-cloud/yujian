extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + message)
	failed = failed or not value

func _run() -> void:
	var level := load("res://scenes/guanqia/06_future_chongqing.tscn").instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	for i in range(12):
		await process_frame
	var craft := level.get_node("FutureLayers/SkyShuttle") as Sprite2D
	check(not level.has_node("FutureLayers/Monorail") and not level.has_node("FutureLayers/TunnelOccluder"), "Old train and tunnel occlusion removed")
	check(craft.texture.resource_path.ends_with("sky-shuttle-v1/shuttle.png"), "Generated spacecraft texture connected")
	check(is_equal_approx(craft.texture.get_width() * craft.scale.x, 220.0), "Shuttle visual width 220px")
	level.set_process(false)
	craft.position.x = -81
	level._update_fixed_background(0.1)
	check(craft.position.x > -80 and craft.position.y >= 68 and craft.position.y <= 76, "High altitude horizontal flight with gentle bob")
	check(level.get_node("FutureShuttleAudio").playing, "Flyby triggers propulsion sound")
	craft.position.x = 821
	level._update_fixed_background(0)
	check(craft.position.x == level.SHUTTLE_LEFT, "Wrap only beyond full offscreen extent")
	level._start_chase()
	level.player.frozen = true
	craft.position.x = 275
	for i in range(12):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := "res://preview/future-sky-shuttle-v1.png"
		root.get_texture().get_image().save_png(path)
		print("Capture: ", path)
	level.queue_free()
	await process_frame
	quit(1 if failed else 0)
