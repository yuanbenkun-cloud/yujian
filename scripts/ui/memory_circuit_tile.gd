extends Button

var ports: int = 0:
	set(value):
		ports = value
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var ends: Array[Vector2] = [Vector2(center.x, 0), Vector2(size.x, center.y), Vector2(center.x, size.y), Vector2(0, center.y)]
	for side in range(4):
		if ports & (1 << side):
			draw_line(center, ends[side], Color("#78dded"), 5.0)
	draw_circle(center, 5.0, Color("#f0c574"))
