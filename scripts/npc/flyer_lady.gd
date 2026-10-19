extends "res://scripts/npc/interactable.gd"
## 传单阿姨本人就是主追兵：等待/追逐/命中后喘息三态。

enum State { WAIT, CHASE, RECOVER }

const BASE_SPEED := 150.0
const FAR_SPEED := 190.0
const CROWD_SPEED_MULTIPLIER := 0.48
const HIT_DISTANCE := 24.0

var _started: bool = false
var _state: int = State.WAIT
var _player: Node2D = null
var _recover_left := 0.0
var _base_y := 0.0

func _ready() -> void:
	super._ready()
	_base_y = global_position.y

func activate(player: Node) -> void:
	_player = player as Node2D
	_state = State.CHASE
	_started = true
	set_prompt_visible(false)

func _physics_process(delta: float) -> void:
	set_meta("locomotion_speed", 0.0)
	# 阅读木牌或与 NPC 交谈时暂停追兵；否则玩家被冻结后仍会在后台受击并带着活跃对话重载。
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds != null and bool(ds.get("active")):
		return
	if _state == State.RECOVER:
		_recover_left -= delta
		if _recover_left <= 0.0:
			_state = State.CHASE
		return
	if _state != State.CHASE or not is_instance_valid(_player):
		return
	var gap := _player.global_position.x - global_position.x
	var speed := _get_chase_speed(gap)
	set_meta("locomotion_speed", speed)
	global_position.x += signf(gap) * speed * delta
	# 行走重心交给贴图帧，保持角色根节点与路面脚线稳定。
	global_position.y = _base_y
	if absf(gap) <= HIT_DISTANCE and absf(_player.global_position.y - global_position.y) < 54.0:
		_hit_player()

func _get_chase_speed(gap: float) -> float:
	var speed := FAR_SPEED if gap > 190.0 else BASE_SPEED
	var slowed := _is_inside_crowd()
	set_meta("crowd_slowed", slowed)
	return speed * CROWD_SPEED_MULTIPLIER if slowed else speed

func _is_inside_crowd() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	for crowd in scene.find_children("diyiguan_renqun_*", "AnimatableBody2D", true, false):
		if crowd.has_method("slows_chaser_at") and bool(crowd.call("slows_chaser_at", global_position)):
			return true
	return false

func _hit_player() -> void:
	_state = State.RECOVER
	_recover_left = 1.05
	global_position.x -= 26.0
	var cur := get_tree().current_scene
	if cur != null:
		var hearts := cur.find_child("HeartSystem", true, false)
		if hearts != null:
			hearts.call("take_damage")
		var camera := cur.find_child("Camera2D", true, false)
		if camera != null and camera.has_method("shake"):
			camera.call("shake", 5.0, 0.22)
	if _player.has_method("knock"):
		_player.call("knock", 185.0)

func on_interact(_interactor: Node) -> void:
	if _started:
		return
	_started = true
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds == null:
		return
	if not bool(ds.call("load_data", "res://assets/dialogue_level1.json")):
		_started = false
		return
	if not ds.is_connected("ended", _on_ended):
		ds.connect("ended", _on_ended)
	set_meta("talking", true)
	ds.call("start_dialogue", "flyer_lady")

func _on_ended() -> void:
	set_meta("talking", false)
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds != null and ds.is_connected("ended", _on_ended):
		ds.disconnect("ended", _on_ended)
	var cur := get_tree().current_scene
	if cur != null:
		var cm := cur.find_child("ChaseManager", true, false)
		if cm != null:
			cm.call("begin")
