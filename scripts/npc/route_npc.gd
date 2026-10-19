extends "res://scripts/npc/interactable.gd"
## 第三关顺序交互 NPC：对话完整结束后推进路线阶段。

@export var dialogue_file := "res://assets/dialogue_level3.json"
@export var dialogue_node := ""
@export var required_stage := 0
@export var next_stage := 0
var _completed := false

func on_interact(_player: Node) -> void:
	var manager := get_tree().current_scene.find_child("ChoiceSystem", true, false)
	if manager == null:
		return
	if _completed:
		manager.call("show_completed")
		return
	if not bool(manager.call("can_use", required_stage)):
		manager.call("show_locked", required_stage)
		return
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds == null:
		return
	# NPC模板原脚本序列化了空路径，替换脚本后仍会覆盖新的导出默认值。
	var data_path: String = dialogue_file if not dialogue_file.is_empty() else "res://assets/dialogue_level3.json"
	if not bool(ds.call("load_data", data_path)):
		return
	if not ds.is_connected("ended", _on_ended):
		ds.connect("ended", _on_ended)
	set_meta("talking", true)
	ds.call("start_dialogue", dialogue_node)

func _on_ended() -> void:
	set_meta("talking", false)
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds != null and ds.is_connected("ended", _on_ended):
		ds.disconnect("ended", _on_ended)
	_completed = true
	disable_interaction()
	var manager := get_tree().current_scene.find_child("ChoiceSystem", true, false)
	if manager != null:
		manager.call("advance_stage", next_stage)
