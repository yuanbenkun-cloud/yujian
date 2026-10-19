extends Node
## 皮肤注入 v3：把 NPC 占位替换为 NPC 帧表待机动画（AnimatedSprite2D，8-? 帧循环）。
## 帧元数据读 assets/npc_anim/meta.json；缺失时回退旧静态立绘。

const META_PATH := "res://assets/npc_anim/meta.json"
const FALLBACK := {
	"NPC_FlyerLady": "res://assets/generated/npc_flyerlady.png",
	"NPC_OldArtisan": "res://assets/generated/npc_oldartisan.png",
	"NPC_AMing": "res://assets/generated/npc_aming.png",
	"NPC_OldShopkeeper": "res://assets/generated/npc_oldshopkeeper.png",
	"NPC_FatTeahouse": "res://assets/generated/npc_teahouse.png",
	"NPC_Helper": "res://assets/generated/npc_helper.png",
	"NPC_LaoZhou": "res://assets/generated/npc_laozhou.png",
	"NPC_OldMan": "res://assets/generated/npc_oldman.png",
}
const NPCS := {
	"chuandanayi": "flyer_lady",
	"laojiangren": "old_artisan",
	"aming": "aming",
	"laozhanggui": "old_shopkeeper",
	"pangzhanggui": "fat_teahouse",
	"banggong": "helper",
	"laozhou": "laozhou",
	"jianglishilaoren": "old_man",
	"youke": "tourist",
	"tanfan": "vendor",
}
const WARTIME_FOLLOWER_TEXTURES := [
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/sheet-transparent.png",
]
const WARTIME_FOLLOWER_IDLE_TEXTURES := [
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
	"res://assets/production/npc/cast_v3/refugee/idle-transparent.png",
]
const CROWD_WALK_FRAME_SIZE := 128
const CROWD_WALK_FRAME_COUNT := 6
const CROWD_WALK_COLUMNS := 3
const NPC_IDLE_FPS := 2.5
const NPC_WALK_FPS := 4.0
const FLYER_WALK_FPS := 12.0
const FLYER_REFERENCE_SPEED := 150.0
const CHARACTER_GROUND_EMBED := 6.0
const HERO_MATCHED_VISIBLE_HEIGHT := 70.0
const NAMED_NPC_VISIBLE_HEIGHT := 70.0

var _meta: Dictionary = {}
var _last_scene: Node = null
var _facing_records: Array[Dictionary] = []
var _bottom_padding_cache: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_meta = parsed

func _process(delta: float) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	if sc != _last_scene:
		_last_scene = sc
		_facing_records.clear()
		_apply(sc)
	_update_facing_and_motion(sc, delta)

func _apply(sc: Node) -> void:
	for npc_name: String in NPCS:
		var n := sc.find_child(npc_name, true, false)
		if n != null:
			var skin_key: String = NPCS[npc_name]
			if npc_name == "chuandanayi" and sc.scene_file_path.ends_with("05_hongyadong_return.tscn"):
				skin_key = "flyer_lady_return"
			_skin(n, skin_key)
	var grp := sc.find_child("NPC_Group", true, false)
	if grp != null:
		var idx := 0
		for c in grp.get_children():
			if str(c.name).begins_with("NPC_Follower"):
				_skin_wartime_follower(
					c as Node2D,
					WARTIME_FOLLOWER_TEXTURES[idx % WARTIME_FOLLOWER_TEXTURES.size()],
					WARTIME_FOLLOWER_IDLE_TEXTURES[idx % WARTIME_FOLLOWER_IDLE_TEXTURES.size()]
				)
				idx += 1

