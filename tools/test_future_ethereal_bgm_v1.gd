extends SceneTree
## 新配乐实际切换、循环、音量恢复及不叠播检查，不修改音量配置/存档。

const TRACK := "res://assets/audio/future/第6关-星河回响-用户版.wav"
var _ok: bool = true

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_ok = _ok and value
	print(("[PASS] " if value else "[FAIL] ") + label)

func _run() -> void:
	change_scene_to_file("res://scenes/guanqia/06_future_chongqing.tscn")
	await create_timer(1.5).timeout
	var audio := root.get_node("AudioManager")
	var music := audio.get_node("MusicPlayer") as AudioStreamPlayer
	_check(audio.get("current_music_path") == TRACK and music.playing, "第六关自动播放星河回响")
	var stream := music.stream as AudioStreamWAV
	_check(stream != null and absf(stream.get_length() - 60.0) < 0.05, "用户提供的60秒立体声配乐加载成功")
	if stream != null:
		_check(stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > stream.loop_begin, "启用完整曲目循环播放")
	_check(is_equal_approx(music.volume_db, -2.0), "正常配乐音量为-2dB")
	audio.call("set_dialogue_active", true)
	await create_timer(0.3).timeout
	_check(is_equal_approx(music.volume_db, -8.0), "对话时再压低6dB")
	audio.call("set_dialogue_active", false)
	await create_timer(0.3).timeout
	_check(is_equal_approx(music.volume_db, -2.0), "对话结束后恢复配乐音量")
	var stream_before := music.stream
	audio.call("_on_scene_changed")
	await create_timer(0.1).timeout
	_check(music.stream == stream_before and music.playing, "同场景刷新不会重建或叠播音乐")
	_check(ResourceLoader.exists("res://assets/audio/future/第6关-城市脉冲.wav"), "原城市脉冲音频仍保留")
	change_scene_to_file("res://scenes/guanqia/02_ciqikou.tscn")
	await create_timer(0.6).timeout
	_check(audio.get("current_music_path") != TRACK and music.stream != stream_before, "离开第六关正常切换其他关卡音乐")
	print("[RESULT] " + ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
