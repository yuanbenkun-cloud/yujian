class_name LooseTile
extends Area2D

## 古墙石扣（第一关）：踩下后结束追逐并唤醒前方传送门。

@export var portal_path: NodePath

var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is CharacterBody2D and body.has_method("set_look_dir"):
		_triggered = true
		var guide: Node = get_node_or_null("/root/QuestGuide")
		if guide != null: guide.call("request_refresh")
		set_deferred("monitoring", false)
		var scene := get_tree().current_scene
		var cm := scene.find_child("ChaseManager", true, false) if scene != null else null
		if cm != null and cm.has_method("finish"):
			cm.call("finish")
		var portal := get_node_or_null(portal_path)
		if portal != null and portal.has_method("activate"):
			portal.call("activate")
		var visual := get_node_or_null("StoneButtonVisual") as CanvasItem
		if visual != null:
			var press := create_tween()
			press.tween_property(visual, "position:y", visual.position.y + 4.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var notice := scene.find_child("UI_Notice", true, false) as Label if scene != null else null
		if notice != null:
			notice.text = "石扣沉了下去——前方的时空门正在显现。"
			notice.visible = true
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.call("play_event", "ui_confirm", 0.78, -2.0)
