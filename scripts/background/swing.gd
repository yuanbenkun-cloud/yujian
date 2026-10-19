class_name Swing
extends Node2D

## 摆动（SPEC 8.1）：灯笼/旗帜 rotation = sin(t*speed)*angle；绑定灯光的 energy 联动。

@export var speed: float = 1.0
@export var angle: float = 0.15
@export var light_path: NodePath = ""

var _t: float = 0.0
var _light: PointLight2D = null

func _ready() -> void:
	if not light_path.is_empty() and has_node(light_path):
		_light = get_node(light_path) as PointLight2D

func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * speed) * angle
	if _light != null:
		_light.energy = 0.8 + sin(_t * 1.7) * 0.15
