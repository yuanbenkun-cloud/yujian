extends SceneTree
## 关卡 1/2 核心玩法回归：追兵、人群节奏、移动条成功与失误。

var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failed += 1

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/01_hongyadong.tscn")
	await process_frame
	await process_frame
	var player := current_scene.find_child("zhujue", true, false) as Node2D
	var chaser := current_scene.find_child("chuandanayi", true, false) as Node2D
	var manager := current_scene.find_child("ChaseManager", true, false)
	var hud := current_scene.find_child("UI_Chase", true, false)
	var crowd := current_scene.find_child("diyiguan_renqun_01", true, false) as Node2D
	var roof := current_scene.find_child("LowRoof1", true, false)
	var composure := current_scene.find_child("ComposureHUD", true, false)
	player.global_position.x = 0.0
	var chaser_before := chaser.global_position.x
	manager.call("begin")
	await create_timer(0.3).timeout
	_check(chaser.global_position.x > chaser_before, "第一关：传单阿姨本人开始追赶")
	_check(hud.visible, "第一关：追逐压力 HUD 可见")
	player.global_position.x = 650.0
	var crowd_before_x := crowd.position.x
	await create_timer(0.85).timeout
	_check(crowd.position.x < crowd_before_x, "第一关：路人预警后逆向走来阻挡")
	var crowd_actor := crowd.find_child("CrowdActor1", false, false) as AnimatedSprite2D
	_check(crowd_actor != null and crowd_actor.sprite_frames != null, "第一关：群众使用重新建模的独立现代路人")
	_check(crowd_actor != null and crowd_actor.sprite_frames.get_frame_count("walk") == 6, "第一关：群众使用真正的六帧步行动画")
	_check(roof != null and bool(roof.get_meta("blocks_jump", false)), "第一关：关键人流上方配置低顶棚限制跳跃")
	_check(composure != null and composure.visible, "第一关：三段式镇定值 HUD 已加载")
	var hero_anim := player.find_child("zhujue_donghua", true, false) as AnimatedSprite2D
	_check(hero_anim != null and is_equal_approx(hero_anim.sprite_frames.get_animation_speed("walk"), 5.5), "主角行走动画降至 5.5 FPS")
	var player_animator := player.find_child("zhujue_anim_kongzhi", true, false)
	player_animator.call("_spawn_dust", true)
	player_animator.call("_spawn_landing_ring")
	player_animator.call("_spawn_air_trail")
	_check(current_scene.find_child("LandingDust", true, false) is CPUParticles2D and current_scene.find_child("LandingRing", true, false) is Line2D and current_scene.find_child("HeroTrailGhost", true, false) is Sprite2D, "主角具备落地尘粒、冲击圈和空中残影")
	manager.call("finish")
	crowd.set("_state", 3)
	crowd.set("_timer", 5.0)
	crowd.position.x = 740.0
	player.global_position = Vector2(650, 240)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await create_timer(0.65).timeout
	Input.action_release("move_right")
	_check(player.global_position.x < 691.0, "第一关：群众阻挡水平方向但不再形成可站立平台")
	player.global_position = Vector2(1000, 240)
	player.velocity = Vector2(0, -320)
	var highest_y := player.global_position.y
	for _i in range(16):
		await physics_frame
		highest_y = minf(highest_y, player.global_position.y)
	_check(highest_y >= 226.0, "第一关：低顶棚实体碰撞会压住跳跃高度")

	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	await process_frame
	await process_frame
	var forge := current_scene.find_child("ForgeSequence", true, false)
	var hero := current_scene.find_child("zhujue", true, false)
	var panel := current_scene.find_child("ForgeTimingPanel", true, false)
	forge.call("advance")
	_check(panel.visible and bool(hero.get("frozen")), "第二关：交互打开移动条并锁定走位")
	var heat_station := current_scene.find_child("HeatStation", true, false)
	var heat_particles := heat_station.find_child("HeatWorkParticles", true, false) as CPUParticles2D
	_check(heat_particles != null and heat_particles.emitting and heat_station.find_child("HeatWorkGlow", true, false) is PointLight2D, "第二关：鼓风时开启火星和暖光")
	forge.set("_cursor_value", 0.60)
	var heat_before: float = forge.get("_cursor_value")
	forge.call("_process", 0.5)
	_check(float(forge.get("_cursor_value")) < heat_before - 0.10, "第二关：炉温仍会持续回退，但不再要求极限连按")
	forge.set("_cursor_value", 0.40)
	forge.call("_heat_tap")
	_check(float(forge.get("_cursor_value")) >= 0.515 and float(forge.get("_cursor_value")) <= 0.525, "第二关：单次鼓风增量提高到适中范围")
	forge.set("current_step", 1)
	var quench_rates := []
	for sample in [0.90, 0.70, 0.48, 0.20]:
		forge.set("_cursor_value", sample)
		quench_rates.append(float(forge.call("_quench_cooling_rate")))
	_check(quench_rates[0] < quench_rates[1] and quench_rates[2] < quench_rates[3] and not is_equal_approx(quench_rates[1], quench_rates[2]), "第二关：淬火四段阻力产生不同降温速度")
	_check(quench_rates.max() / quench_rates.min() >= 3.5 and quench_rates.max() / quench_rates.min() <= 3.8, "第二关：淬火阻力差异清晰但末段不再骤坠")
	forge.set("current_step", 0)
	forge.set("_cursor_value", forge.get("_target_center"))
	forge.call("_judge")
	_check(current_scene.find_child("TimingImpactParticles", true, false) is CPUParticles2D and current_scene.find_child("TimingImpactRing", true, false) is Line2D, "第二关：移动条命中叠加火花、冲击圈与指针弹性反馈")
	await create_timer(0.7).timeout
	_check(int(forge.get("current_step")) == 0 and int(forge.get("current_round")) == 1 and int(forge.get("score")) == 100, "第二关：完美判定推进添炭工位进度并计分")
	forge.set("_target_center", 0.7)
	forge.set("_cursor_value", 0.0)
	var time_before: float = forge.get("time_left")
	forge.call("_judge")
	_check(int(forge.get("current_step")) == 0 and int(forge.get("current_round")) == 1 and is_equal_approx(float(forge.get("time_left")), time_before - 5.0), "第二关：失误不推进工位进度且扣除 5 秒")
	print("[RESULT] %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)
