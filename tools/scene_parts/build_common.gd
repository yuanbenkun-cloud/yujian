class_name SceneBuilderCommon
extends RefCounted

## build_common 本身不产出场景（run 恒返回 true），只提供公共辅助。

func run(_tree: SceneTree) -> bool:
	return true

func new_scene(name: String) -> Node2D:
	var root := Node2D.new()
	root.name = name
	return root

func add_node(parent: Node, type: String, node_name: String) -> Node:
	var n: Node = ClassDB.instantiate(type)
	n.name = node_name
	parent.add_child(n)
	return n

func save_scene(root: Node, path: String) -> bool:
	## PackedScene.pack 要求整树节点 owner=root，否则子节点不序列化
	_own_recursive(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	return ResourceSaver.save(packed, path) == OK

func _own_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
		# PackedScene 实例的内部节点由其源场景拥有；继续递归会在外层场景
		# 再序列化一份同名子节点，运行时出现重复碰撞、动画和提示。
		if node.scene_file_path != "":
			return
	for c in node.get_children():
		_own_recursive(c, scene_root)

func make_color_rect(size: Vector2, color: Color, pos: Vector2 = Vector2.ZERO, parent: Node = null) -> ColorRect:
	var cr := ColorRect.new()
	cr.size = size
	cr.position = pos
	cr.color = color
	if parent != null:
		parent.add_child(cr)
	return cr

func make_label(text: String, pos: Vector2, font_size: int = 10, color: Color = Color.WHITE, parent: Node = null) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.position = pos
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", color)
	if parent != null:
		parent.add_child(lb)
	return lb

func bind_script(node: Node, script_path: String) -> Node:
	node.set_script(load(script_path))
	return node

func instantiate_scene(parent: Node, scene_path: String, node_name: String, pos: Vector2) -> Node:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("无法加载场景：" + scene_path)
		return null
	var instance := packed.instantiate()
	instance.name = node_name
	if instance is Node2D:
		instance.position = pos
	parent.add_child(instance)
	return instance

func instantiate_npc(
	parent: Node,
	npc_key: String,
	node_name: String,
	pos: Vector2,
	script_path: String = "res://scripts/npc/npc_base.gd",
	properties: Dictionary = {}
) -> Area2D:
	var scene_path := "res://scenes/renwu/npc/%s/%s.tscn" % [npc_key, npc_key]
	var npc := instantiate_scene(parent, scene_path, node_name, pos) as Area2D
	if npc == null:
		return null
	if script_path != "":
		bind_script(npc, script_path)
	for property_name: String in properties:
		npc.set(property_name, properties[property_name])
	return npc

## ---- Phase 8 背景辅助 ----

## 可复用的五层横向舞台：天空 / 远景 / 中景 / 近雾 / 前景。
func make_background(root: Node, cols: Array, era: String, world_left: float = -700.0, world_right: float = 2500.0) -> ParallaxBackground:
	var packed: PackedScene = load("res://scenes/background/parallax_stage.tscn")
	if packed == null:
		push_error("无法加载共享视差舞台")
		return null
	var pbg := packed.instantiate() as ParallaxBackground
	pbg.name = "BG_Parallax"
	pbg.call("configure", era, cols)
	root.add_child(pbg)
	root.move_child(pbg, 1)
	var ambient := Node2D.new()
	ambient.name = "AmbientLife"
	bind_script(ambient, "res://scripts/background/ambient_life.gd")
	ambient.call("configure", era, world_left, world_right)
	root.add_child(ambient)
	var weather := CanvasLayer.new()
	weather.name = "WeatherSystem"
	bind_script(weather, "res://scripts/background/weather_system.gd")
	weather.call("configure", era, world_left, world_right)
	root.add_child(weather)
	return pbg

## WorldEnvironment：glow + adjustments + vignette（bg_col 为环境底色）
func make_environment(root: Node, bg_col: Color) -> void:
	var wenv := WorldEnvironment.new()
	wenv.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg_col
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_bloom = 0.1
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0
	e.adjustment_saturation = 1.0
	wenv.environment = e
	root.add_child(wenv)

## LightRig：CanvasModulate 时代色调 + 若干点光源；lights=[x, y, colorhex, energy, radius]
func make_light_rig(root: Node, tone: Color, lights: Array) -> void:
	var rig := Node2D.new()
	rig.name = "LightRig"
	root.add_child(rig)
	var cm := CanvasModulate.new()
	cm.name = "CanvasModulate"
	cm.color = tone
	rig.add_child(cm)
	for L in lights:
		var p := PointLight2D.new()
		p.name = "PointLight"
		p.position = Vector2(L[0], L[1])
		p.color = Color(L[2])
		p.energy = L[3]
		p.texture_scale = L[4] / 32.0
		rig.add_child(p)
	bind_script(rig, "res://scripts/background/light_rig.gd")

## 人群路障：物理阻挡 + 多名路人立绘（追逐战掩体 → 人群）
func make_crowd(root: Node, cid: int, cx: float, w: float, h: float) -> void:
	var body := AnimatableBody2D.new()
	body.name = "diyiguan_renqun_%02d" % cid
	body.position = Vector2(cx, 240.0 - h / 2.0)
	root.add_child(body)
	bind_script(body, "res://scripts/npc/crowd_blocker.gd")
	var csh := CollisionShape2D.new()
	var cr := SegmentShape2D.new()
	# 只在迎向玩家的一侧形成竖直阻挡，避免矩形碰撞让主角站到群众头顶。
	cr.a = Vector2(-w / 2.0, -h / 2.0)
	cr.b = Vector2(-w / 2.0, h / 2.0)
	csh.shape = cr
	body.add_child(csh)


## ---- C/D：无缝背景艺术层 + 场景摆件 ----

## 五关旧素材目录仅继续提供与碰撞同速的地面纹理；正式背景已迁往 production。
const TERRAIN_DIRS := {
	"01": "res://assets/raw/素材2/背景/01洪崖洞-现代夜",
	"02": "res://assets/raw/素材2/背景/02磁器口-古代窑场",
	"03": "res://assets/raw/素材2/背景/03中山古镇-古代",
	"04": "res://assets/raw/素材2/背景/04防空洞-近代",
	"05": "res://assets/raw/素材2/背景/05洪崖洞-归来晨光",
}

func add_scene_art(pbg: ParallaxBackground, ground: Node, era: String, world_left: float = -700.0, world_right: float = 2500.0) -> void:
	if not TERRAIN_DIRS.has(era) or pbg == null:
		return
	# 天空、远景和中景由共享 ParallaxStage 在运行时装配；
	# 可行走地形已按真正接触面裁切，顶边与 Ground 碰撞面严格一致。
	var terrain_path := "res://assets/production/terrain/%s/ground.png" % era
	if ResourceLoader.exists(terrain_path) and ground != null:
		var tex: Texture2D = load(terrain_path)
		if tex != null:
			var s := 150.0 / float(tex.get_height())
			var step_x := float(tex.get_width()) * s
			var n := int(ceil((world_right - world_left) / step_x)) + 1
			for i in range(n):
				var sp := Sprite2D.new()
				sp.name = "TerrainTile"
				sp.texture = tex
				sp.centered = false
				sp.scale = Vector2(s, s)
				sp.position = Vector2(world_left - ground.position.x + float(i) * step_x, -20.0)
				sp.z_index = 10
				ground.add_child(sp)

## 地面后的场景摆件（吊脚楼/窑炉/门面/码头），wx=世界x，h=显示高度
func add_object_behind(ground: Node, path: String, wx: float, h: float) -> void:
	if ground == null:
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	var s := h / float(tex.get_height())
	var bottom_padding := 0.0
	var image := tex.get_image()
	if image != null and not image.is_empty():
		for y in range(image.get_height() - 1, -1, -1):
			var has_visible_pixel := false
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.12:
					has_visible_pixel = true
					break
			if has_visible_pixel:
				bottom_padding = float(image.get_height() - 1 - y)
				break
	spr.scale = Vector2(s, s)
	# 透明画布的底部留白不应被算进落地点；可见底边再压入地面 8px。
	spr.position = Vector2(wx - ground.position.x - float(tex.get_width()) * s * 0.5, -12.0 - h + bottom_padding * s)
	ground.add_child(spr)

func add_goal_portal_visual(parent: Node, active: bool = true) -> Node2D:
	var portal := Node2D.new()
	portal.name = "GoalPortalVisual"
	portal.set_script(load("res://scripts/systems/goal_portal_visual.gd"))
	portal.set("active", active)
	parent.add_child(portal)
	return portal

func _pick(files: Array, keyword: String, ext: String) -> String:
	for f in files:
		if f.contains(keyword) and f.ends_with(ext):
			return f
	return ""
