extends Sprite2D

## 第六关第一段的记忆无人机。它保持在主角前方，但会在终点前放慢，
## 让追逐依靠平台移动而不是一次苛刻的碰撞判定。

const CRUISE_SPEED := 116.0
const ESCAPE_DISTANCE := 155.0
const CATCH_DISTANCE := 54.0
const STOP_X := 790.0
const CHASE_SECONDS := 18.0

var player: CharacterBody2D
var active := false
var _time := 0.0
var _base_y := 193.0
var remaining := CHASE_SECONDS

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_normalize_texture()
	_base_y = position.y

func begin(target: CharacterBody2D) -> void:
	player = target
	active = true
	remaining = CHASE_SECONDS

func reset_chase(target: CharacterBody2D) -> void:
	position = Vector2(310, _base_y)
	begin(target)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.6) * 5.0
	rotation = sin(_time * 2.1) * 0.025
	if not active or player == null:
		return
	var arrival := get_node_or_null("/root/ChapterArrival")
	if arrival != null and bool(arrival.call("is_presenting")):
		return # 阅读中央时空字幕时不扣除追逐时间，也不让目标提前飞走。
	remaining -= delta
	if remaining <= 0.0:
		get_parent().call("restart_chase")
		return
	var gap := global_position.x - player.global_position.x
	if global_position.x < STOP_X and gap < ESCAPE_DISTANCE:
		global_position.x = minf(STOP_X, global_position.x + CRUISE_SPEED * delta)
	# 接住灯芯需要真正跳近机体，不能站在地上隔空获得碎片。
	var player_hand := player.global_position + Vector2(0, -36)
	if global_position.x >= STOP_X and absf(gap) <= 32.0 and absf(global_position.y - player_hand.y) <= 26.0:
		active = false
		var level := get_parent()
		if level != null and level.has_method("on_drone_caught"):
			level.call("on_drone_caught", global_position)
		queue_free()

func _normalize_texture() -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var s := minf(92.0 / float(used.size.x), 58.0 / float(used.size.y))
	scale = Vector2.ONE * s

