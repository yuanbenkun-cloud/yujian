class_name AmbientLife
extends Node2D

## 轻量动态背景：远处飞鸟与不参与碰撞的行人，强化横向关卡的生命感。

const MODERN_PEOPLE := [
	"res://assets/production/npc/crowd_walk/modern/modern-01.png",
	"res://assets/production/npc/crowd_walk/modern/modern-02.png",
	"res://assets/production/npc/crowd_walk/modern/modern-03.png",
	"res://assets/production/npc/crowd_walk/modern/modern-04.png",
	"res://assets/production/npc/crowd_walk/modern/modern-05.png",
	"res://assets/production/npc/crowd_walk/modern/modern-06.png",
]
const WARTIME_PEOPLE := [
	"res://assets/production/npc/crowd_wartime/crowd-wartime-01.png",
	"res://assets/production/npc/crowd_wartime/crowd-wartime-02.png",
	"res://assets/production/npc/crowd_wartime/crowd-wartime-03.png",
	"res://assets/production/npc/crowd_wartime/crowd-wartime-04.png",
	"res://assets/production/npc/crowd_wartime/crowd-wartime-05.png",
	"res://assets/production/npc/crowd_wartime/crowd-wartime-06.png",
]
const WORKSHOP_PEOPLE := [
	"res://assets/production/npc/cast_v3/aming/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/helper/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/old_artisan/sheet-transparent.png",
]
const WATERSIDE_PEOPLE := [
	"res://assets/production/npc/cast_v3/helper/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/laozhou/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/old_shopkeeper/sheet-transparent.png",
	"res://assets/production/npc/cast_v3/fat_teahouse/sheet-transparent.png",
]

@export var era := "01"
@export var world_left := -700.0
@export var world_right := 2500.0

var _birds: Array[Node2D] = []
var _walkers: Array[AnimatedSprite2D] = []
var _drifters: Array[Node2D] = []
var _elapsed := 0.0

# 这里记录的是每个场景真正的“视觉落脚线”，不是 Ground 色块或地形贴图的外框。
# 道路/台阶素材会向上、向下延伸，所以仍需配合透明像素底边检测后再压入表面。
const WALKER_FOOT_Y := {
	"01": 246.0,
	"02": 246.0,
	"03": 246.0,
	"05": 246.0,
}
const SHELTER_RAT_FOOT_Y := 253.0
const WALK_FRAME_SIZE := 128
const WALK_FRAME_COUNT := 6
const WALK_COLUMNS := 3
const WALKER_VISIBLE_HEIGHT := 70.0
const FIRST_LEVEL_WALKER_VISIBLE_HEIGHT := 70.0

func configure(era_id: String, left_edge: float, right_edge: float) -> void:
	era = era_id
	world_left = left_edge
	world_right = right_edge

func _ready() -> void:
	z_index = 0
	# 第一关收敛动态元素：少量鸟群 + 孔明灯，不再与天气粒子叠满屏幕。
	_build_birds(10 if era == "01" else (12 if era in ["03", "05"] else 6))
	if era in ["01", "05"]:
		_build_walkers(12)
	elif era in ["02", "03"]:
		# 作坊与水乡也需要有人真正走动；这些角色只在背景层巡游，
		# 不抢占剧情 NPC 的交互位置。
		_build_walkers(8)
	if era == "01":
		_build_sky_lanterns(12)
	if era == "02":
		_build_kiln_smoke(16)
	elif era == "04":
		_build_shelter_rats(10)

