class_name CompanionAvatar
extends Control

## 正式像素版“渝灯”：4 帧悬浮循环，资源由 generate2dsprite 流程校正。

const SHEET := "res://assets/production/companion/yudeng/sheet-transparent.png"
const CELL := Vector2(128, 128)

var talking := false:
	set(value):
		talking = value
		if _sprite != null:
			_sprite.speed_scale = 1.45 if talking else 1.0

var _sprite: AnimatedSprite2D
var facing: int = -1

func set_facing(direction: int) -> void:
	facing = 1 if direction >= 0 else -1
	if _sprite != null:
		_sprite.flip_h = facing > 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 76)
	_build_animation()

func _build_animation() -> void:
	var sheet := load(SHEET) as Texture2D
	if sheet == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("hover")
	frames.set_animation_loop("hover", true)
	frames.set_animation_speed("hover", 5.0)
	for i in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(float(i % 2), float(i / 2)) * CELL, CELL)
		frames.add_frame("hover", frame)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "YudengSprite"
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(36, 38)
	_sprite.scale = Vector2.ONE * 0.58
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.speed_scale = 1.45 if talking else 1.0
	add_child(_sprite)
	_sprite.play("hover")
	set_facing(facing)