func _skin_wartime_follower(n: Node2D, texture_path: String, idle_texture_path: String) -> void:
	if n == null or not is_instance_valid(n):
		return
	var visual_parent := n.get_node_or_null("VisualPivot") as Node2D
	if visual_parent == null:
		visual_parent = n
	var existing := n.find_child("SkinAnim", true, false)
	if existing != null:
		existing.queue_free()
	_add_ground_shadow(n)
	var texture := load(texture_path) as Texture2D
	var idle_texture := load(idle_texture_path) as Texture2D
	if texture == null or idle_texture == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", NPC_IDLE_FPS)
	frames.set_animation_loop("idle", true)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", NPC_WALK_FPS)
	frames.set_animation_loop("walk", true)
	var idle_frame := AtlasTexture.new()
	idle_frame.atlas = idle_texture
	idle_frame.region = Rect2(0.0, 0.0, CROWD_WALK_FRAME_SIZE, CROWD_WALK_FRAME_SIZE)
	frames.add_frame("idle", idle_frame)
	for i in range(CROWD_WALK_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			float(i % CROWD_WALK_COLUMNS) * CROWD_WALK_FRAME_SIZE,
			float(i / CROWD_WALK_COLUMNS) * CROWD_WALK_FRAME_SIZE,
			CROWD_WALK_FRAME_SIZE,
			CROWD_WALK_FRAME_SIZE
		)
		frames.add_frame("walk", frame)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "SkinAnim"
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 防空洞整体压暗较重；群众采用不受点光重复染黑的材质，仍保留场景的红褐色氛围，
	# 但能清楚看出每个人不同的衣着与轮廓。
	var crowd_shader := Shader.new()
	crowd_shader.code = "shader_type canvas_item; render_mode unshaded, blend_mix; void fragment(){ vec4 c = texture(TEXTURE, UV); vec3 lifted = clamp(c.rgb * 1.45 + vec3(0.055, 0.04, 0.025), vec3(0.0), vec3(1.0)); COLOR = vec4(lifted, c.a); }"
	var crowd_material := ShaderMaterial.new()
	crowd_material.shader = crowd_shader
	sprite.material = crowd_material
	sprite.self_modulate = Color.WHITE
	# 护送群众与主角统一为 70px 可见身高；等待与行走状态都保持同一体量。
	var target_height := HERO_MATCHED_VISIBLE_HEIGHT
	var visible_height := _visible_content_height(idle_texture, CROWD_WALK_FRAME_SIZE, CROWD_WALK_FRAME_SIZE)
	var bottom_padding := _visible_bottom_padding(idle_texture, CROWD_WALK_FRAME_SIZE, CROWD_WALK_FRAME_SIZE)
	var scale_value := target_height / float(maxi(visible_height, 1))
	sprite.scale = Vector2(scale_value, scale_value)
	# 共享脚线压入地面 6px，与主角/NPC 的落脚规则一致。
	sprite.position = Vector2(0.0, -float(CROWD_WALK_FRAME_SIZE) * scale_value * 0.5 + float(bottom_padding) * scale_value + CHARACTER_GROUND_EMBED)
	sprite.set_meta("ground_embed_world", CHARACTER_GROUND_EMBED)
	sprite.set_meta("grounded_visible_bottom_y", n.global_position.y + CHARACTER_GROUND_EMBED)
	sprite.set_meta("visible_height_world", target_height)
	sprite.set_meta("wartime_crowd_texture", texture_path)
	sprite.set_meta("wartime_idle_texture", idle_texture_path)
	visual_parent.add_child(sprite)
	sprite.play("idle")
	# 新战时群众原画朝右；向左时才水平翻转。
	_register_facing(n, sprite, true, true)

