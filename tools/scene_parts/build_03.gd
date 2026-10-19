extends RefCounted
## 第 3 关（中山古镇·规矩与诚信）构建（Phase 5）。

const WORLD_LEFT := -700.0
const WORLD_RIGHT := 3400.0
const WORLD_WIDTH := WORLD_RIGHT - WORLD_LEFT
const GROUND_CENTER_X := (WORLD_LEFT + WORLD_RIGHT) * 0.5

func run(_tree: SceneTree) -> bool:
	var b = load("res://tools/scene_parts/build_common.gd").new()
	var root: Node2D = b.new_scene("LevelRoot")
	root.set_meta("camera_right_limit", WORLD_RIGHT)

	# (旧生成背景条已移除，远景=每关主背景)
	var ground: StaticBody2D = b.add_node(root, "StaticBody2D", "Ground")
	ground.position = Vector2(GROUND_CENTER_X, 260)
	b.bind_script(ground, "res://scripts/background/prop_grounding.gd")
	var gsh := CollisionShape2D.new()
	var grec := RectangleShape2D.new()
	grec.size = Vector2(WORLD_WIDTH, 40)
	gsh.shape = grec
	ground.add_child(gsh)
	var gv := ColorRect.new()
	gv.color = Color("#5a6470")
	gv.size = Vector2(WORLD_WIDTH, 40)
	gv.position = Vector2(-WORLD_WIDTH * 0.5, -20)
	ground.add_child(gv)

	var player: CharacterBody2D = b.instantiate_scene(
		root, "res://scenes/renwu/zhujue/zhujue.tscn", "zhujue", Vector2(60, 200)
	) as CharacterBody2D

	# ChoiceSystem 节点保留命名兼容；脚本升级为顺序护货路线导演。
	var cs: Node = b.add_node(root, "Node", "ChoiceSystem")
	b.bind_script(cs, "res://scripts/systems/trade_route_manager.gd")

	var ui: CanvasLayer = b.add_node(root, "CanvasLayer", "UI_Base")
	ui.layer = 10
	var dlg := Control.new()
	dlg.name = "DialoguePanel"
	b.bind_script(dlg, "res://scripts/ui/dialogue_panel.gd")
	ui.add_child(dlg)

	# NPC 工厂：四段式
	var npcs := [
		["laozhanggui", 180, "old_shopkeeper", 0, 1],
		["pangzhanggui", 980, "teahouse", 1, 2],
		["banggong", 1820, "helper", 2, 3],
	]
	for n in npcs:
		var nm: String = n[0]
		var px: float = n[1]
		var dialogue_node: String = n[2]
		var required_stage: int = n[3]
		var next_stage: int = n[4]
		b.instantiate_npc(
			root, nm, nm, Vector2(px, 240), "res://scripts/npc/route_npc.gd",
			{"dialogue_node": dialogue_node, "required_stage": required_stage, "next_stage": next_stage}
		)

	# 老周（验货，独立脚本）
	b.instantiate_npc(
		root, "laozhou", "laozhou", Vector2(2940, 240),
		"res://scripts/npc/laozhou.gd"
	)

	# 完整交货后开启，玩家主动穿门进入防空洞年代。
	var exit_area: Area2D = b.add_node(root, "Area2D", "disanguan_chukou")
	exit_area.position = Vector2(3160, 215)
	b.bind_script(exit_area, "res://scripts/systems/locked_exit_portal.gd")
	var exit_shape := CollisionShape2D.new()
	var exit_rect := RectangleShape2D.new()
	exit_rect.size = Vector2(50, 90)
	exit_shape.shape = exit_rect
	exit_shape.position = Vector2(0, -45)
	exit_area.add_child(exit_shape)
	b.add_goal_portal_visual(exit_area, false)

	# 货包（交互查看）
	var bag: Area2D = b.add_node(root, "Area2D", "disanguan_huobao")
	bag.position = Vector2(300, 215)
	b.bind_script(bag, "res://scripts/npc/npc_base.gd")
	var bsh := CollisionShape2D.new()
	var brec := RectangleShape2D.new()
	brec.size = Vector2(26, 18)
	bsh.shape = brec
	bag.add_child(bsh)
	var bvis := Sprite2D.new()
	bvis.name = "CargoVisual"
	bvis.texture = load("res://assets/production/props/gameplay/cargo-intact.png")
	bvis.position = Vector2(0, -20)
	bvis.set_script(load("res://scripts/systems/cargo_visual.gd"))
	bag.add_child(bvis)
	var bpr := ColorRect.new()
	bpr.name = "Prompt"
	bpr.color = Color("#7fd4ff")
	bpr.size = Vector2(12, 12)
	bpr.position = Vector2(-6, -43)
	bag.add_child(bpr)
	bag.set("dialogue_file", "res://assets/dialogue_level3.json")
	bag.set("dialogue_node", "goods_bag")

	# 三段护送危险：都可通过等待或跳跃躲避；一旦擦碰只记录货损，仍须走完全程。
	_add_cargo_hazard(root, b, "RouteHazard1", 1, 650.0, "stolen", "挑担人", Color("#b78653"), 42.0, 1.12)
	_add_cargo_hazard(root, b, "RouteHazard2", 2, 1390.0, "cheated", "巷口水花", Color("#6f9fac"), 28.0, 1.45)
	_add_cargo_hazard(root, b, "RouteHazard3", 3, 2380.0, "robbed", "湿滑栈桥人流", Color("#708476"), 54.0, 1.28)

	var cp: Area2D = b.add_node(root, "Area2D", "Checkpoint")
	cp.position = Vector2(1700, 215)
	b.bind_script(cp, "res://scripts/systems/checkpoint.gd")
	var cpsh := CollisionShape2D.new()
	var cprec := RectangleShape2D.new()
	cprec.size = Vector2(30, 60)
	cpsh.shape = cprec
	cpsh.position = Vector2(0, -30)
	cp.add_child(cpsh)

	# --- Phase 8：背景系统（视差5层 + WorldEnvironment + LightRig）---
	var pbg = b.make_background(root, [Color("#5b6670"), Color("#7e8b99"), Color("#9aa88f"), Color("#b7c0a8"), Color("#4f5a4a")], "03", WORLD_LEFT, WORLD_RIGHT)
	b.add_scene_art(pbg, ground, "03", WORLD_LEFT, WORLD_RIGHT)
	b.make_environment(root, Color("#5b6670"))
	b.make_light_rig(root, Color(0.85, 0.88, 0.9), [[640, 120, "#ffd9a0", 0.8, 80], [1260, 120, "#ffcf8a", 0.5, 60], [2050, 120, "#ffcf8a", 0.5, 60], [2860, 120, "#ffd9a0", 0.62, 70]])

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

	b.add_object_behind(ground, "res://assets/objects/teahouse.png", 980.0, 205.0)

	var ok: bool = b.save_scene(root, "res://scenes/guanqia/03_zhongshan.tscn")
	root.free()
	return ok

