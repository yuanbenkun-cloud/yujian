extends RefCounted
## 第 1 关（洪崖洞·迷途）v3：单一追兵 + 会预警/退场的动态人群路障。

const WORLD_LEFT := -700.0
const WORLD_RIGHT := 3650.0
const WORLD_WIDTH := WORLD_RIGHT - WORLD_LEFT
const GROUND_CENTER_X := (WORLD_LEFT + WORLD_RIGHT) * 0.5

func run(_tree: SceneTree) -> bool:
	var b = load("res://tools/scene_parts/build_common.gd").new()
	var root: Node2D = b.new_scene("LevelRoot")
	root.set_meta("camera_right_limit", WORLD_RIGHT)

	# (旧生成背景条已移除，远景=每关主背景)
	# 加长后的完整追逐街段。
	var ground: StaticBody2D = b.add_node(root, "StaticBody2D", "Ground")
	ground.position = Vector2(GROUND_CENTER_X, 260)
	b.bind_script(ground, "res://scripts/background/prop_grounding.gd")
	var gsh := CollisionShape2D.new()
	var grec := RectangleShape2D.new()
	grec.size = Vector2(WORLD_WIDTH, 40)
	gsh.shape = grec
	ground.add_child(gsh)
	var gv := ColorRect.new()
	gv.color = Color("#39424e")
	gv.size = Vector2(WORLD_WIDTH, 40)
	gv.position = Vector2(-WORLD_WIDTH * 0.5, -20)
	ground.add_child(gv)

	# 地图两端边界墙（防坠出地图）
	for ew in [[WORLD_LEFT - 12.0, -1], [WORLD_RIGHT + 12.0, 1]]:
		var eb := StaticBody2D.new()
		eb.name = "EdgeWall"
		eb.position = Vector2(ew[0], 140)
		var esh := CollisionShape2D.new()
		var erec := RectangleShape2D.new()
		erec.size = Vector2(40, 320)
		esh.shape = erec
		eb.add_child(esh)
		root.add_child(eb)

	# 主角使用独立 PackedScene；碰撞、相机与动画只维护一份。
	var player: CharacterBody2D = b.instantiate_scene(
		root, "res://scenes/renwu/zhujue/zhujue.tscn", "zhujue", Vector2(-620, 200)
	) as CharacterBody2D
	var camera := player.get_node_or_null("zhujue_shexiangji") as Camera2D
	if camera != null:
		camera.limit_right = int(WORLD_RIGHT)

	# HeartSystem + UI
	var heart: Node = b.add_node(root, "Node", "HeartSystem")
	b.bind_script(heart, "res://scripts/systems/heart_system.gd")
	var ui: CanvasLayer = b.add_node(root, "CanvasLayer", "UI_Base")
	ui.layer = 10
	var hearts := Label.new()
	hearts.name = "UI_Hearts"
	hearts.text = "♥♥♥"
	hearts.position = Vector2(8, 4)
	hearts.add_theme_font_size_override("font_size", 18)
	hearts.add_theme_color_override("font_color", Color("#ff5c5c"))
	ui.add_child(hearts)
	var chase_hud := Label.new()
	chase_hud.name = "UI_Chase"
	chase_hud.text = "追逐  ▱▱▱▱▱▱▱▱"
	chase_hud.position = Vector2(438, 7)
	chase_hud.size = Vector2(190, 24)
	chase_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chase_hud.add_theme_font_size_override("font_size", 12)
	chase_hud.visible = false
	ui.add_child(chase_hud)
	var notice := Label.new()
	notice.name = "UI_Notice"
	notice.text = ""
	notice.position = Vector2(8, 55)
	notice.size = Vector2(464, 40)
	notice.add_theme_font_size_override("font_size", 12)
	notice.add_theme_color_override("font_color", Color("#ffe9c7"))
	notice.visible = false
	ui.add_child(notice)
	var dlg := Control.new()
	dlg.name = "DialoguePanel"
	b.bind_script(dlg, "res://scripts/ui/dialogue_panel.gd")
	ui.add_child(dlg)

	# 存档点
	var cp: Area2D = b.add_node(root, "Area2D", "Checkpoint")
	cp.position = Vector2(140, 215)
	b.bind_script(cp, "res://scripts/systems/checkpoint.gd")
	var cpsh := CollisionShape2D.new()
	var cprec := RectangleShape2D.new()
	cprec.size = Vector2(30, 60)
	cpsh.shape = cprec
	cpsh.position = Vector2(0, -30)
	cp.add_child(cpsh)

	# 传单阿姨（共享 NPC 场景 + 本关专属追逐脚本）
	b.instantiate_npc(
		root, "chuandanayi", "chuandanayi", Vector2(-420, 240),
		"res://scripts/npc/flyer_lady.gd"
	)

	# 追逐管理器；玩家漏按交互时，越过开场位置也会自动开追。
	var cm: Node = b.add_node(root, "Node", "ChaseManager")
	b.bind_script(cm, "res://scripts/systems/chase_manager.gd")
	var obstacle_rig: Node2D = b.add_node(root, "Node2D", "ChaseObstacleRig")
	b.bind_script(obstacle_rig, "res://scripts/systems/chase_obstacle_rig.gd")
	var chase_start: Area2D = b.add_node(root, "Area2D", "ChaseStart")
	chase_start.position = Vector2(-330, 180)
	b.bind_script(chase_start, "res://scripts/systems/chase_start.gd")
	var start_shape := CollisionShape2D.new()
	var start_rect := RectangleShape2D.new()
	start_rect.size = Vector2(24, 160)
	start_shape.shape = start_rect
	chase_start.add_child(start_shape)

	# 七组专用现代路人形成“疏—密—疏”的追逐节奏；2、4、6 组位于低顶棚下。
	b.make_crowd(root, 1, 720, 88, 52)
	b.make_crowd(root, 2, 1040, 72, 48)
	b.make_crowd(root, 3, 1370, 96, 54)
	b.make_crowd(root, 4, 1700, 76, 49)
	b.make_crowd(root, 5, 2040, 92, 53)
	b.make_crowd(root, 6, 2380, 74, 48)
	b.make_crowd(root, 7, 2720, 90, 52)
	for obstacle_data in [[1, 870.0], [2, 1530.0], [3, 2200.0], [4, 2870.0]]:
		_add_street_obstacle(root, int(obstacle_data[0]), float(obstacle_data[1]))

	# 加长后增加中段存档点，失败重来仍保留完整后半程压力。
	var cp_mid: Area2D = b.add_node(root, "Area2D", "CheckpointMid")
	cp_mid.position = Vector2(1870, 215)
	b.bind_script(cp_mid, "res://scripts/systems/checkpoint.gd")
	var cp_mid_shape := CollisionShape2D.new()
	var cp_mid_rect := RectangleShape2D.new()
	cp_mid_rect.size = Vector2(30, 60)
	cp_mid_shape.shape = cp_mid_rect
	cp_mid_shape.position = Vector2(0, -30)
	cp_mid.add_child(cp_mid_shape)

	# 装饰灯笼
	for lp in [[600, 96], [1500, 96], [2460, 96], [3060, 96]]:
		var ltex: Texture2D = load("res://assets/generated/obj_lantern.png")
		if ltex != null:
			var lsp := Sprite2D.new()
			lsp.name = "OBJ_Lantern"
			lsp.texture = ltex
			lsp.centered = false
			lsp.position = Vector2(lp[0] - 16.0, lp[1])
			root.add_child(lsp)

	# 历史木牌（对话，信息节点 info_board）
	var board: Area2D = b.add_node(root, "Area2D", "diyiguan_mupai")
	board.position = Vector2(3010, 210)
	b.bind_script(board, "res://scripts/npc/npc_base.gd")
	var bsh := CollisionShape2D.new()
	var brect := RectangleShape2D.new()
	brect.size = Vector2(40, 40)
	bsh.shape = brect
	bsh.position = Vector2(0, -20)
	board.add_child(bsh)
	var board_texture: Texture2D = load("res://assets/production/props/info_board/info-board.png")
	if board_texture != null:
		var bvis := Sprite2D.new()
		bvis.name = "InfoBoardVisual"
		bvis.texture = board_texture
		bvis.scale = Vector2.ONE * (64.0 / float(board_texture.get_height()))
		bvis.position = Vector2(0, -7)
		bvis.z_index = 15
		b.bind_script(bvis, "res://scripts/background/interactive_prop_grounding.gd")
		bvis.set("target_ground_y", 247.0)
		board.add_child(bvis)
	var bpr := ColorRect.new()
	bpr.name = "Prompt"
	bpr.color = Color("#7fd4ff")
	bpr.size = Vector2(12, 12)
	bpr.position = Vector2(-6, -50)
	board.add_child(bpr)
	board.set("dialogue_file", "res://assets/dialogue_level1.json")
	board.set("dialogue_node", "info_board")

	# 第一关终点：先踩下古墙石扣，再走进显现的时空门。
	var tile: Area2D = b.add_node(root, "Area2D", "diyiguan_husongdizhuan")
	tile.position = Vector2(3180, 240)
	b.bind_script(tile, "res://scripts/systems/loose_tile.gd")
	tile.set("portal_path", NodePath("../FirstExitPortal"))
	var tsh := CollisionShape2D.new()
	var trect := RectangleShape2D.new()
	trect.size = Vector2(34, 8)
	tsh.shape = trect
	tile.add_child(tsh)
	var tile_tex: Texture2D = load("res://assets/production/props/gameplay/loose-tile-runtime.png")
	if tile_tex != null:
		var tile_visual := Sprite2D.new()
		tile_visual.name = "StoneButtonVisual"
		tile_visual.texture = tile_tex
		tile_visual.position = Vector2(0, -5)
		tile_visual.scale = Vector2.ONE * 0.55
		tile_visual.z_index = 16
		tile.add_child(tile_visual)
	var portal: Area2D = b.add_node(root, "Area2D", "FirstExitPortal")
	portal.position = Vector2(3300, 240)
	b.bind_script(portal, "res://scripts/systems/locked_exit_portal.gd")
	portal.set("starts_active", false)
	var portal_shape := CollisionShape2D.new()
	var portal_rect := RectangleShape2D.new()
	portal_rect.size = Vector2(42, 80)
	portal_shape.shape = portal_rect
	portal_shape.position = Vector2(0, -40)
	portal.add_child(portal_shape)
	b.add_goal_portal_visual(portal, false)

	# 背景系统
	var pbg = b.make_background(root, [Color("#0a0f22"), Color("#14204a"), Color("#3a4f8f"), Color("#6b4a6b"), Color("#23273f")], "01", WORLD_LEFT, WORLD_RIGHT)
	b.add_scene_art(pbg, ground, "01", WORLD_LEFT, WORLD_RIGHT)
	b.make_environment(root, Color("#0a0f22"))
	b.make_light_rig(root, Color(1.0, 0.9, 0.75), [[540, 70, "#ff8fb3", 0.9, 60], [1120, 60, "#7fd4ff", 0.7, 60], [1780, 80, "#ffd166", 0.6, 40], [2500, 72, "#ff8fb3", 0.72, 52], [3160, 68, "#ffd166", 0.62, 46]])

	# 地面向下填充（640x360 视口底部不露空）
	var gfill := ColorRect.new()
	gfill.name = "GroundFill"
	gfill.color = Color("#232a33")
	gfill.size = Vector2(WORLD_WIDTH, 130)
	gfill.position = Vector2(-WORLD_WIDTH * 0.5, 0)
	ground.add_child(gfill)

	b.add_object_behind(ground, "res://assets/objects/stilt.png", 3370.0, 210.0)

	var ok: bool = b.save_scene(root, "res://scenes/guanqia/01_hongyadong.tscn")
	root.free()
	return ok

