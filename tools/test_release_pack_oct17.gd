extends SceneTree
## Run with --main-pack <export.pck> --script <absolute path to this file>.
var failed: bool = false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("[PASS] " if value else "[FAIL] ") + label)
	failed = failed or not value

func _run() -> void:
	# Stage four uses scripted escort dialogue rather than a separate JSON file.
	for level in [1, 2, 3, 5]:
		var path: String = "res://assets/dialogue_level%d.json" % level
		check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "发行包包含第%d关对话JSON" % level)
	var lm: Node = root.get_node("LevelManager")
	for path: String in lm.SCENES + [lm.FUTURE_SCENE]:
		var scene: PackedScene = load(path)
		check(scene != null, "发行包可加载关卡：" + path.get_file())
		if scene != null:
			var instance: Node = scene.instantiate()
			check(instance != null, "关卡场景与脚本可实例化")
			instance.free()
	check(root.get_node("YudengChat").PROVIDER_PRESETS.size() == 6, "发行包含最新五平台AI预设和自定义项")
	check(ResourceLoader.exists("res://scripts/ui/memory_circuit.gd"), "发行包含第六关线路解谜")
	for path: String in ["res://scenes/guanqia/05_hongyadong_return.tscn", "res://scenes/guanqia/06_future_chongqing.tscn"]:
		change_scene_to_file(path)
		await create_timer(0.3).timeout
		check(current_scene != null and current_scene.get_node_or_null("zhujue") != null, "包内实际装配运行：" + path.get_file())
	for path: String in ["res://tools", "res://preview", "res://docs", "res://art_source", "res://air_quality_study", "res://Build"]:
		check(not DirAccess.dir_exists_absolute(path), "不夹带开发/无关目录：" + path)
	for path: String in ["res://yudeng_ai.cfg", "res://story_save.cfg", "res://.env"]:
		check(not FileAccess.file_exists(path), "不夹带本机配置：" + path)
	print("[RESULT] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
