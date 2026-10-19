extends SceneTree
## 第一、四关加长与动态背景回归测试。

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
	var level1 := current_scene
	var ground1 := level1.find_child("Ground", true, false) as StaticBody2D
	var exit1 := level1.find_child("FirstExitPortal", true, false) as Node2D
	var ground_shape := ground1.get_child(0) as CollisionShape2D if ground1 != null and ground1.get_child_count() > 0 else null
	var crowds := level1.find_children("diyiguan_renqun_*", "AnimatableBody2D", true, false)
	var street_obstacles := level1.find_children("StreetObstacle*", "StaticBody2D", true, false)
	var ambient1 := level1.find_child("AmbientLife", true, false)
	var weather1 := level1.find_child("WeatherSystem", true, false)
	var camera1 := level1.find_child("zhujue_shexiangji", true, false) as Camera2D
	await create_timer(0.1).timeout
	_check(ground_shape != null and ground_shape.shape is RectangleShape2D and ground_shape.shape.size.x >= 4300.0, "第一关地面扩展到 4300px 以上")
	_check(exit1 != null and exit1.position.x >= 3250.0, "第一关终点后移，完整流程明显加长")
	_check(crowds.size() >= 7, "第一关至少七组流动人群")
	_check(street_obstacles.size() >= 4, "第一关加入四组可跳跃街道路障")
	_check(ambient1 != null and ambient1.find_children("Bird*", "Node2D", true, false).size() == 10, "第一关鸟群收敛为十只，避免天气层过杂")
	_check(ambient1 != null and ambient1.find_children("DistantWalker*", "AnimatedSprite2D", true, false).size() >= 10, "第一关动态背景包含更醒目的远景行人")
	var first_walker1 := ambient1.find_child("DistantWalker01", true, false) as AnimatedSprite2D
	_check(first_walker1 != null and is_equal_approx(float(first_walker1.get_meta("grounded_visible_bottom_y", 0.0)), 247.0), "第一关远景行人稍微上移并按可见脚底贴合道路")
	_check(first_walker1 != null and is_equal_approx(float(first_walker1.get_meta("visible_height_world", 0.0)), 76.8) and first_walker1.modulate.a >= 0.95 and first_walker1.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "背景行人与流动人群使用一致的可见人物比例")
	_check(first_walker1 != null and float(first_walker1.get_meta("speed", 0.0)) >= 17.0 and first_walker1.modulate.r <= 0.72, "远景行人提速并降低亮度层级")
	_check(ambient1 != null and ambient1.find_children("SkyLantern*", "Sprite2D", true, false).size() == 12, "第一关保留十二盏由下向上漂浮的孔明灯")
	_check(weather1 != null and weather1.find_child("ClearNightTone", true, false) is ColorRect and weather1.find_child("NightDrizzle", true, false) == null and weather1.find_child("LanternMotes", true, false) == null, "第一关天气收敛为干净夜色，不再叠加雨雾与额外光点")
	_check(camera1 != null and camera1.limit_right >= 3650, "第一关相机可跟随至加长地图终点")

	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	await process_frame
	await process_frame
	var level2 := current_scene
	var heat_station := level2.find_child("HeatStation", true, false)
	var quench_station := level2.find_child("QuenchStation", true, false)
	var wall2 := level2.find_child("di_erguan_yanbi", true, false) as Node2D
	var exit2 := level2.find_child("dierguan_chukou", true, false) as Node2D
	var ambient2 := level2.find_child("AmbientLife", true, false)
	var weather2 := level2.find_child("WeatherSystem", true, false)
	_check(heat_station != null and int(heat_station.get("station_step")) == 0, "第二关加入独立添炭控火工位")
	_check(quench_station != null and int(quench_station.get("station_step")) == 1, "第二关加入独立淬火控温工位")
	_check(heat_station != null and str(heat_station.get_meta("gameplay_mode", "")) == "rapid_tap", "第二关炉火工位使用连续按键玩法")
	_check(quench_station != null and str(quench_station.get_meta("gameplay_mode", "")) == "hold_release", "第二关淬火工位使用按住松手玩法")
	var forge_sequence := level2.find_child("ForgeSequence", true, false)
	var forge_constants: Dictionary = forge_sequence.get_script().get_script_constant_map() if forge_sequence != null else {}
	_check(forge_constants.get("ROUNDS_BY_STEP", []) == [4, 4, 3] and int(forge_constants.get("TOTAL_ACTIONS", 0)) == 11, "第二关火、淬水增加为四轮，按 4+4+3 共十一次完成")
	_check(wall2 != null and wall2.find_child("OverlayHeat", true, false) == null and wall2.find_child("OverlayQuench", true, false) == null, "第二关移除会露出矩形边界的旧火水叠色层")
	_check(heat_station != null and heat_station.find_child("StationVisual", true, false) is Sprite2D and quench_station != null and quench_station.find_child("StationVisual", true, false) is Sprite2D, "第二关炉火与淬火均使用生成后的像素画工位")
	_check(wall2 != null and wall2.position.x >= 2350.0 and exit2 != null and exit2.position.x >= 2650.0, "第二关三工位沿长路线依次展开")
	_check(ambient2 != null and ambient2.find_children("KilnSmoke*", "Polygon2D", true, false).size() >= 14, "第二关背景加入更明显的流动窑烟")
	_check(weather2 != null and weather2.find_child("HeatDistortion", true, false) is ColorRect and weather2.find_child("HeatEmbers", true, false) is CPUParticles2D, "第二关加入局部热浪扭曲与窑火浮尘")
	var wall_visual := wall2.find_child("WallVisual", true, false) as Sprite2D if wall2 != null else null
	_check(wall_visual != null and wall_visual.texture.resource_path.ends_with("chisel-wall-v2.png"), "第二关岩壁使用逐像素去亮橙外边框版本")

	change_scene_to_file("res://scenes/guanqia/03_zhongshan.tscn")
	await process_frame
	await process_frame
	var level3 := current_scene
	var hazards := level3.find_children("RouteHazard*", "Area2D", true, false)
	var exit3 := level3.find_child("disanguan_chukou", true, false) as Node2D
	var ambient3 := level3.find_child("AmbientLife", true, false)
	var weather3 := level3.find_child("WeatherSystem", true, false)
	_check(hazards.size() >= 3, "第三关三段路线各有可躲避的货损危险")
	_check(exit3 != null and exit3.position.x >= 3100.0, "第三关码头交付路线明显加长")
	_check(ambient3 != null and ambient3.find_children("RiverBoat*", "Node2D", true, false).is_empty(), "第三关按反馈移除违和的背景行船")
	_check(level3.find_children("OBJ_Lantern", "Sprite2D", true, false).is_empty(), "第三关移除旧版悬空红灯笼")
	_check(weather3 != null and weather3.find_child("RainHaze", true, false) is ColorRect and weather3.find_child("DrizzleParticles", true, false) is CPUParticles2D, "第三关加入灰蒙薄雾和淅沥细雨")

	change_scene_to_file("res://scenes/guanqia/04_fangdong.tscn")
	await process_frame
	await process_frame
	var level4 := current_scene
	var exit4 := level4.find_child("disiguan_chukou", true, false) as Node2D
	var shields := level4.find_children("BlastShield*", "Node2D", true, false)
	var rubble := level4.find_children("RubbleObstacle*", "StaticBody2D", true, false)
	var bomb := level4.find_child("BombWarning", true, false)
	var ambient4 := level4.find_child("AmbientLife", true, false)
	var weather4 := level4.find_child("WeatherSystem", true, false)
	await process_frame
	var follower_models := level4.find_children("SkinAnim", "AnimatedSprite2D", true, false)
	var camera4 := level4.find_child("zhujue_shexiangji", true, false) as Camera2D
	await create_timer(0.1).timeout
	_check(exit4 != null and exit4.position.x >= 3200.0, "第四关出口后移至长距离护送终点")
	_check(shields.size() >= 6, "第四关扩展为六段挡板推进")
	_check(rubble.is_empty(), "第四关按反馈移除地面碎石障碍")
	_check(bomb != null and float(bomb.get("max_strike_x")) >= 3100.0, "第四关轰炸覆盖加长后的全程")
	_check(ambient4 != null and ambient4.find_children("DistantWalker*", "AnimatedSprite2D", true, false).is_empty(), "第四关按反馈移除动态背景人物")
	var wartime_followers := follower_models.filter(func(model: AnimatedSprite2D) -> bool: return str(model.get_meta("wartime_crowd_texture", "")).contains("wartime-"))
	_check(wartime_followers.size() == 6, "第四关六名护送群众全部换成新战时避难人群建模")
	_check(wartime_followers.all(func(model: AnimatedSprite2D) -> bool: return is_equal_approx(float(model.get_meta("visible_height_world", 60.0)), 60.0) or model.scale.y < 1.0), "第四关避难人群缩放到与主角一致的可见身高")
	var rescue_stages: Dictionary = {}
	for follower in level4.find_children("NPC_Follower*", "Area2D", true, false):
		rescue_stages[int(follower.get_meta("rescue_stage", 0))] = true
	_check(rescue_stages.has(1) and rescue_stages.has(2) and rescue_stages.has(3), "第四关六名难民分布为三批沿途救援")
	_check(level4.find_child("CarriedLantern", true, false) == null and level4.find_child("YudengPathLight", true, false) is PointLight2D, "第四关移除手提灯，改由精灵提供动态照明")
	var generated_barriers := level4.find_children("GeneratedBarrier", "Sprite2D", true, false)
	_check(generated_barriers.size() == 6, "第四关六段挡板全部替换为 AI 生成的战时沙袋掩体")
	_check(generated_barriers.all(func(barrier: Sprite2D) -> bool: return barrier.position.y >= 68.0), "第四关挡板下沉并贴合洞内真实地表")
	_check(level4.find_child("AirRaidWarningEmblem", true, false) != null, "第四关落弹提示替换为环形航弹警告标志")
	_check(ambient4 != null and ambient4.find_children("ShelterRat*", "Sprite2D", true, false).size() >= 8, "第四关地面加入无碰撞奔跑老鼠")
	_check(weather4 != null and weather4.find_child("CaveDust", true, false) is CPUParticles2D and weather4.find_child("ShelterDustVeil", true, false) is ColorRect, "第四关加入洞内悬尘与灰屑，不增加玩法障碍")
	var first_rat := ambient4.find_child("ShelterRat01", true, false) as Sprite2D
	_check(first_rat != null and is_equal_approx(float(first_rat.get_meta("grounded_visible_bottom_y", 0.0)), 253.0), "第四关老鼠按洞底碎石表面单独贴地")
	var missile_light := level4.find_child("MissileGlow", true, false) as PointLight2D
	var explosion := bomb.call("_spawn_explosion", Vector2(900, 226), false) as Node2D
	var explosion_light := explosion.find_child("ExplosionFlashLight", true, false) as PointLight2D
	_check(missile_light != null and explosion_light != null and explosion_light.texture_scale >= 8.0, "第四关导弹下落与爆炸均带明显动态照明")
	_check(camera4 != null and camera4.limit_right >= 3450, "第四关相机覆盖加长后的完整护送路线")

	change_scene_to_file("res://scenes/guanqia/05_hongyadong_return.tscn")
	await process_frame
	await process_frame
	var level5 := current_scene
	var route5 := level5.find_child("MemoryRoute", true, false)
	var wall_memory := level5.find_child("diwuguan_jiuchengqiang", true, false)
	var light_memory := level5.find_child("diwuguan_denghuo", true, false)
	var photo5 := level5.find_child("diwuguan_zhaoxiangdian", true, false) as Node2D
	var ambient5 := level5.find_child("AmbientLife", true, false)
	var weather5 := level5.find_child("WeatherSystem", true, false)
	_check(route5 != null and int(route5.get_script().get_script_constant_map().get("TOTAL", 0)) == 6, "第五关扩展为六段城市记忆")
	_check(wall_memory != null and light_memory != null, "第五关新增旧墙与城市灯火观察点")
	_check(wall_memory != null and wall_memory.find_child("OldGateVisual", true, false) is Sprite2D and light_memory != null and light_memory.find_child("CityLightsVisual", true, false) is Sprite2D, "第五关新增观察物改用统一像素画生成素材")
	var first_walker5 := ambient5.find_child("DistantWalker01", true, false) as AnimatedSprite2D if ambient5 != null else null
	_check(first_walker5 != null and is_equal_approx(float(first_walker5.get_meta("grounded_visible_bottom_y", 0.0)), 247.0), "第五关远景行人稍微上移并贴合台阶顶面")
	_check(first_walker5 != null and is_equal_approx(float(first_walker5.get_meta("visible_height_world", 0.0)), 60.0), "第五关人影与主角统一为 60px 可见身高")
	_check(photo5 != null and photo5.position.x >= 3200.0, "第五关拍照点位于完整观察路线末端")
	_check(weather5 != null and weather5.find_child("MorningLightShaft1", true, false) is Polygon2D and weather5.find_child("GoldenMotes", true, false) is CPUParticles2D, "第五关加入清晨斜射光与金色浮尘")
	print("[RESULT] %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)
