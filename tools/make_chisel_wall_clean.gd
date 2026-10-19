extends SceneTree
## 从原岩壁逐像素生成去亮橙外边框版本；不改内部砖缝、裂纹与木架。

const SOURCE := "res://assets/production/props/forge_stations/chisel-wall-v1.png"
const OUTPUT := "res://assets/production/props/forge_stations/chisel-wall-v2.png"

func _init() -> void:
	var texture := load(SOURCE) as Texture2D
	if texture == null:
		push_error("无法加载岩壁源图")
		quit(1)
		return
	var image := texture.get_image()
	var width := image.get_width()
	var height := image.get_height()
	for x in range(width):
		var top := -1
		var bottom := -1
		for y in range(height):
			if image.get_pixel(x, y).a > 0.12:
				if top < 0: top = y
				bottom = y
		if top >= 0:
			_tone_edge_pixel(image, x, top)
			_tone_edge_pixel(image, x, mini(top + 1, height - 1))
			_tone_edge_pixel(image, x, bottom)
			_tone_edge_pixel(image, x, maxi(bottom - 1, 0))
	for y in range(height):
		var left := -1
		var right := -1
		for x in range(width):
			if image.get_pixel(x, y).a > 0.12:
				if left < 0: left = x
				right = x
		if left >= 0:
			_tone_edge_pixel(image, left, y)
			_tone_edge_pixel(image, mini(left + 1, width - 1), y)
			_tone_edge_pixel(image, right, y)
			_tone_edge_pixel(image, maxi(right - 1, 0), y)
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("[CHISEL WALL] %s -> %s" % [SOURCE, OUTPUT])
	quit(0 if error == OK else 1)

func _tone_edge_pixel(image: Image, x: int, y: int) -> void:
	var color := image.get_pixel(x, y)
	if color.a <= 0.12:
		return
	var orange_score := (color.r - color.b) * 0.58 + (color.r - color.g) * 0.42
	if orange_score < 0.19 or color.r < 0.30:
		return
	var amount := clampf((orange_score - 0.16) * 2.2, 0.28, 0.78)
	var grounded := Color(color.r * 0.38, color.g * 0.48, color.b * 0.58, color.a)
	image.set_pixel(x, y, color.lerp(grounded, amount))
