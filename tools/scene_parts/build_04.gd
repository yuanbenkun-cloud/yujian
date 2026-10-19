extends RefCounted
## 第 4 关（防空洞·黑暗中的脊梁）构建（Phase 6）。

const WORLD_LEFT := -700.0
const WORLD_RIGHT := 3450.0
const WORLD_WIDTH := WORLD_RIGHT - WORLD_LEFT
const GROUND_CENTER_X := (WORLD_LEFT + WORLD_RIGHT) * 0.5

func run(_tree: SceneTree) -> bool:
	var b = load("res://tools/scene_parts/build_common.gd").new()
	var root: Node2D = b.new_scene("LevelRoot")
	root.set_meta("camera_right_limit", WORLD_RIGHT)

	# 洞顶与洞壁已经进入独立的远景/中景透明景片，不再叠加旧纯色横条。

	var ground: StaticBody2D = b.add_node(root, "StaticBody2D", "Ground")
	ground.position = Vector2(GROUND_CENTER_X, 260)
	var gsh := CollisionShape2D.new()
	var grec := RectangleShape2D.new()
	grec.size = Vector2(WORLD_WIDTH, 40)
	gsh.shape = grec
	ground.add_child(gsh)
	var gv := ColorRect.new()
	gv.color = Color("#3a3a42")
	gv.size = Vector2(WORLD_WIDTH, 40)
	gv.position = Vector2(-WORLD_WIDTH * 0.5, -20)
	ground.add_child(gv)

	# 主角使用独立 PackedScene；由全局 Companion 精灵提供照明，不再追加手提灯。
	var player: CharacterBody2D = b.instantiate_scene(
		root, "res://scenes/renwu/zhujue/zhujue.tscn", "zhujue", Vector2(80, 200)
	) as CharacterBody2D
	var camera := player.get_node_or_null("zhujue_shexiangji") as Camera2D
	if camera != null:
		camera.limit_right = int(WORLD_RIGHT)
	# UI（DialoguePanel + 轰炸红色警示）
	var ui: CanvasLayer = b.add_node(root, "CanvasLayer", "UI_Base")
	ui.layer = 10
	var flash := ColorRect.new()
	flash.name = "UI_BombFlash"
	flash.color = Color(1.0, 0.1, 0.1)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.modulate.a = 0.0
	flash.visible = false
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	var bomb_status := Label.new()
	bomb_status.name = "UI_BombStatus"
	bomb_status.position = Vector2(96, 18)
	bomb_status.size = Vector2(448, 28)
	bomb_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bomb_status.add_theme_font_size_override("font_size", 13)
	bomb_status.add_theme_color_override("font_color", Color("#ffd166"))
	bomb_status.visible = false
	ui.add_child(bomb_status)
	var escort_status := Label.new()
	escort_status.name = "UI_EscortStatus"
	escort_status.position = Vector2(16, 48)
	escort_status.size = Vector2(250, 24)
	escort_status.add_theme_font_size_override("font_size", 11)
	escort_status.add_theme_color_override("font_color", Color("#ffe0a0"))
	escort_status.add_theme_color_override("font_outline_color", Color("#15100d"))
	escort_status.add_theme_constant_override("outline_size", 3)
	escort_status.visible = true
	ui.add_child(escort_status)
	var dlg := Control.new()
	dlg.name = "DialoguePanel"
	b.bind_script(dlg, "res://scripts/ui/dialogue_panel.gd")
	ui.add_child(dlg)

	# 队伍容器：开场不跟随。三处救援点依次加入 1、2、3 人，队尾自然越来越长。
	var group := Node2D.new()
	group.name = "NPC_Group"
	root.add_child(group)
	var rescue_layout := [[1, 520.0, 1], [2, 1480.0, 2], [3, 2440.0, 3]]
	var follower_id := 1
	for rescue_data in rescue_layout:
		var stage := int(rescue_data[0])
		var rescue_x := float(rescue_data[1])
		var count := int(rescue_data[2])
		for local_index in range(count):
			var offset := (float(local_index) - float(count - 1) * 0.5) * 28.0
			var follower: Area2D = b.instantiate_npc(
				group, "binanzhongqun", "NPC_Follower%d" % follower_id,
				Vector2(rescue_x + offset, 240), "res://scripts/npc/npc_base.gd"
			)
			follower.set_meta("rescue_stage", stage)
			follower.set_meta("recruit_at_x", rescue_x)
			follower.set_meta("rescued", false)
			follower_id += 1
		_add_rescue_marker(root, stage, rescue_x, count)

	# GroupFollower 组件：检测三处救援点，只有获救难民进入跟随队列。
	var gf: Node = b.add_node(root, "Node", "GroupFollower")
	b.bind_script(gf, "res://scripts/npc/group_follower.gd")
	var story_intro: Node = b.add_node(root, "Node", "LevelStoryIntro")
	b.bind_script(story_intro, "res://scripts/systems/level_story_intro.gd")

	# BombWarning 组件
	var bw: Node = b.add_node(root, "Node", "BombWarning")
	b.bind_script(bw, "res://scripts/systems/bomb_warning.gd")
	bw.set("max_strike_x", 3130.0)

	# 六段防空挡板：长距离推进中不断换位，挡板损毁后不能原地等待。
	for shield_data in [[1, 315.0, 92.0], [2, 800.0, 92.0], [3, 1285.0, 92.0], [4, 1770.0, 92.0], [5, 2255.0, 92.0], [6, 2740.0, 92.0]]:
		_add_blast_shield(root, b, int(shield_data[0]), float(shield_data[1]), float(shield_data[2]))

	# 存档点（洞中途）
	var cp: Area2D = b.add_node(root, "Area2D", "Checkpoint")
	cp.position = Vector2(1440, 215)
	b.bind_script(cp, "res://scripts/systems/checkpoint.gd")
	var csh := CollisionShape2D.new()
	var crec := RectangleShape2D.new()
	crec.size = Vector2(30, 60)
	csh.shape = crec
	csh.position = Vector2(0, -30)
	cp.add_child(csh)

	# 出口传送门
	var exit_area: Area2D = b.add_node(root, "Area2D", "disiguan_chukou")
	exit_area.position = Vector2(3230, 215)
	b.bind_script(exit_area, "res://scripts/systems/exit_portal.gd")
	var esh := CollisionShape2D.new()
	var erec := RectangleShape2D.new()
	erec.size = Vector2(50, 90)
	esh.shape = erec
	esh.position = Vector2(0, -45)
	exit_area.add_child(esh)
	b.add_goal_portal_visual(exit_area, true)

	# --- Phase 8：背景系统（视差5层 + WorldEnvironment + LightRig）---
	var pbg = b.make_background(root, [Color("#050508"), Color("#14141a"), Color("#26262e"), Color("#34343e"), Color("#101014")], "04", WORLD_LEFT, WORLD_RIGHT)
	b.add_scene_art(pbg, ground, "04", WORLD_LEFT, WORLD_RIGHT)
	b.make_environment(root, Color("#0a0a0c"))
	b.make_light_rig(root, Color(0.25, 0.25, 0.3), [])

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

	var ok: bool = b.save_scene(root, "res://scenes/guanqia/04_fangdong.tscn")
	root.free()
	return ok