func _add_street_obstacle(root: Node2D, obstacle_id: int, x: float) -> void:
	var barrier := StaticBody2D.new()
	barrier.name = "StreetObstacle%d" % obstacle_id
	barrier.position = Vector2(x, 228)
	barrier.z_index = 23
	barrier.set_meta("jumpable", true)
	root.add_child(barrier)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38, 24)
	shape.shape = rect
	barrier.add_child(shape)
	var board := Polygon2D.new()
	board.name = "BarrierBoard"
	board.polygon = PackedVector2Array([Vector2(-22, -10), Vector2(21, -10), Vector2(18, 1), Vector2(-19, 1)])
	board.color = Color("#d58a3f")
	barrier.add_child(board)
	for stripe in range(3):
		var mark := Polygon2D.new()
		mark.name = "ReflectiveStripe%d" % stripe
		var sx := -15.0 + float(stripe) * 14.0
		mark.polygon = PackedVector2Array([Vector2(sx, -9), Vector2(sx + 5, -9), Vector2(sx + 1, 0), Vector2(sx - 4, 0)])
		mark.color = Color("#f5d995")
		barrier.add_child(mark)
	for leg_x in [-14.0, 14.0]:
		var leg := ColorRect.new()
		leg.color = Color("#514148")
		leg.position = Vector2(leg_x - 2.0, 1.0)
		leg.size = Vector2(4, 11)
		barrier.add_child(leg)
