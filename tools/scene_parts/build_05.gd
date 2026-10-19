extends RefCounted
## 第 5 关（洪崖洞·归来）构建（Phase 7）：步行模拟 + 4 触发点，无失败条件。

const WORLD_LEFT := -700.0
const WORLD_RIGHT := 3600.0
const WORLD_WIDTH := WORLD_RIGHT - WORLD_LEFT
const GROUND_CENTER_X := (WORLD_LEFT + WORLD_RIGHT) * 0.5

func run(_tree: SceneTree) -> bool:
	var b = load("res://tools/scene_parts/build_common.gd").new()
	var root: Node2D = b.new_scene("LevelRoot")
	root.set_meta("camera_right_limit", WORLD_RIGHT)

	# (旧生成背景条已移除，远景=每关主背景)
	var ground: StaticBody2D = b.add_node(root, "StaticBody2D", "Ground")
	ground.position = Vector2(GROUND_CENTER_X, 260)
	var gsh := CollisionShape2D.new()
	var grec := RectangleShape2D.new()
	grec.size = Vector2(WORLD_WIDTH, 40)
	gsh.shape = grec
	ground.add_child(gsh)
	var gv := ColorRect.new()
	gv.color = Color("#a8a08a")
	gv.size = Vector2(WORLD_WIDTH, 40)
	gv.position = Vector2(-WORLD_WIDTH * 0.5, -20)
	ground.add_child(gv)

	var player: CharacterBody2D = b.instantiate_scene(
		root, "res://scenes/renwu/zhujue/zhujue.tscn", "zhujue", Vector2(60, 200)
	) as CharacterBody2D

	var ui: CanvasLayer = b.add_node(root, "CanvasLayer", "UI_Base")
	ui.layer = 10
	var dlg := Control.new()
	dlg.name = "DialoguePanel"
	b.bind_script(dlg, "res://scripts/ui/dialogue_panel.gd")
	ui.add_child(dlg)
	var memory_route: Node = b.add_node(root, "Node", "MemoryRoute")
	b.bind_script(memory_route, "res://scripts/systems/memory_route.gd")

	# 交互物工厂
	var triggers := [
		["diwuguan_mupai", 280, "#8a6a3b", 40, "board", "res://scripts/npc/memory_interactable.gd"],
		["diwuguan_jiuchengqiang", 1180, "#827364", 34, "old_wall", "res://scripts/npc/memory_interactable.gd"],
		["diwuguan_jingguandian", 2250, "#7fa8c9", 26, "view_spot", "res://scripts/npc/memory_interactable.gd"],
		["diwuguan_denghuo", 2760, "#d59b4f", 30, "city_lights", "res://scripts/npc/memory_interactable.gd"],
		["diwuguan_zhaoxiangdian", 3230, "#c9a27f", 26, "photo", "res://scripts/npc/photo_spot.gd"],
	]
	for t in triggers:
		var nm: String = t[0]
		var px: float = t[1]
		var col: Color = Color(t[2])
		var h: float = t[3]
		var dnode: String = t[4]
		var script_p: String = t[5]
		var a: Area2D = b.add_node(root, "Area2D", nm)
		a.position = Vector2(px, 215)
		b.bind_script(a, script_p)
		var ash := CollisionShape2D.new()
		var arec := RectangleShape2D.new()
		arec.size = Vector2(34, 46)
		ash.shape = arec
		ash.position = Vector2(0, -23)
		a.add_child(ash)
		_add_trigger_visual(a, dnode, col)
		var pr := ColorRect.new()
		pr.name = "Prompt"
		pr.color = Color(0.05, 0.08, 0.12, 0.94)
		pr.size = Vector2(18, 18)
		var prompt_y := -78.0
		if dnode == "old_wall":
			prompt_y = -138.0
		elif dnode == "city_lights":
			prompt_y = -102.0
		elif dnode == "view_spot":
			prompt_y = -94.0
		elif dnode == "photo":
			prompt_y = -90.0
		pr.position = Vector2(-9, prompt_y)
		pr.z_index = 35
		pr.visible = false
		var key_label := Label.new()
		key_label.name = "KeyLabel"
		key_label.text = "E"
		key_label.position = Vector2(5, 0)
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color("#ffd166"))
		pr.add_child(key_label)
		a.add_child(pr)
		a.set("dialogue_file", "res://assets/dialogue_level5.json")
		a.set("dialogue_node", dnode)
		if dnode == "board":
			a.set("memory_id", "board")
		elif dnode == "old_wall":
			a.set("memory_id", "wall")
		elif dnode == "view_spot":
			a.set("memory_id", "view")
		elif dnode == "city_lights":
			a.set("memory_id", "lights")

	# 讲历史老人使用共享 NPC 场景；其它条目仍是关卡专属交互点。
	b.instantiate_npc(
		root, "jianglishilaoren", "jianglishilaoren", Vector2(720, 240),
		"res://scripts/npc/memory_interactable.gd",
		{"dialogue_node": "old_man", "memory_id": "old_man"}
	)

	# 传单阿姨（内心 OS 触发点，纯文本）
	b.instantiate_npc(
		root, "chuandanayi", "chuandanayi", Vector2(1710, 240),
		"res://scripts/npc/memory_interactable.gd",
		{"dialogue_node": "flyer_lady_os", "memory_id": "flyer"}
	)

	# --- Phase 8：背景系统（视差5层 + WorldEnvironment + LightRig）---
	var pbg = b.make_background(root, [Color("#d8e2ef"), Color("#cfe0d8"), Color("#f0d9a0"), Color("#b7c49a"), Color("#8f9480")], "05", WORLD_LEFT, WORLD_RIGHT)
	b.add_scene_art(pbg, ground, "05", WORLD_LEFT, WORLD_RIGHT)
	b.make_environment(root, Color("#f0d9a0"))
	b.make_light_rig(root, Color(0.95, 0.93, 0.88), [[300, 130, "#fff3d6", 0.4, 60], [1180, 80, "#ffeecb", 0.42, 64], [2250, 60, "#d8edff", 0.5, 70], [2760, 80, "#ffd166", 0.58, 66], [3230, 70, "#ffeecb", 0.5, 70]])

	# 地图两端边界墙
	for ew in [[WORLD_LEFT - 12.0, -1], [WORLD_RIGHT + 12.0, 1]]:
		var ew2 := StaticBody2D.new()
		ew2.name = "EdgeWall"
		ew2.position = Vector2(ew[0], 140)
		var esh2 := CollisionShape2D.new()
		var erec2 := RectangleShape2D.new()
		erec2.size = Vector2(40, 320)
		esh2.shape = erec2
		ew2.add_child(esh2)
		root.add_child(ew2)
	# 地面向下填充（640x360 视口底部不露空）
	var gfill := ColorRect.new()
	gfill.name = "GroundFill"
	gfill.color = Color("#232a33")
	gfill.size = Vector2(WORLD_WIDTH, 130)
	gfill.position = Vector2(-WORLD_WIDTH * 0.5, 0)
	ground.add_child(gfill)

	var ok: bool = b.save_scene(root, "res://scenes/guanqia/05_hongyadong_return.tscn")
	root.free()
	return ok