func _add_blast_shield(root: Node2D, b: RefCounted, shield_id: int, x: float, half_width: float) -> void:
	var shield := Node2D.new()
	shield.name = "BlastShield%d" % shield_id
	shield.position = Vector2(x, 128)
	var shield_material := CanvasItemMaterial.new()
	shield_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	shield.material = shield_material
	root.add_child(shield)
	b.bind_script(shield, "res://scripts/systems/blast_shield.gd")
	shield.set("half_width", half_width)
	var safe_zone := ColorRect.new()
	safe_zone.name = "SafeZone"
	safe_zone.color = Color(1.0, 0.76, 0.28, 0.62)
	safe_zone.position = Vector2(-half_width, 98)
	safe_zone.size = Vector2(half_width * 2.0, 3)
	safe_zone.z_index = 30
	shield.add_child(safe_zone)
	_add_native_blast_barrier(shield, half_width)
	var label := Label.new()
	label.name = "Durability"
	label.use_parent_material = true
	label.position = Vector2(-38, -35)
	label.size = Vector2(76, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_outline_color", Color("#211817"))
	label.add_theme_constant_override("outline_size", 2)
	label.z_index = 27
	shield.add_child(label)

func _add_rescue_marker(root: Node2D, stage: int, x: float, count: int) -> void:
	var marker := Node2D.new()
	marker.name = "RescueMarker%d" % stage
	marker.position = Vector2(x, 158)
	marker.z_index = 31
	root.add_child(marker)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	diamond.color = Color("#e8b04b")
	marker.add_child(diamond)
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)])
	inner.color = Color("#fff0c2")
	marker.add_child(inner)
	var label := Label.new()
	label.text = "等待救援 · %d人" % count
	label.position = Vector2(-52, 13)
	label.size = Vector2(104, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#ffe0a0"))
	label.add_theme_color_override("font_outline_color", Color("#19110d"))
	label.add_theme_constant_override("outline_size", 3)
	marker.add_child(label)

func _add_carried_lantern(root: Node2D, player: CharacterBody2D, b: RefCounted) -> void:
	var rig := Node2D.new()
	rig.name = "CarriedLantern"
	rig.position = Vector2(11, -25)
	rig.z_index = 34
	b.bind_script(rig, "res://scripts/player/carried_lantern.gd")
	player.add_child(rig)
	rig.owner = root
	var handle := Line2D.new()
	handle.name = "Handle"
	handle.points = PackedVector2Array([Vector2(-5, -9), Vector2(-4, -14), Vector2(0, -17), Vector2(4, -14), Vector2(5, -9)])
	handle.width = 1.5
	handle.default_color = Color("#39271d")
	rig.add_child(handle)
	handle.owner = root
	var body := Polygon2D.new()
	body.name = "LanternBody"
	body.polygon = PackedVector2Array([Vector2(-6, -9), Vector2(6, -9), Vector2(8, 7), Vector2(5, 11), Vector2(-5, 11), Vector2(-8, 7)])
	body.color = Color("#7a3f22")
	rig.add_child(body)
	body.owner = root
	var glass := Polygon2D.new()
	glass.name = "LanternGlass"
	glass.polygon = PackedVector2Array([Vector2(-4, -7), Vector2(4, -7), Vector2(5, 6), Vector2(-5, 6)])
	glass.color = Color("#ffb94f")
	rig.add_child(glass)
	glass.owner = root
	var flame := Polygon2D.new()
	flame.name = "Flame"
	flame.polygon = PackedVector2Array([Vector2(-2, 4), Vector2(0, -3), Vector2(2, 4)])
	flame.color = Color("#fff2a6")
	rig.add_child(flame)
	flame.owner = root
	var light := PointLight2D.new()
	light.name = "PointLight2D"
	light.texture = _make_lantern_light_texture()
	light.texture_scale = 4.6
	light.color = Color("#ffb85b")
	light.energy = 1.65
	light.shadow_enabled = false
	rig.add_child(light)
	light.owner = root

func _make_lantern_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 0.72, 0.34, 0.62), Color(1.0, 0.35, 0.05, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 96
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func _add_native_blast_barrier(shield: Node2D, half_width: float) -> void:
	var visual := Node2D.new()
	visual.name = "BarrierVisual"
	visual.z_index = 24
	visual.use_parent_material = true
	shield.add_child(visual)
	var barrier_texture := load("res://assets/production/props/gameplay/blast-shield-ai-v2.png") as Texture2D
	if barrier_texture != null:
		var barrier := Sprite2D.new()
		barrier.name = "GeneratedBarrier"
		barrier.texture = barrier_texture
		barrier.centered = true
		barrier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var target_width := half_width * 2.0
		var barrier_scale := target_width / float(barrier_texture.get_width())
		barrier.scale = Vector2.ONE * barrier_scale
		# AI 图上下有透明留白：真实可见底边在原图 y=806，而非纹理 y=887。
		# 挡板根节点位于世界 y=128，把真实底边放到世界 y=246（压入地面 6px）。
		var visible_bottom_from_center := (806.0 - float(barrier_texture.get_height()) * 0.5) * barrier_scale
		barrier.position = Vector2(0, 118.0 - visible_bottom_from_center)
		visual.add_child(barrier)
	for crack_data in [["Crack1", -18.0], ["Crack2", 26.0]]:
		var crack := Line2D.new()
		crack.name = str(crack_data[0])
		var cx := float(crack_data[1])
		crack.points = PackedVector2Array([Vector2(cx, 18), Vector2(cx - 7, 35), Vector2(cx + 3, 48), Vector2(cx - 9, 68)])
		crack.width = 2.0
		crack.default_color = Color("#211817")
		crack.visible = false
		visual.add_child(crack)
