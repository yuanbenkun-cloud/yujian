class_name GroupFollower
extends Node

## 第四关护送队伍：沿途分批救下难民，获救者按主角的历史路径排成长队。

const MIN_FOLLOW_SPEED := 155.0
const TRAIL_SPACING := 26.0

var followers: Array[Node2D] = []
var active_followers: Array[Node2D] = []
var history: Array[Vector2] = []
var sample_interval: float = 0.2
var max_history: int = 40
var _acc: float = 0.0
var _leader: Node2D = null
var _step: int = 1          # 紧凑队形才能整体进入挡板覆盖范围
var _enabled: bool = false
var _waiting_by_stage: Dictionary = {}
var _rescue_x_by_stage: Dictionary = {}
var _status: Label = null

func _ready() -> void:
	# 场景切换期间 current_scene 可能仍是上一关；只从所属关卡根节点绑定。
	var level_root := get_parent()
	_leader = level_root.get_node_or_null("zhujue") as Node2D
	var container := level_root.get_node_or_null("NPC_Group")
	_status = level_root.find_child("UI_EscortStatus", true, false) as Label
	if container != null:
		for c in container.get_children():
			if c is Node2D and str(c.name).begins_with("NPC_Follower"):
				add_follower(c as Node2D)
	_update_status("寻找洞中的避难者")

func add_follower(npc: Node2D) -> void:
	followers.append(npc)
	var stage := int(npc.get_meta("rescue_stage", 0))
	if stage <= 0 or bool(npc.get_meta("rescued", false)):
		active_followers.append(npc)
		return
	if not _waiting_by_stage.has(stage):
		_waiting_by_stage[stage] = []
	(_waiting_by_stage[stage] as Array).append(npc)
	_rescue_x_by_stage[stage] = float(npc.get_meta("recruit_at_x", npc.global_position.x))

func start_following() -> void:
	if _leader == null:
		return
	if history.is_empty():
		_seed_history(_leader.global_position)
	_enabled = true

func restore_at(pos: Vector2) -> void:
	_seed_history(pos)
	for i in active_followers.size():
		active_followers[i].global_position.x = pos.x - TRAIL_SPACING * float(i + 1)
	_enabled = not active_followers.is_empty()

func _seed_history(pos: Vector2) -> void:
	history.clear()
	_acc = 0.0
	for i in range(max_history):
		history.append(pos - Vector2(TRAIL_SPACING * float(max_history - 1 - i), 0.0))

func _physics_process(delta: float) -> void:
	_check_rescue_points()
	if not _enabled and _can_start_following():
		start_following()
	if not _enabled or _leader == null:
		return
	_acc += delta
	if _acc >= sample_interval:
		_acc -= sample_interval
		history.append(_leader.global_position)
		if history.size() > max_history:
			history.remove_at(0)
	if history.is_empty():
		return
	for i in active_followers.size():
		var npc: Node2D = active_followers[i]
		if npc == null or not is_instance_valid(npc):
			continue
		var idx: int = maxi(0, history.size() - 1 - (i + 1) * _step)
		var next_idx: int = mini(idx + 1, history.size() - 1)
		var tgt: Vector2 = history[idx].lerp(history[next_idx], clampf(_acc / sample_interval, 0.0, 1.0))
		# 主角跳跃时群众仍沿地面走，不追随主角的垂直坐标。
		tgt.y = npc.global_position.y
		var gap := absf(tgt.x - npc.global_position.x)
		var speed := MIN_FOLLOW_SPEED + minf(maxf(gap - TRAIL_SPACING, 0.0) * 0.45, 85.0)
		npc.global_position = npc.global_position.move_toward(tgt, speed * delta)

func _can_start_following() -> bool:
	if _leader == null or not is_instance_valid(_leader) or active_followers.is_empty():
		return false
	if get_tree().current_scene != get_parent():
		return false
	var director := get_node_or_null("/root/StoryDirector")
	if director != null and bool(director.get("busy")):
		return false
	return not bool(_leader.get("frozen"))

func _check_rescue_points() -> void:
	if _leader == null or not is_instance_valid(_leader):
		return
	if get_tree().current_scene != get_parent() or bool(_leader.get("frozen")):
		return
	var stages: Array = _waiting_by_stage.keys()
	stages.sort()
	for stage_value in stages:
		var stage := int(stage_value)
		var rescue_x := float(_rescue_x_by_stage.get(stage, INF))
		if _leader.global_position.x >= rescue_x - 72.0:
			_recruit_stage(stage)

func _recruit_stage(stage: int) -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	if not _waiting_by_stage.has(stage):
		return
	var rescued_now := _waiting_by_stage[stage] as Array
	_waiting_by_stage.erase(stage)
	_rescue_x_by_stage.erase(stage)
	if history.is_empty():
		_seed_history(_leader.global_position)
	for npc_value in rescued_now:
		var npc := npc_value as Node2D
		if npc == null or not is_instance_valid(npc):
			continue
		npc.set_meta("rescued", true)
		active_followers.append(npc)
		var pivot := npc.get_node_or_null("VisualPivot") as Node2D
		if pivot != null:
			pivot.scale = Vector2(0.78, 1.18)
			create_tween().tween_property(pivot, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var marker := get_parent().find_child("RescueMarker%d" % stage, true, false) as CanvasItem
	if marker != null:
		var marker_tween := create_tween().set_parallel(true)
		marker_tween.tween_property(marker, "modulate:a", 0.0, 0.22)
		marker_tween.tween_property(marker, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		marker_tween.finished.connect(marker.queue_free)
	_enabled = true
	_update_status("救下 %d 人，队伍正在变长" % rescued_now.size())
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_event", "ui_confirm", 1.02, -1.5)

func rescued_count() -> int:
	return active_followers.size()

func all_rescued() -> bool:
	return active_followers.size() >= followers.size() and not followers.is_empty()

func _update_status(message: String = "") -> void:
	if _status == null:
		return
	var prefix := "护送 %d/%d" % [active_followers.size(), followers.size()]
	_status.text = prefix if message == "" else "%s　%s" % [prefix, message]
	_status.visible = true
	_status.modulate.a = 1.0
	if message != "":
		var tween := create_tween()
		tween.tween_interval(1.4)
		tween.tween_property(_status, "modulate:a", 0.76, 0.35)
