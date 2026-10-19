extends SceneTree

var _ok := true

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	_ok = _ok and value

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor_body.position = Vector2(1200, 260)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var player := load("res://scenes/renwu/zhujue/zhujue.tscn").instantiate() as CharacterBody2D
	player.position = Vector2(240, 240)
	world.add_child(player)
	for i in range(10):
		await physics_frame
	var hero := player.get_node("VisualPivot/zhujue_donghua") as AnimatedSprite2D
	_check(hero.sprite_frames.get_frame_count("walk") == 8, "小跑使用八帧紧凑双步周期")
	_check(hero.sprite_frames.get_frame_count("idle") == 6 and hero.sprite_frames.get_frame_count("interact") == 6, "待机和交互均为6张新帧")
	for action in ["idle", "interact"]:
		var bottoms := []
		for index in range(hero.sprite_frames.get_frame_count(action)):
			var image := hero.sprite_frames.get_frame_texture(action, index).get_image()
			var used := image.get_used_rect()
			bottoms.append(used.end.y)
		_check(bottoms.max() == 125 and bottoms.min() == 125, action + "所有鞋底对齐125，无逐帧缩放")
	Input.action_press("move_right")
	var seen := {}
	var contacts: Array[int] = []
	hero.foot_contact.connect(func(index: int) -> void: contacts.append(index))
	for i in range(70):
		await physics_frame
		if hero.animation == &"walk":
			seen[hero.frame] = true
	_check(seen.size() == 8, "实际右移完整播放八帧，未每帧重置")
	_check(not hero.flip_h and absf(hero.speed_scale - 1.0) < 0.01 and hero.sprite_frames.get_animation_speed("walk") == 12.0, "保持130移速，对应12fps轻快小跑")
	_check(contacts.size() >= 3 and contacts.all(func(index: int) -> bool: return index in [0, 4]), "脚步事件只在两次落脚帧触发")
	var alternating := true
	for i in range(1, contacts.size()):
		alternating = alternating and contacts[i] != contacts[i - 1]
	_check(alternating, "左右脚落脚事件交替，未重复播放")
	for index in range(8):
		var used := hero.sprite_frames.get_frame_texture("walk", index).get_image().get_used_rect()
		_check(used.end.y == (124 if index in [3, 7] else 125), "小跑第%d帧脚线稳定，无5到10像素悬空" % index)
	Input.action_release("move_right")
	Input.action_press("move_left")
	for i in range(10):
		await physics_frame
	_check(hero.flip_h, "左朝向正确镜像整套动画")
	Input.action_release("move_left")
	for i in range(8):
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	var airborne := {}
	var landed := false
	for i in range(90):
		await physics_frame
		if hero.animation == &"jump":
			airborne[hero.frame] = true
		landed = landed or hero.animation == &"land"
	_check(hero.sprite_frames.get_frame_count("jump") == 4 and airborne.has(0) and airborne.has(3), "跳跃回退为原四帧顺序播放")
	_check(not landed and not hero.sprite_frames.has_animation("land"), "不再使用新跳跃的蜷身落地帧")
	var original_jump := load("res://assets/production/hero/jump/jump-1.png") as Texture2D
	_check(hero.sprite_frames.get_frame_texture("jump", 0) == original_jump, "跳跃实际使用原版素材，不是只改帧数")
	hero.call("trigger_interact")
	_check(hero.animation == &"interact", "交互播放新动作")
	Input.action_press("move_right")
	for i in range(3):
		await physics_frame
	_check(hero.animation == &"walk", "移动可立即打断交互，不出现滑行动作")
	Input.action_release("move_right")
	player.set("frozen", true)
	for i in range(3):
		await physics_frame
	_check(hero.animation == &"idle", "冻结和对话状态保持待机")
	print("[RESULT] ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