func _process(delta: float) -> void:
	_elapsed += delta
	for i in range(_birds.size()):
		var bird := _birds[i]
		var speed := float(bird.get_meta("speed"))
		bird.position.x += speed * delta
		bird.position.y = float(bird.get_meta("base_y")) + sin(_elapsed * 1.35 + float(bird.get_meta("phase"))) * 4.0
		var wing := 2.0 + absf(sin(_elapsed * 4.2 + float(i))) * 3.0
		var left_wing := bird.get_node("LeftWing") as Line2D
		var right_wing := bird.get_node("RightWing") as Line2D
		left_wing.points = PackedVector2Array([Vector2(-8, wing), Vector2(0, 0)])
		right_wing.points = PackedVector2Array([Vector2(0, 0), Vector2(8, wing)])
		if bird.position.x > world_right + 180.0:
			bird.position.x = world_left - 180.0 - float(i) * 47.0
	for i in range(_walkers.size()):
		var walker := _walkers[i]
		walker.position.x += float(walker.get_meta("speed")) * delta
		# 连续步态替代旧版每 0.28 秒瞬移一像素的“抽动”。轻微抬脚、摆身与呼吸缩放
		# 全部使用正弦插值，所以低速横移时也不会突然跳帧。
		var gait_phase := _elapsed * 6.2 + float(walker.get_meta("phase")) * TAU
		var stride := sin(gait_phase)
		var lift := absf(sin(gait_phase * 0.5))
		var base_scale := float(walker.get_meta("base_scale"))
		walker.position.y = float(walker.get_meta("base_y")) - lift * 1.35
		walker.rotation_degrees = stride * 0.85
		walker.scale = Vector2(base_scale * (1.0 + absf(stride) * 0.012), base_scale * (1.0 - absf(stride) * 0.008))
		if walker.position.x > world_right + 90.0:
			walker.position.x = world_left - 100.0 - float(i) * 83.0
	for i in range(_drifters.size()):
		var drifter := _drifters[i]
		var velocity: Vector2 = drifter.get_meta("velocity")
		drifter.position += velocity * delta
		var kind := str(drifter.get_meta("kind"))
		if kind == "smoke":
			drifter.modulate.a = 0.38 + 0.18 * absf(sin(_elapsed * 0.8 + float(i)))
			if drifter.position.y < 48.0:
				drifter.position.y = 194.0
		elif kind == "lantern":
			drifter.position.x += sin(_elapsed * 0.55 + float(drifter.get_meta("phase"))) * 3.0 * delta
			drifter.modulate.a = 0.62 + 0.20 * absf(sin(_elapsed * 0.9 + float(i)))
			if drifter.position.y < -55.0:
				drifter.position.y = 330.0 + float(i % 4) * 24.0
		elif kind == "rat":
			drifter.position.y = float(drifter.get_meta("base_y")) - absf(sin(_elapsed * 8.0 + float(i))) * 1.2
			if drifter.position.x > world_right + 100.0:
				drifter.position.x = world_left - 120.0 - float(i) * 155.0

func _build_birds(count: int) -> void:
	for i in range(count):
		var bird := Node2D.new()
		bird.name = "Bird%02d" % (i + 1)
		bird.z_as_relative = false
		bird.z_index = -1
		var bird_material := CanvasItemMaterial.new()
		bird_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		bird.material = bird_material
		var flock := i / 4
		var member := i % 4
		bird.position = Vector2(world_left + 150.0 + float(flock) * 650.0 + float(member) * 34.0, 42.0 + float(flock % 3) * 25.0 + float(member) * 9.0)
		bird.scale = Vector2.ONE * (0.78 + float((i + flock) % 3) * 0.13)
		bird.modulate = Color(0.72, 0.78, 0.86, 0.82) if era != "04" else Color(0.50, 0.44, 0.40, 0.62)
		bird.set_meta("speed", 15.0 + float(flock % 3) * 2.5 + float(member) * 0.6)
		bird.set_meta("base_y", bird.position.y)
		bird.set_meta("phase", float(i) * 0.83)
		for wing_data in [["LeftWing", PackedVector2Array([Vector2(-8, 3), Vector2(0, 0)])], ["RightWing", PackedVector2Array([Vector2(0, 0), Vector2(8, 3)])]]:
			var line := Line2D.new()
			line.name = str(wing_data[0])
			line.points = wing_data[1]
			line.width = 2.0
			line.default_color = Color.WHITE
			line.use_parent_material = true
			bird.add_child(line)
		add_child(bird)
		_birds.append(bird)

func _build_walkers(count: int) -> void:
	var pool: Array = MODERN_PEOPLE
	if era == "04":
		pool = WARTIME_PEOPLE
	elif era == "02":
		pool = WORKSHOP_PEOPLE
	elif era == "03":
		pool = WATERSIDE_PEOPLE
	var spacing := (world_right - world_left - 300.0) / float(maxi(count, 1))
	for i in range(count):
		var texture: Texture2D = load(pool[i % pool.size()])
		if texture == null:
			continue
		var walker := AnimatedSprite2D.new()
		walker.name = "DistantWalker%02d" % (i + 1)
		walker.sprite_frames = _make_walk_frames(texture)
		walker.z_as_relative = false
		walker.z_index = 13
		var walker_material := CanvasItemMaterial.new()
		walker_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		walker.material = walker_material
		walker.position = Vector2(world_left + 150.0 + float(i) * spacing, 210.0)
		# 背景人影与主角使用同一 70px 可见身高；只靠颜色层级退入背景，
		# 不再用额外放大制造“近处巨人”。
		var visible_height := _visible_height(texture)
		var bottom_padding := _bottom_padding(texture)
		var target_visible_height := FIRST_LEVEL_WALKER_VISIBLE_HEIGHT if era == "01" else WALKER_VISIBLE_HEIGHT
		var display_scale := target_visible_height / float(maxi(visible_height, 1))
		walker.scale = Vector2.ONE * display_scale
		walker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 保持不透明来避免发虚，只降低 RGB 亮度，使其退入背景层级。
		walker.modulate = Color(0.70, 0.73, 0.76, 0.98)
		walker.set_meta("speed", 17.0 + float(i % 3) * 4.0)
		walker.set_meta("phase", float(i) * 0.19)
		walker.set_meta("base_scale", display_scale)
		add_child(walker)
		walker.play("walk")
		# 按第一帧真正脚底对齐道路表面，忽略 128px 动画格的透明留白。
		var foot_y := float(WALKER_FOOT_Y.get(era, 251.0))
		walker.position.y = foot_y - (float(WALK_FRAME_SIZE) * 0.5 - float(bottom_padding)) * display_scale
		walker.set_meta("grounded_visible_bottom_y", foot_y)
		walker.set_meta("visible_height_world", target_visible_height)
		walker.set_meta("base_y", walker.position.y)
		_walkers.append(walker)