func _skin(n: Node2D, key: String) -> void:
	if n == null or not is_instance_valid(n):
		return
	var visual_parent := n.get_node_or_null("VisualPivot") as Node2D
	if visual_parent == null:
		visual_parent = n
	var existing := n.find_child("SkinAnim", true, false) as Node2D
	if existing != null:
		var previous_embed := float(existing.get_meta("ground_embed_world", 0.0))
		if previous_embed < CHARACTER_GROUND_EMBED:
			existing.position.y += CHARACTER_GROUND_EMBED - previous_embed
			existing.set_meta("ground_embed_world", CHARACTER_GROUND_EMBED)
		if key == "flyer_lady":
			_apply_flyer_opaque(existing, n, visual_parent)
		# cast_v3 全部原画朝右；向左时再水平翻转。
		_register_facing(n, existing as Node2D, true, str(n.name) == "chuandanayi")
		return
	_add_ground_shadow(n)
	for c in n.get_children():
		if c is ColorRect and str(c.name) != "Prompt":
			c.visible = false
	var m: Dictionary = _meta.get(key, {})
	if m.is_empty():
		var fb: String = FALLBACK.get(str(n.name), "")
		if fb == "":
			return
		var tex: Texture2D = load(fb)
		if tex == null:
			return
		var spr := Sprite2D.new()
		spr.name = "SkinAnim"
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2(-16, -48)
		visual_parent.add_child(spr)
		_register_facing(n, spr, false, str(n.name) == "chuandanayi")
		return
	var sheet: Texture2D = load(str(m.get("idle_file", m["file"])))
	if sheet == null:
		return
	var fw: int = int(m.get("idle_fw", m["fw"]))
	var fh: int = int(m.get("idle_fh", m["fh"]))
	var count: int = int(m.get("idle_count", m["count"]))
	var idle_cols: int = int(m.get("idle_cols", count))
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", NPC_IDLE_FPS)
	sf.set_animation_loop("idle", true)
	sf.add_animation("walk")
	sf.set_animation_speed("walk", FLYER_WALK_FPS if key.begins_with("flyer_lady") else NPC_WALK_FPS)
	sf.set_animation_loop("walk", true)
	for i in range(mini(count, 3)):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(float(i % idle_cols) * float(fw), float(floori(float(i) / float(idle_cols))) * float(fh), float(fw), float(fh))
		sf.add_frame("idle", at)
	var walk_sheet: Texture2D = load(str(m.get("walk_file", m["file"])))
	var walk_fw := int(m.get("walk_fw", fw))
	var walk_fh := int(m.get("walk_fh", fh))
	var walk_count := int(m.get("walk_count", count))
	var walk_cols := int(m.get("walk_cols", walk_count))
	for i in range(walk_count):
		var walk_at := AtlasTexture.new()
		walk_at.atlas = walk_sheet
		walk_at.region = Rect2(float(i % walk_cols) * float(walk_fw), float(floori(float(i) / float(walk_cols))) * float(walk_fh), float(walk_fw), float(walk_fh))
		sf.add_frame("walk", walk_at)
	var anim := AnimatedSprite2D.new()
	anim.name = "SkinAnim"
	anim.centered = key.begins_with("flyer_lady")
	anim.sprite_frames = sf
	anim.material = null
	anim.self_modulate = Color.WHITE
	if key == "flyer_lady":
		_apply_flyer_opaque(anim, n, visual_parent)
	# 回归关的阿姨应比青年主角略有体量感；她的单帧原画留白也更多，单独放大。
	var target_height := NAMED_NPC_VISIBLE_HEIGHT
	# 新帧表采用固定 256px 单元并留有安全边距；按首帧的真实可见高度缩放，
	# 否则会把透明留白也算进身高，角色会比主角明显偏小。
	var visible_height := _visible_content_height(sheet, fw, fh)
	var s := target_height / float(maxi(visible_height, 1))
	anim.scale = Vector2(s, s)
	var bottom_padding := _visible_bottom_padding(sheet, fw, fh)
	var ground_adjust := float(bottom_padding) * s + CHARACTER_GROUND_EMBED
	# 无论帧表是否居中，均以纹理单元底边和透明底部留白计算真实脚线。
	anim.position = (Vector2(0.0, -float(fh) * s * 0.5) if anim.centered else Vector2(-float(fw) * s * 0.5, -float(fh) * s)) + Vector2(0.0, ground_adjust)
	anim.set_meta("visible_bottom_padding_px", bottom_padding)
	anim.set_meta("visible_content_height_px", visible_height)
	anim.set_meta("ground_embed_world", CHARACTER_GROUND_EMBED)
	anim.set_meta("grounded_visible_bottom_y", n.global_position.y + CHARACTER_GROUND_EMBED)
	anim.set_meta("visible_height_world", target_height)
	visual_parent.add_child(anim)
	anim.play("idle")
	# 所有 NPC 都接入真实位移检测：静止时是中性待机，任何剧情脚本、跟随或巡游
	# 造成的横向位移都会自动切入六帧 walk，停止后再回 idle。
	# cast_v3 的待机和行走帧均以朝右为原始方向。
	_register_facing(n, anim, true, true)

