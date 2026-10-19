extends "res://scripts/npc/interactable.gd"

## 码头老周（第三关）：按 GameState 货物完整度触发 3 档验货对话；完好交付后开启出口时空门。

const TIER_NODES := {
	"完好": "laozhou_good",
	"受损": "laozhou_damaged",
	"严重受损": "laozhou_bad",
}

var _delivery_failed := false

func on_interact(_player: Node) -> void:
	var route := get_tree().current_scene.find_child("ChoiceSystem", true, false)
	if route != null and not bool(route.call("can_use", 3)):
		route.call("show_locked", 3)
		return
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds == null:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var tier := str(gs.call("get_result_tier"))
	_delivery_failed = int(gs.get("goods_integrity")) < 50
	gs.call("record_insight", "trust", tier)
	var node_name: String = TIER_NODES.get(tier, "laozhou_good")
	ds.call("load_data", "res://assets/dialogue_level3.json")
	if not ds.is_connected("ended", _on_dialogue_ended):
		ds.connect("ended", _on_dialogue_ended)
	set_meta("talking", true)
	ds.call("start_dialogue", node_name)

func _on_dialogue_ended() -> void:
	set_meta("talking", false)
	var ds := get_node_or_null("/root/DialogueSystem")
	if ds != null and ds.is_connected("ended", _on_dialogue_ended):
		ds.disconnect("ended", _on_dialogue_ended)
	var lm := get_node_or_null("/root/LevelManager")
	if _delivery_failed:
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			gs.call("reset_goods")
		if lm != null:
			lm.call("fail", "染布剩余不足一半，老周无法签收。重新护送这包染布吧。")
	else:
		disable_interaction()
		var portal := get_tree().current_scene.find_child("disanguan_chukou", true, false)
		if portal != null and portal.has_method("activate"):
			portal.call("activate")
		var route := get_tree().current_scene.find_child("ChoiceSystem", true, false)
		if route != null:
			route.call("advance_stage", 4)
			route.call("show_completed")