func _make_walk_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 4.0)
	frames.set_animation_loop("walk", true)
	for i in range(WALK_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(float(i % WALK_COLUMNS) * WALK_FRAME_SIZE, float(i / WALK_COLUMNS) * WALK_FRAME_SIZE, WALK_FRAME_SIZE, WALK_FRAME_SIZE)
		frames.add_frame("walk", frame)
	return frames

func _visible_height(texture: Texture2D) -> int:
	var image := texture.get_image()
	var top := WALK_FRAME_SIZE
	var bottom := -1
	for y in range(WALK_FRAME_SIZE):
		for x in range(WALK_FRAME_SIZE):
			if image.get_pixel(x, y).a >= 0.12:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return WALK_FRAME_SIZE if bottom < top else bottom - top + 1

func _bottom_padding(texture: Texture2D) -> int:
	var image := texture.get_image()
	for y in range(WALK_FRAME_SIZE - 1, -1, -1):
		for x in range(WALK_FRAME_SIZE):
			if image.get_pixel(x, y).a >= 0.12:
				return WALK_FRAME_SIZE - 1 - y
	return 0

func _build_kiln_smoke(count: int) -> void:
	for i in range(count):
		var puff := Polygon2D.new()
		puff.name = "KilnSmoke%02d" % (i + 1)
		puff.z_as_relative = false
		puff.z_index = 2
		puff.position = Vector2(world_left + 240.0 + float(i) * 420.0, 194.0 - float(i % 3) * 26.0)
		puff.polygon = PackedVector2Array([Vector2(-13, 3), Vector2(-11, -8), Vector2(-3, -15), Vector2(8, -12), Vector2(15, -3), Vector2(11, 8), Vector2(-3, 11)])
		puff.color = Color(0.50, 0.43, 0.40, 0.54)
		puff.scale = Vector2.ONE * (1.05 + float(i % 4) * 0.22)
		puff.set_meta("kind", "smoke")
		puff.set_meta("velocity", Vector2(3.0 + float(i % 2) * 2.0, -7.0 - float(i % 3)))
		add_child(puff)
		_drifters.append(puff)

func _build_sky_lanterns(count: int) -> void:
	var texture: Texture2D = load("res://assets/production/ambient/sky-lantern-v1.png")
	if texture == null:
		return
	for i in range(count):
		var lantern := Sprite2D.new()
		lantern.name = "SkyLantern%02d" % (i + 1)
		lantern.texture = texture
		lantern.z_as_relative = false
		lantern.z_index = 2
		var spacing := (world_right - world_left - 300.0) / float(maxi(count - 1, 1))
		lantern.position = Vector2(world_left + 150.0 + float(i) * spacing, 24.0 + float(i % 7) * 46.0)
		lantern.scale = Vector2.ONE * (0.64 + float(i % 3) * 0.10)
		lantern.modulate = Color(1.0, 0.88, 0.72, 0.76)
		lantern.set_meta("kind", "lantern")
		lantern.set_meta("velocity", Vector2(1.4 + float(i % 2), -9.0 - float(i % 4) * 1.4))
		lantern.set_meta("phase", float(i) * 0.71)
		add_child(lantern)
		_drifters.append(lantern)

func _build_shelter_rats(count: int) -> void:
	var texture: Texture2D = load("res://assets/production/ambient/shelter-rat-v1.png")
	if texture == null:
		return
	for i in range(count):
		var rat := Sprite2D.new()
		rat.name = "ShelterRat%02d" % (i + 1)
		rat.texture = texture
		rat.z_as_relative = false
		rat.z_index = 30
		var spacing := (world_right - world_left - 420.0) / float(maxi(count - 1, 1))
		rat.position = Vector2(world_left + 210.0 + float(i) * spacing, 222.0)
		rat.scale = Vector2.ONE * (0.50 + float(i % 2) * 0.06)
		rat.modulate = Color(0.88, 0.76, 0.62, 0.94)
		var material := CanvasItemMaterial.new()
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		rat.material = material
		rat.set_meta("kind", "rat")
		rat.set_meta("velocity", Vector2(20.0 + float(i % 3) * 5.0, 0.0))
		add_child(rat)
		# 防空洞碎石地面比通用道路的视觉表面更低，单独使用洞底落脚线。
		InteractivePropGrounding.ground_sprite(rat, SHELTER_RAT_FOOT_Y, 0.12)
		rat.set_meta("base_y", rat.position.y)
		_drifters.append(rat)
