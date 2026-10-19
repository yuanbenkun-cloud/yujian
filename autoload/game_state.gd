extends Node
## GameState（全局单例）：跨关数据（货物完整度、历史领悟等）。SPEC Phase 5。

signal goods_changed(current: int, delta: int, event_name: String)

const SAVE_PATH := "user://story_save.cfg"

var goods_integrity: int = 100
var insight_flags: Dictionary = {}   # 历史领悟（第五关等使用）
var saved_level: int = 0
var highest_unlocked_level: int = 1
var story_completed := false
var completed_levels: Array[int] = []

func record_level_completed(level: int) -> void:
	if level < 1 or level > 5 or completed_levels.has(level): return
	completed_levels.append(level)
	_save_story()

func can_enter_future() -> bool:
	for level in range(1, 6):
		if not completed_levels.has(level): return false
	return true
var ending_choice := "observe"
var photo_timestamp := ""

func _ready() -> void:
	_load_story()

func record_insight(key: String, value: Variant = true) -> void:
	insight_flags[key] = value
	_save_story()

func reset_story() -> void:
	goods_integrity = 100
	insight_flags.clear()
	ending_choice = "observe"
	photo_timestamp = ""

func capture_photo_timestamp() -> String:
	## 使用玩家按下快门时的本机时间；同一时间会保留到片尾照片。
	var now := Time.get_datetime_dict_from_system(false)
	photo_timestamp = "%04d年%02d月%02d日 %02d:%02d:%02d · 重庆" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
	]
	_save_story()
	return photo_timestamp

func get_photo_timestamp(compact: bool = false) -> String:
	if photo_timestamp == "":
		return "拍摄时间未记录"
	if not compact:
		return photo_timestamp
	var parts := photo_timestamp.split(" ")
	if parts.size() < 2:
		return photo_timestamp
	var date_text := str(parts[0]).replace("年", ".").replace("月", ".").replace("日", "")
	var time_text := str(parts[1])
	if time_text.length() >= 5:
		time_text = time_text.substr(0, 5)
	return date_text + " " + time_text

func begin_new_story() -> void:
	reset_story()
	saved_level = 1
	highest_unlocked_level = 1
	story_completed = false
	_save_story()

func begin_from_chapter(level: int) -> void:
	var unlocked := highest_unlocked_level
	reset_story()
	saved_level = clampi(level, 1, 5)
	highest_unlocked_level = maxi(unlocked, saved_level)
	story_completed = false
	_save_story()

func save_progress(level: int) -> void:
	saved_level = clampi(level, 1, 5)
	highest_unlocked_level = maxi(highest_unlocked_level, saved_level)
	story_completed = false
	_save_story()

func has_continue() -> bool:
	return saved_level >= 1 and saved_level <= 5 and not story_completed

func get_continue_level() -> int:
	return clampi(saved_level, 1, 5)

func mark_story_complete(choice: String) -> void:
	record_level_completed(5)
	ending_choice = choice
	story_completed = true
	saved_level = 0
	highest_unlocked_level = 5
	_save_story()

func reset_goods() -> void:
	goods_integrity = 100
	goods_changed.emit(goods_integrity, 0, "reset")
	_save_story()

func apply_goods_event(event_name: String) -> void:
	## stolen -30 / cheated -30 / robbed -40 / safe 0
	var before := goods_integrity
	match event_name:
		"stolen":
			goods_integrity -= 30
		"cheated":
			goods_integrity -= 30
		"robbed":
			goods_integrity -= 40
		_:
			pass  # safe / 空
	goods_integrity = clampi(goods_integrity, 0, 100)
	goods_changed.emit(goods_integrity, goods_integrity - before, event_name)
	_save_story()

func get_result_tier() -> String:
	## 100% 完好；50%及以上仍可交付；严格低于一半才失败。
	if goods_integrity >= 100:
		return "完好"
	if goods_integrity >= 50:
		return "受损"
	return "严重受损"

func _save_story() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "saved_level", saved_level)
	cfg.set_value("progress", "highest_unlocked_level", highest_unlocked_level)
	cfg.set_value("progress", "story_completed", story_completed)
	cfg.set_value("progress", "completed_levels", completed_levels)
	cfg.set_value("progress", "clear_records_version", 2)
	cfg.set_value("progress", "ending_choice", ending_choice)
	cfg.set_value("progress", "photo_timestamp", photo_timestamp)
	cfg.set_value("run", "goods_integrity", goods_integrity)
	cfg.set_value("run", "insight_flags", insight_flags)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("剧情存档写入失败：%d" % err)

func _load_story() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	saved_level = int(cfg.get_value("progress", "saved_level", 0))
	highest_unlocked_level = int(cfg.get_value("progress", "highest_unlocked_level", 1))
	story_completed = bool(cfg.get_value("progress", "story_completed", false))
	completed_levels.clear()
	var cleared: Variant = cfg.get_value("progress", "completed_levels", [])
	if int(cfg.get_value("progress", "clear_records_version", 0)) >= 2 and cleared is Array:
		for level: Variant in cleared:
			if level is int and level >= 1 and level <= 5 and not completed_levels.has(level): completed_levels.append(level)
	# Old lists may have been inferred from a debug ending. Never manufacture clear records.
	# Keep the original save recoverable before the first corrected save overwrites it.
	if int(cfg.get_value("progress", "clear_records_version", 0)) < 2:
		var backup: String = SAVE_PATH + ".before_verified_clears.bak"
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(backup))
	ending_choice = str(cfg.get_value("progress", "ending_choice", "observe"))
	photo_timestamp = str(cfg.get_value("progress", "photo_timestamp", ""))
	goods_integrity = clampi(int(cfg.get_value("run", "goods_integrity", 100)), 0, 100)
	var loaded_flags = cfg.get_value("run", "insight_flags", {})
	insight_flags = loaded_flags if loaded_flags is Dictionary else {}