func _add_cargo_hazard(root: Node2D, b: RefCounted, node_name: String, stage: int, x: float, event_name: String, title: String, accent: Color, span: float, speed: float) -> void:
	var hazard: Area2D = b.add_node(root, "Area2D", node_name)
	# 原点就是脚底线；人物与担子允许略压住路面，避免悬空感。
	hazard.position = Vector2(x, 260)
	b.bind_script(hazard, "res://scripts/systems/cargo_route_hazard.gd")
	hazard.set("required_stage", stage)
	hazard.set("event_name", event_name)
	hazard.set("hazard_name", title)
	hazard.set("motion_span", span)
	hazard.set("motion_speed", speed)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 50)
	shape.shape = rect
	shape.position = Vector2(0, -24)
	hazard.add_child(shape)
	var visual := Node2D.new()
	visual.name = "HazardVisual"
	visual.z_index = 19
	hazard.add_child(visual)
	var carrier := Sprite2D.new()
	carrier.name = "Carrier"
	carrier.texture = load("res://assets/npc_anim/helper.png")
	carrier.hframes = 8
	carrier.frame = clampi(stage + 1, 0, 7)
	# 旧 helper 图集每格真实人物高度约 467px。按主角 70px 可见身高缩放，
	# 再把鞋底对齐主角站立时的世界脚线（地表上压入约 7px）。
	carrier.position = Vector2(0, -42)
	carrier.scale = Vector2(0.15, 0.15)
	visual.add_child(carrier)
	var pole := ColorRect.new()
	pole.color = Color("#4b3831")
	pole.position = Vector2(-2, -48)
	pole.size = Vector2(4, 42)
	visual.add_child(pole)
	for side in [-1.0, 1.0]:
		var basket := Polygon2D.new()
		basket.polygon = PackedVector2Array([Vector2(side * 4, -28), Vector2(side * 22, -26), Vector2(side * 18, -10), Vector2(side * 6, -12)])
		basket.color = accent
		visual.add_child(basket)
	var warning := Label.new()
	warning.text = "!"
	warning.position = Vector2(-6, -70)
	warning.add_theme_font_size_override("font_size", 16)
	warning.add_theme_color_override("font_color", Color("#ffd166"))
	warning.add_theme_color_override("font_outline_color", Color("#3a2720"))
	warning.add_theme_constant_override("outline_size", 2)
	visual.add_child(warning)
