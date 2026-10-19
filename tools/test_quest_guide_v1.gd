extends SceneTree

var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func settle() -> void:
	for i in range(20): await process_frame

func _run() -> void:
	var guide: Node = root.get_node("QuestGuide")
	var companion: Node = root.get_node("Companion")
	var paths: Array[String] = root.get_node("LevelManager").SCENES.duplicate()
	paths.append(root.get_node("LevelManager").FUTURE_SCENE)
	var expected: Array[String] = ["diyiguan_husongdizhuan", "laojiangren", "laozhanggui", "NPC_Follower", "diwuguan_mupai", "MemoryDrone"]
	for i in range(6):
		change_scene_to_file(paths[i])
		await settle()
		var scene: Node = current_scene
		var player: CharacterBody2D = scene.get_node("zhujue")
		player.frozen = false
		if i == 5:
			scene._start_chase()
			scene._story_panel.hide()
		await settle()
		var arrival: Node = root.get_node("ChapterArrival")
		check(arrival.is_presenting() and not guide._layer.visible, "第%d关先展示时空字幕，不叠加任务提示" % (i + 1))
		arrival._process(3.0)
		await process_frame
		await process_frame
		check(guide.level == i + 1 and is_instance_valid(guide.target), "第%d关已绑定任务目标" % (i + 1))
		check(is_instance_valid(guide.target) and str(guide.target.name).begins_with(expected[i]), "第%d关初始箭头指向正确对象" % (i + 1))
		check(companion._root.visible and companion._root.get_node_or_null("CompanionButton") == null, "第%d关渝灯跟随显示且不抢交互键" % (i + 1))
		check(guide._toast.visible, "第%d关显示短时操作提示" % (i + 1))
		guide._process(5.6)
		check(not guide._toast.visible, "第%d关提示超时自动消失" % (i + 1))
		root.get_node("DialogueSystem").active = true
		await process_frame
		await process_frame
		check((companion._root.visible if i == 3 else not companion._root.visible) and not guide._layer.visible, "第%d关对话期间隐藏引导（洞内精灵继续照明）" % (i + 1))
		root.get_node("DialogueSystem").active = false
		await settle()
		if i == 1:
			scene.get_node("laojiangren").set("_completed", true)
			guide.refresh()
			check(guide.target.name == &"HeatStation", "老匠人对话后指向鼓风工位")
			scene.get_node("ForgeSequence").current_step = 1
			guide.refresh()
			check(guide.target.name == &"QuenchStation", "鼓风完成后指向淬火工位")
		if i == 2:
			scene.get_node("ChoiceSystem").advance_stage(2)
			await settle()
			check(guide.target.name == &"banggong", "第三关路线事件自动更新目标")
		if i == 3:
			for npc in scene.get_node("NPC_Group").get_children():
				if npc.has_meta("rescue_stage"): npc.set_meta("rescued", true)
			guide.refresh()
			check(guide.target.name == &"disiguan_chukou", "难民全部救出后指向洞口")
		if i == 4:
			scene.get_node("MemoryRoute").collected["board"] = true
			guide.refresh()
			check(guide.target.name == &"jianglishilaoren", "已收集的记忆不再标记")
		if i == 5:
			scene.player._on_zone_entered(scene.get_node("MemoryTerminal"))
			await process_frame
			check(scene.player._interaction_hint_time > 0, "靠近可交互物短暂显示E提示")
			scene.player._interaction_hint_time = 0.01
			scene.player._physics_process(0.1)
			check(not scene.player._interaction_hint.visible, "E提示自动消失但不禁用交互")
			var before: Vector2 = companion._root.position
			player.position.y -= 40
			player.velocity = Vector2.ZERO
			await settle()
			check(companion._root.position.distance_to(before) > 1, "渝灯位置随主角移动而更新")
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://preview/quest-guide-level%d-v1.png" % (i + 1))
	change_scene_to_file("res://scenes/kaishi.tscn")
	await settle()
	check(not companion._root.visible and not guide._layer.visible, "返回菜单后清理跟随和任务标记")
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
