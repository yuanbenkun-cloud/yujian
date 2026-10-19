extends SceneTree

func _init() -> void:
	var source := "C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-6a618c31-bc47-403f-a07c-eef8c861ad41.png"
	var image := Image.load_from_file(source)
	if image == null:
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i.ZERO
	var transparent := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.4:
				transparent += 1
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	print("[ALPHA] transparent pixels=", transparent, " / ", image.get_width() * image.get_height())
	if transparent == 0:
		push_error("Generated barrier has no usable alpha; do not ship a black rectangle.")
		quit(1)
		return
	var bounds := Rect2i(min_point, max_point - min_point + Vector2i.ONE)
	var crop := image.get_region(bounds)
	crop.resize(192, 96, Image.INTERPOLATE_NEAREST)
	var destination := "res://assets/production/future/maintenance-barrier-v5.png"
	print("[SAVE] ", destination, " error=", crop.save_png(destination))
	# Report source alpha instead of assuming node modulation is the final opacity.
	var shield := Image.load_from_file("res://assets/production/props/gameplay/blast-shield-ai-v2.png")
	print("[HISTORY SOURCE] center alpha=", shield.get_pixel(shield.get_width()/2, shield.get_height()/3).a)
	quit()
