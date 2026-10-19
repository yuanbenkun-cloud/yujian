class_name Interactable
extends Area2D

## 交互物基类（SPEC Phase 1 / 4.4）：Area2D + 提示圈。
## 子类覆盖 on_interact(player)。玩家靠近显示 Prompt，按 E 触发。

var _interaction_enabled := true

func _prompt() -> Node:
	for c in get_children():
		var nm := str(c.name)
		if nm == "Prompt" or nm.ends_with("_tishi"):
			return c
	return null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_prompt_visible(false)

func set_prompt_visible(value: bool) -> void:
	var pp := _prompt()
	if pp != null:
		# 世界空间色块不再悬在人物/建筑上；统一提示改由玩家 HUD 在屏幕底部显示。
		pp.visible = false

func on_interact(_player: Node) -> void:
	pass

func is_interaction_available() -> bool:
	return _interaction_enabled

func disable_interaction() -> void:
	var guide: Node = get_node_or_null("/root/QuestGuide")
	if guide != null: guide.call("request_refresh")
	_interaction_enabled = false
	set_prompt_visible(false)
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.find_child("zhujue", true, false)
	if player != null and player.has_method("remove_nearby_interaction"):
		player.call("remove_nearby_interaction", self)

## 用鸭子类型判断主角（不依赖全局类缓存；headless --script 场景下类缓存可能缺失）
func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and body.has_method("set_look_dir")

func _on_body_entered(body: Node) -> void:
	if _interaction_enabled and _is_player(body):
		set_prompt_visible(true)

func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		set_prompt_visible(false)
