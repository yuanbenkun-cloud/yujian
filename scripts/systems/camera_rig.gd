class_name CameraRig
extends Camera2D

## 相机（Phase 1 产出）：跟随 Player（position_smoothing_enabled）+ shake() 震屏。
## （实现细节：spec 未给该脚本路径，放 scripts/systems/，见 DEV_LOG。）

var _shake_remaining: float = 0.0
var _shake_strength: float = 4.0
var _shake_duration: float = 0.3
var _shake_time: float = 0.0

func _ready() -> void:
	var level_root := get_parent().get_parent()
	if level_root == null:
		level_root = get_tree().current_scene
	if level_root != null and level_root.has_meta("camera_right_limit"):
		limit_right = int(level_root.get_meta("camera_right_limit"))

func _process(delta: float) -> void:
	if _shake_remaining > 0.0:
		_shake_remaining -= delta
		_shake_time += delta * 30.0
		var t := maxf(_shake_remaining / _shake_duration, 0.0)
		var access := get_node_or_null("/root/Accessibility")
		var scale_value := float(access.get("shake_scale")) if access != null else 1.0
		var smooth_noise := Vector2(sin(_shake_time * 1.7), sin(_shake_time * 2.3))
		offset = smooth_noise * _shake_strength * t * t * scale_value
		if _shake_remaining <= 0.0:
			offset = Vector2.ZERO

func shake(strength: float = 4.0, duration: float = 0.3) -> void:
	_shake_strength = strength
	_shake_duration = duration
	_shake_remaining = duration
	_shake_time = 0.0
