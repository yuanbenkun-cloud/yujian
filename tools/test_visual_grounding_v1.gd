extends SceneTree
## 角色描边、接触阴影、NPC 脚底与地面资源回归。

const CASES := {
	"res://scenes/guanqia/01_hongyadong.tscn": ["chuandanayi"],
	"res://scenes/guanqia/02_ciqikou.tscn": ["laojiangren", "aming"],
	"res://scenes/guanqia/03_zhongshan.tscn": ["laozhanggui", "pangzhanggui", "banggong", "laozhou"],
	"res://scenes/guanqia/04_fangdong.tscn": ["NPC_Follower1", "NPC_Follower6"],
	"res://scenes/guanqia/05_hongyadong_return.tscn": ["jianglishilaoren", "chuandanayi"],
}

var _ok := true

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + message)
	_ok = _ok and condition

func _texture_source_path(texture: Texture2D) -> String:
	var source := texture
	while source is AtlasTexture:
		source = (source as AtlasTexture).atlas
	return source.resource_path if source != null else ""

func _run() -> void:
	for scene_path: String in CASES:
		change_scene_to_file(scene_path)
		await create_timer(0.18).timeout
		var terrain := current_scene.find_child("TerrainTile", true, false) as Sprite2D
		_check(terrain != null and "/assets/production/terrain/" in terrain.texture.resource_path, "%s 使用校准地面" % scene_path.get_file())
		var hero := current_scene.find_child("zhujue_donghua", true, false) as AnimatedSprite2D
		_check(hero != null and hero.material == null, "%s 主角无强制黑描边" % scene_path.get_file())
		_check(current_scene.find_child("GroundShadow", true, false) is Polygon2D, "%s 有柔和接触阴影" % scene_path.get_file())
		var interaction_hint := current_scene.find_child("InteractionHint", true, false) as Control
		_check(interaction_hint != null and interaction_hint.position.y >= 300.0, "%s 互动提示位于屏幕下方" % scene_path.get_file())
		var mid_layer := current_scene.find_child("BG_Mid", true, false)
		var mid_plate := mid_layer.get_node_or_null("Plate_00") as Sprite2D if mid_layer != null else null
		_check(mid_plate != null and absf(float(mid_plate.get_meta("visible_ground_y", -999.0)) - 247.0) < 0.1, "%s 中景建筑按可见底边贴地" % scene_path.get_file())
		for npc_name: String in CASES[scene_path]:
			var npc := current_scene.find_child(npc_name, true, false) as Node2D
			_check(npc != null and absf(npc.global_position.y - 240.0) < 1.0, "%s 脚底落在地面线" % npc_name)
			var npc_visual := npc.find_child("SkinAnim", true, false) if npc != null else null
			_check(npc_visual != null and float(npc_visual.get_meta("ground_embed_world", 0.0)) >= 6.0, "%s 可见鞋底已深压入地面" % npc_name)
		if scene_path.ends_with("01_hongyadong.tscn"):
			var building := current_scene.find_child("@Sprite2D@54", true, false) as Sprite2D
			_check(building != null and bool(building.get_meta("grounded_to_opaque_pixels", false)), "第一关独立建筑按不透明底边接地")
			var board := current_scene.find_child("InfoBoardVisual", true, false) as Sprite2D
			var stone := current_scene.find_child("StoneButtonVisual", true, false) as Sprite2D
			var stone_bottom := stone.global_position.y + float(stone.texture.get_height()) * stone.global_scale.y * 0.5 if stone != null else -999.0
			_check(board != null and absf(float(board.get_meta("grounded_visible_bottom_y", -999.0)) - 247.0) < 0.1, "第一关门牌压入地面")
			_check(stone != null and stone_bottom >= 246.0, "第一关石扣压入地面且清晰可见")
		if scene_path.ends_with("02_ciqikou.tscn"):
			var pot_visual := current_scene.find_child("@Sprite2D@58", true, false) as Sprite2D
			var wood_visual := current_scene.find_child("@Sprite2D@60", true, false) as Sprite2D
			var kiln := current_scene.find_child("@Sprite2D@90", true, false) as Sprite2D
			var wall := current_scene.find_child("di_erguan_yanbi", true, false) as Node2D
			var wall_prompt := wall.find_child("Prompt", false, false) as CanvasItem if wall != null else null
			_check(wall != null and absf(wall.global_position.y - 250.0) < 1.0, "第二关石壁压入地面 10 像素")
			_check(wall_prompt != null and not wall_prompt.visible, "石壁不再显示悬空方块提示")
			_check(pot_visual != null and absf(float(pot_visual.get_meta("grounded_visible_bottom_y", -999.0)) - 247.0) < 0.1, "第二关壶按可见底边贴地")
			_check(wood_visual != null and absf(float(wood_visual.get_meta("grounded_visible_bottom_y", -999.0)) - 247.0) < 0.1, "第二关木头按可见底边贴地")
			_check(kiln != null and kiln.texture.resource_path.ends_with("kiln-right-v2.png"), "第二关使用右向侧视新窑炉")
			_check(kiln != null and kiln.position.y >= -174.0, "第二关窑炉进一步压入地面")
			wall.call("crack")
			wall.call("celebrate_breakthrough")
			await process_frame
			var crack := wall.find_child("Crack1", false, false) as Line2D
			_check(crack != null and not crack.visible, "石壁消失后不残留发光裂纹")
		if scene_path.ends_with("03_zhongshan.tscn"):
			var cargo := current_scene.find_child("CargoVisual", true, false) as Sprite2D
			_check(cargo != null and absf(float(cargo.get_meta("grounded_visible_bottom_y", -999.0)) - 247.0) < 0.1, "第三关货包压入地面")
		if scene_path.ends_with("05_hongyadong_return.tscn"):
			var aunt := current_scene.find_child("chuandanayi", true, false) as Node2D
			var aunt_visual := aunt.find_child("SkinAnim", true, false) as AnimatedSprite2D if aunt != null else null
			var aunt_frame := aunt_visual.sprite_frames.get_frame_texture(&"idle", 0) if aunt_visual != null else null
			_check(aunt_visual != null and aunt_frame != null and _texture_source_path(aunt_frame).ends_with("npc/redesign/flyer_lady/sheet-transparent.png") and aunt_visual.material == null, "第五关阿姨使用统一新版透明帧表")
			for prop_name in ["InfoBoardVisual", "ScenicViewerVisual", "PhotoCameraVisual"]:
				var prop := current_scene.find_child(prop_name, true, false) as Sprite2D
				_check(prop != null and absf(float(prop.get_meta("grounded_visible_bottom_y", -999.0)) - 247.0) < 0.1, "%s 压入地面" % prop_name)
	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
