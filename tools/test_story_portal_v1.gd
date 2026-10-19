extends SceneTree
## 时空裂隙叙事链：资源、转场模式与最终解释回归。

var _ok := true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	var director := root.get_node_or_null("StoryDirector")
	_check(director != null, "叙事导演已加载")
	var constants: Dictionary = director.get_script().get_script_constant_map()
	var stories: Dictionary = constants.get("TRANSITION_STORIES", {})
	var comics: Dictionary = constants.get("COMIC_STORIES", {})
	_check(stories.size() == 4, "第二至第五关均有独立剧情插画")
	_check(comics.size() == 4, "第二至第五关均有四格因果漫画")
	for level in [2, 3, 4, 5]:
		var data: Dictionary = stories.get(level, {})
		_check(ResourceLoader.exists(str(data.get("art", ""))), "第%d关插画资源存在" % level)
		_check(str(data.get("body", "")).length() >= 30, "第%d关包含剧情因果说明" % level)
		var beats: Array = comics.get(level, [])
		_check(beats.size() == 4, "第%d关漫画含四个逐步画格" % level)
		for beat: Dictionary in beats:
			_check(ResourceLoader.exists(str(beat.get("art", ""))) and str(beat.get("body", "")).length() >= 18, "第%d关画格资源与文案完整" % level)

	director.call("play_transition", "res://scenes/guanqia/02_ciqikou.tscn", 2, "")
	await create_timer(0.7).timeout
	_check(bool(director.get("busy")), "裂隙插画进入播放状态")
	_check(bool(director.get("_illustration_mode")), "转场使用全画幅插画布局")
	var comic := director.find_child("StoryComic", true, false)
	_check(comic != null, "首次穿越使用逐格漫画")
	var first_art := comic.find_child("ComicArt1", true, false) as TextureRect
	var first_texture := first_art.texture as AtlasTexture if first_art != null else null
	_check(first_texture != null and first_texture.atlas.resource_path.ends_with("portal-origin.png"), "首次穿越漫画保留古墙裂隙插画")
	director.set("_skip_all", true)
	await create_timer(0.8).timeout

	var file := FileAccess.open("res://assets/dialogue_level5.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	var old_man_text := ""
	if parsed is Dictionary:
		for line: Dictionary in parsed.get("old_man", {}).get("lines", []):
			old_man_text += str(line.get("text", ""))
	_check("洪崖门" in old_man_text and "只顾赶路" in old_man_text and "回头重走" in old_man_text, "第五关对白以日常聊天回收裂隙来源")
	print("[RESULT] %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)

func _check(condition: bool, message: String) -> void:
	print(("[PASS] " if condition else "[FAIL] ") + message)
	_ok = _ok and condition