func _add_trigger_visual(area: Area2D, kind: String, _accent: Color) -> void:
	var visual := Node2D.new()
	visual.name = "Visual"
	visual.z_index = 15
	area.add_child(visual)
	match kind:
		"board":
			var board_texture: Texture2D = load("res://assets/production/props/info_board/info-board.png")
			if board_texture != null:
				var sprite := Sprite2D.new()
				sprite.set_script(load("res://scripts/background/interactive_prop_grounding.gd"))
				sprite.name = "InfoBoardVisual"
				sprite.texture = board_texture
				sprite.scale = Vector2.ONE * (64.0 / float(board_texture.get_height()))
				sprite.position = Vector2(0, -7)
				visual.add_child(sprite)
		"view_spot":
			_add_prop_sprite(
				visual,
				"ScenicViewerVisual",
				"res://assets/production/props/scenic_viewer/scenic-viewer.png",
				78.0
			)
		"photo":
			_add_prop_sprite(
				visual,
				"PhotoCameraVisual",
				"res://assets/production/props/photo_camera/photo-camera.png",
				76.0
			)
		"old_wall":
			_add_prop_sprite(visual, "OldGateVisual", "res://assets/production/props/memory_landmarks/old-gate-v1.png", 132.0)
		"city_lights":
			_add_prop_sprite(visual, "CityLightsVisual", "res://assets/production/props/memory_landmarks/city-lights-railing-v1.png", 88.0)

func _add_prop_sprite(parent: Node2D, node_name: String, texture_path: String, display_height: float) -> void:
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.set_script(load("res://scripts/background/interactive_prop_grounding.gd"))
	sprite.name = node_name
	sprite.texture = texture
	var display_scale := display_height / float(texture.get_height())
	sprite.scale = Vector2.ONE * display_scale
	sprite.position = Vector2(0, -display_height * 0.5)
	parent.add_child(sprite)
