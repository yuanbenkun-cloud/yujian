extends SceneTree
## 五关难度升级、最终关阿姨显示与洪崖洞双结局回归。

var failed := 0

func _check(condition: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failed += 1

func _texture_source_path(texture: Texture2D) -> String:
	var source := texture
	while source is AtlasTexture:
		source = (source as AtlasTexture).atlas
	return source.resource_path if source != null else ""

func _init() -> void:
	call_deferred("_run")

func _load_scene(path: String) -> void:
	root.get_node("DialogueSystem").call("cancel_for_scene_change")
	change_scene_to_file(path)
	await process_frame
	await process_frame

func _run() -> void:
	await _load_scene("res://scenes/guanqia/01_hongyadong.tscn")
	var aunt := current_scene.find_child("chuandanayi", true, false)
	var aunt_constants: Dictionary = aunt.get_script().get_script_constant_map()
	_check(float(aunt_constants.get("BASE_SPEED", 0.0)) >= 150.0 and float(aunt_constants.get("FAR_SPEED", 0.0)) >= 190.0, "第一关：追逐阿姨速度显著提高")
	var crowd := current_scene.find_child("diyiguan_renqun_01", true, false)
	var crowd_people := crowd.find_children("CrowdActor*", "AnimatedSprite2D", false, false)
	_check(crowd_people.size() == 5, "第一关：每股流动人群由 3 人增至 5 人")
	var stone := current_scene.find_child("diyiguan_husongdizhuan", true, false)
	var stone_visual := stone.find_child("StoneButtonVisual", false, false) if stone != null else null
	var portal1 := current_scene.find_child("FirstExitPortal", true, false)
	var portal1_visual := portal1.find_child("GoalPortalVisual", false, false) if portal1 != null else null
	root.get_node("LevelManager").set("current_level", 1)
	_check(stone_visual != null, "第一关：古墙石扣恢复为可见场景物件")
	_check(portal1 != null and not bool(portal1.get("_active")) and portal1_visual != null and not portal1_visual.visible, "第一关：碰到石扣前传送门隐藏")
	stone.call("_on_body_entered", current_scene.find_child("zhujue", true, false))
	await process_frame
	_check(bool(portal1.get("_active")) and portal1_visual.visible and root.get_node("LevelManager").get("current_level") == 1, "第一关：石扣只唤醒传送门，不会立即切关")
	aunt.global_position = crowd.global_position
	var slowed_speed := float(aunt.call("_get_chase_speed", 300.0))
	aunt.global_position = crowd.global_position + Vector2(100.0, 0.0)
	var restored_speed := float(aunt.call("_get_chase_speed", 300.0))
	_check(slowed_speed < 100.0 and is_equal_approx(restored_speed, 190.0), "第一关：阿姨进入人群降速，走出人群恢复原追速")

	await _load_scene("res://scenes/guanqia/02_ciqikou.tscn")
	var forge := current_scene.find_child("ForgeSequence", true, false)
	var portal2 := current_scene.find_child("dierguan_chukou", true, false)
	_check(portal2 != null and not bool(portal2.get("_active")), "第二关：锻造前传送门关闭")
	portal2.call("activate")
	_check(bool(portal2.get("_active")) and current_scene.find_child("GoalPortalVisual", true, false).visible, "第二关：锻造完成后可开启传送门")
	var forge_constants: Dictionary = forge.get_script().get_script_constant_map()
	_check(float(forge_constants.get("HEAT_DECAY_BASE", 0.0)) >= 0.19 and float(forge_constants.get("HEAT_DECAY_BASE", 1.0)) <= 0.22 and float(forge_constants.get("HEAT_TAP_GAIN", 0.0)) >= 0.115, "第二关：炉温仍会回退，但连续鼓风容错适度提高")
	forge.set("current_step", 2)
	forge.set("current_round", 2)
	_check(float(forge.call("_current_speed")) >= 2.2 and float(forge.call("_current_speed")) <= 2.3, "第二关：凿击后续轮次保留压力但不再过快")
	_check(float(forge.call("_current_width")) >= 0.12, "第二关：后续轮次判定区不再收缩过度")
	_check(float(forge_constants.get("MISS_TIME_PENALTY", 0.0)) == 5.0, "第二关：单次失误扣时由七秒降至五秒")

	await _load_scene("res://scenes/guanqia/04_fangdong.tscn")
	var bombs := current_scene.find_child("BombWarning", true, false)
	_check(current_scene.find_child("disiguan_chukou", true, false).find_child("GoalPortalVisual", false, false) != null, "第四关：洞口色块替换为传送门")
	var bomb_constants: Dictionary = bombs.get_script().get_script_constant_map()
	_check(float(bombs.get("_cooldown")) <= 3.0 and float(bombs.get("_cooldown")) > 2.8, "第四关：第一枚导弹从约 3 秒开始")
	var early_bounds := bombs.call("_current_cooldown_bounds") as Vector2
	bombs.set("_strike_count", 3)
	var late_bounds := bombs.call("_current_cooldown_bounds") as Vector2
	_check(late_bounds.y <= 0.7 and late_bounds.x < early_bounds.x, "第四关：前三轮逐步加密，第四轮进入最高频率")
	var lm := root.get_node("LevelManager")
	lm.call("register_checkpoint", Vector2(700, 215))
	lm.call("respawn")
	await process_frame
	await process_frame
	var respawned_player := current_scene.find_child("zhujue", true, false) as Node2D
	_check(absf(respawned_player.global_position.x - 80.0) < 2.0 and respawned_player.global_position.y < 210.0, "第四关：失败重来固定回到初始出生点")

	await _load_scene("res://scenes/guanqia/05_hongyadong_return.tscn")
	var final_aunt := current_scene.find_child("chuandanayi", true, false) as CanvasItem
	_check(current_scene.find_child("GoalPortalVisual", true, false) == null and current_scene.find_child("PhotoCameraVisual", true, false) != null, "第五关：按要求保留原拍照点，不替换传送门")
	var aunt_visual := final_aunt.find_child("SkinAnim", true, false) as CanvasItem
	_check(final_aunt.modulate.a == 1.0 and aunt_visual != null and aunt_visual.modulate.a == 1.0 and aunt_visual.self_modulate.a == 1.0, "第五关：传单阿姨节点与立绘均保持完全不透明")
	var aunt_anim := aunt_visual as AnimatedSprite2D
	var aunt_texture := aunt_anim.sprite_frames.get_frame_texture(&"idle", 0) if aunt_anim != null else null
	_check(aunt_texture != null and _texture_source_path(aunt_texture).ends_with("npc/redesign/flyer_lady/idle-transparent.png") and aunt_visual.material == null, "第五关：阿姨换用与原设一致的新实色待机立绘")
	var dialogue_panel := current_scene.find_child("DialoguePanel", true, false) as Control
	dialogue_panel.call("play_line", "传单阿姨", "测试")
	dialogue_panel.call("reset_portraits")
	dialogue_panel.call("play_line", "旁白", "拍照测试")
	var portrait_left := dialogue_panel.get("_pt_left") as TextureRect
	_check(portrait_left.texture == null, "第五关：新拍照对白不会沿用阿姨头像")
	var ds := root.get_node("DialogueSystem")
	ds.call("load_data", "res://assets/dialogue_level5.json")
	ds.call("start_dialogue", "photo")
	ds.call("_on_advance")
	ds.call("_on_advance")
	ds.call("choose", 0)
	await process_frame
	var photo_prelude := ds.find_child("DialoguePreludeImage", true, false) as TextureRect
	var photo_stamp := ds.find_child("PreludeTimestamp", true, false) as Label
	var now := Time.get_datetime_dict_from_system(false)
	var expected_date := "%04d年%02d月%02d日" % [int(now.year), int(now.month), int(now.day)]
	var recorded_stamp := str(root.get_node("GameState").get("photo_timestamp"))
	_check(photo_prelude != null and photo_prelude.texture.resource_path.ends_with("ending-hongyadong-photo.png") and photo_stamp != null and photo_stamp.text.begins_with(expected_date) and photo_stamp.text.contains(":") and photo_stamp.text.ends_with("· 重庆") and photo_stamp.text == recorded_stamp and str(ds.get("last_choice_next")) == "photo_take", "第五关拍照：按下快门时写入实时年月日与时分秒，并保留到结局")
	ds.call("cancel_for_scene_change")
	ds.call("load_data", "res://assets/dialogue_level5.json")
	ds.call("start_dialogue", "photo_not")
	await process_frame
	var prelude := ds.find_child("DialoguePreludeImage", true, false) as TextureRect
	_check(prelude != null and prelude.texture.resource_path.ends_with("ending-hongyadong-people.png") and not dialogue_panel.visible, "第五关不拍照：先单独展示洪崖洞人群画面")
	await create_timer(2.3).timeout
	_check(ds.find_child("DialoguePreludeLayer", true, false) == null and dialogue_panel.visible, "第五关不拍照：画面结束后再恢复原对白")
	ds.call("cancel_for_scene_change")

	var gs := root.get_node("GameState")
	gs.set("ending_choice", "photo")
	await _load_scene("res://scenes/jieju.tscn")
	var photo_bg := current_scene.find_child("EndingBackdrop", true, false) as TextureRect
	var framed_photo := current_scene.find_child("HongyadongPhoto", true, false) as Sprite2D
	var ending_stamp := current_scene.find_child("PhotoTimestamp", true, false) as Label
	_check(photo_bg.texture.resource_path.ends_with("layered-preview.png") and framed_photo.texture.resource_path.ends_with("ending-hongyadong-photo.png") and ending_stamp != null and ending_stamp.text == str(gs.call("get_photo_timestamp", true)), "第五关拍照：洪崖洞照片沿用快门时刻的实时时间戳")
	gs.set("ending_choice", "observe")
	await _load_scene("res://scenes/jieju.tscn")
	var people_bg := current_scene.find_child("EndingBackdrop", true, false) as TextureRect
	_check(people_bg.texture.resource_path.ends_with("layered-preview.png") and current_scene.find_child("UnrecordedMoment", true, false) != null, "第五关不拍照：片尾恢复原版文案与构图")

	await _load_scene("res://scenes/guanqia/03_zhongshan.tscn")
	_check(current_scene.find_child("@Sprite2D@124", true, false) == null, "第三关：移除老周身后的渔船装饰")
	var portal3 := current_scene.find_child("disanguan_chukou", true, false)
	_check(portal3 != null and not bool(portal3.get("_active")), "第三关：交货前终点传送门保持关闭")
	var trade := current_scene.find_child("ChoiceSystem", true, false)
	var dock := current_scene.find_child("laozhou", true, false)
	gs.call("reset_goods")
	trade.call("advance_stage", 3)
	dock.call("on_interact", current_scene.find_child("zhujue", true, false))
	root.get_node("DialogueSystem").call("_finish")
	_check(bool(portal3.get("_active")) and not bool(lm.get("_failing")), "第三关：完好交付后开启传送门，不再自动切关")

	await _load_scene("res://scenes/guanqia/03_zhongshan.tscn")
	gs.call("reset_goods")
	gs.call("apply_goods_event", "stolen")
	trade = current_scene.find_child("ChoiceSystem", true, false)
	trade.call("advance_stage", 3)
	dock = current_scene.find_child("laozhou", true, false)
	dock.call("on_interact", current_scene.find_child("zhujue", true, false))
	_check(int(trade.get("stage")) == 4 and not bool(lm.get("_failing")), "第三关：染布受损后仍必须走完并交到老周手中")
	root.get_node("DialogueSystem").call("_finish")
	_check(bool(lm.get("_failing")) and int(gs.get("goods_integrity")) == 100, "第三关：验货对话结束才失败，并为重试恢复染布")

	paused = false
	print("[RESULT] %s" % ("PASS" if failed == 0 else "FAIL"))
	quit(0 if failed == 0 else 1)
