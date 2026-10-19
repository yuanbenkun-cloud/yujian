extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview/" + filename)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(0.4).timeout
	var level: Node = current_scene
	level._start_chase()
	level.player.position = Vector2(2020, 282)
	level._story_panel.hide()
	await create_timer(0.6).timeout
	var effect: CanvasLayer = level.get_node("MemoryScreenEffect")
	check(not effect.screen.visible and effect.strength == 0.0, "现实区特效完全关闭")
	check(effect.layer < level.ui.layer and effect.screen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD和对话不被特效染色或截获点击")
	await capture("future-reality-mode-v1.png")
	level.set_history_mode(true)
	await create_timer(0.4).timeout
	check(effect.screen.visible and is_equal_approx(effect.strength, 1.0), "回忆区蓝色数字屏幕渐入完成")
	check(effect.screen.size.is_equal_approx(root.get_visible_rect().size), "特效覆盖完整视口")
	check(level._mode_badge.text.contains("回忆区"), "模式文字明确显示回忆区")
	var civilian: Node = level.get_node("MemoryCivilian1")
	var material: ShaderMaterial = civilian._anim.material
	check(material.get_shader_parameter("memory_amount") == 1.0, "回忆人物启用轻微蓝幕虚化")
	await capture("future-memory-mode-v1.png")
	level.set_history_mode(false)
	await create_timer(0.4).timeout
	check(not effect.screen.visible and effect.strength == 0.0, "切回现实完整恢复原画面")
	check(material.get_shader_parameter("memory_amount") == 0.0, "现实中跟随人物恢复清晰原色")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