func _apply_flyer_opaque(visual: CanvasItem, actor: Node2D, visual_parent: Node2D) -> void:
	# 提高边缘裁切阈值并增强中间调，避免晨雾关的缩放边缘形成半透明人影。
	var opaque_shader := Shader.new()
	opaque_shader.code = "shader_type canvas_item; render_mode unshaded, blend_mix; void fragment(){ vec4 c = texture(TEXTURE, UV); if(c.a < 0.22){ discard; } vec3 solid_rgb = clamp((c.rgb - vec3(0.5)) * 1.10 + vec3(0.5), vec3(0.0), vec3(1.0)); COLOR = vec4(solid_rgb, 1.0); }"
	var opaque_material := ShaderMaterial.new()
	opaque_material.shader = opaque_shader
	visual.material = opaque_material
	visual.modulate = Color.WHITE
	visual.self_modulate = Color.WHITE
	actor.modulate = Color.WHITE
	actor.self_modulate = Color.WHITE
	visual_parent.modulate = Color.WHITE
	visual_parent.self_modulate = Color.WHITE

func _visible_bottom_padding(sheet: Texture2D, frame_width: int, frame_height: int) -> int:
	var key := "%s:%dx%d" % [sheet.resource_path, frame_width, frame_height]
	if _bottom_padding_cache.has(key):
		return int(_bottom_padding_cache[key])
	var image := sheet.get_image()
	if image == null or image.is_empty():
		return 0
	var scan_width := mini(frame_width, image.get_width())
	var scan_height := mini(frame_height, image.get_height())
	for y in range(scan_height - 1, -1, -1):
		for x in range(scan_width):
			if image.get_pixel(x, y).a >= 0.12:
				var padding := scan_height - 1 - y
				_bottom_padding_cache[key] = padding
				return padding
	_bottom_padding_cache[key] = 0
	return 0

func _visible_content_height(sheet: Texture2D, frame_width: int, frame_height: int) -> int:
	var image := sheet.get_image()
	if image == null or image.is_empty():
		return frame_height
	var scan_width := mini(frame_width, image.get_width())
	var scan_height := mini(frame_height, image.get_height())
	var top := scan_height
	var bottom := -1
	for y in range(scan_height):
		for x in range(scan_width):
			if image.get_pixel(x, y).a >= 0.12:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if bottom < top:
		return frame_height
	return bottom - top + 1

func _register_facing(actor: Node2D, visual: Node2D, source_faces_right: bool = false, motion_enabled: bool = false) -> void:
	for record in _facing_records:
		if record.get("actor") == actor:
			return
	_facing_records.append({
		"actor": actor,
		"visual": visual,
		"last_x": actor.global_position.x,
		"facing": -1,
		"base_position": visual.position,
		"base_scale": visual.scale,
		"phase": randf_range(0.0, TAU),
		"motion_blend": 0.0,
		"moving_grace": 0.0,
		"source_faces_right": source_faces_right,
		"motion_enabled": motion_enabled,
	})
	visual.set("flip_h", source_faces_right)
	actor.set_meta("facing_direction", -1)

