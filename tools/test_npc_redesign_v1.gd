extends SceneTree

const KEYS := [
	"flyer_lady",
	"old_artisan",
	"aming",
	"old_shopkeeper",
	"fat_teahouse",
	"helper",
	"laozhou",
	"old_man",
]

var _ok := true


func _initialize() -> void:
	var raw := FileAccess.get_file_as_string("res://assets/npc_anim/meta.json")
	var parsed = JSON.parse_string(raw)
	_check(parsed is Dictionary, "NPC 动画配置可读取")
	if not parsed is Dictionary:
		quit(1)
		return
	for key in KEYS:
		var entry: Dictionary = parsed.get(key, {})
		var expected := "res://assets/production/npc/redesign/%s/sheet-transparent.png" % key
		_check(entry.get("walk_file", "") == expected, "%s 使用最终运行帧表" % key)
		_check(int(entry.get("walk_count", 0)) == 6 and int(entry.get("walk_cols", 0)) == 3, "%s 配置六帧行走" % key)
		var texture := load(expected) as Texture2D
		_check(texture != null, "%s 帧表可加载" % key)
		if texture != null:
			_check(texture.get_size() == Vector2(768, 512), "%s 帧表为 3×2、单帧 256" % key)
		var portrait_path := "res://assets/portraits/%s.png" % key
		var portrait := load(portrait_path) as Texture2D
		_check(portrait != null and portrait.get_size() == Vector2(384, 512), "%s 对话立绘已替换" % key)
	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_ok = false
		push_error("[FAIL] %s" % label)