func _update_facing_and_motion(scene: Node, delta: float) -> void:
	var player := scene.find_child("zhujue", true, false) as Node2D
	for i in range(_facing_records.size() - 1, -1, -1):
		var record: Dictionary = _facing_records[i]
		var actor := record.get("actor") as Node2D
		var visual := record.get("visual") as Node2D
		if not is_instance_valid(actor) or not is_instance_valid(visual):
			_facing_records.remove_at(i)
			continue
		if str(actor.name) == "chuandanayi":
			actor.modulate = Color.WHITE
			actor.self_modulate = Color.WHITE
			visual.modulate = Color.WHITE
			visual.self_modulate = Color.WHITE
		var current_x := actor.global_position.x
		var movement_x := current_x - float(record.get("last_x", current_x))
		var movement_speed := absf(movement_x) / maxf(delta, 0.0001)
		var motion_enabled := bool(record.get("motion_enabled", false))
		var direction := int(record.get("facing", -1))
		# 追逐/跟随时优先服从实际移动方向；静止时在近距离看向玩家。
		if motion_enabled and movement_speed > 4.0:
			direction = 1 if movement_x > 0.0 else -1
		elif is_instance_valid(player):
			var player_dx := player.global_position.x - current_x
			if absf(player_dx) > 5.0 and absf(player_dx) < 300.0:
				direction = 1 if player_dx > 0.0 else -1
		var source_faces_right := bool(record.get("source_faces_right", false))
		visual.set("flip_h", direction < 0 if source_faces_right else direction > 0)
		actor.set_meta("facing_direction", direction)
		# 物理帧之间可能穿插多个渲染帧；短暂保留移动状态，防止 walk/idle 闪烁。
		var moving_grace := float(record.get("moving_grace", 0.0))
		if motion_enabled and movement_speed > 4.0:
			moving_grace = 0.14
		else:
			moving_grace = maxf(0.0, moving_grace - delta)
		var moving := moving_grace > 0.0
		var target_blend := 1.0 if moving else 0.0
		var blend := move_toward(float(record.get("motion_blend", 0.0)), target_blend, delta * 5.0)
		var phase := float(record.get("phase", 0.0)) + delta * (7.0 if moving else 1.8)
		var stride := absf(sin(phase)) * blend
		var talking := bool(actor.get_meta("talking", false))
		var talk_bob := absf(sin(phase * 0.72)) * 0.75 if talking and not moving else 0.0
		var base_position: Vector2 = record.get("base_position", visual.position)
		var base_scale: Vector2 = record.get("base_scale", visual.scale)
		var is_flyer := str(actor.name) == "chuandanayi"
		# 阿姨帧表自带步态，额外上下位移与拉伸会让鞋底滑动、身体抽动。
		visual.position = base_position if is_flyer else base_position + Vector2(0.0, -stride * 1.15 - talk_bob)
		visual.scale = base_scale if is_flyer else Vector2(base_scale.x * (1.0 + stride * 0.012), base_scale.y * (1.0 - stride * 0.017))
		if visual is AnimatedSprite2D:
			var animated := visual as AnimatedSprite2D
			var wanted_animation := &"walk" if moving else &"idle"
			if animated.animation != wanted_animation:
				animated.play(wanted_animation)
			animated.speed_scale = 1.0
			if is_flyer and moving:
				# 使用物理脚本提供的速度，避免高刷新率下相邻渲染帧的零位移造成变速。
				var gait_speed := float(actor.get_meta("locomotion_speed", FLYER_REFERENCE_SPEED))
				animated.speed_scale = clampf(gait_speed / FLYER_REFERENCE_SPEED, 0.4, 1.4)
		record["last_x"] = current_x
		record["facing"] = direction
		record["phase"] = phase
		record["motion_blend"] = blend
		record["moving_grace"] = moving_grace
		_facing_records[i] = record

func _add_ground_shadow(actor: Node2D) -> void:
	if actor.has_node("GroundShadow"):
		return
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-11, 0), Vector2(-8, -2), Vector2(-4, -3), Vector2(4, -3),
		Vector2(8, -2), Vector2(11, 0), Vector2(8, 2), Vector2(4, 3),
		Vector2(-4, 3), Vector2(-8, 2),
	])
	shadow.color = Color(0.015, 0.02, 0.03, 0.24)
	shadow.z_index = 19
	actor.add_child(shadow)
