extends Node2D
## 第一关低顶棚：地面可正常通行，但起跳后会撞到棚顶，不能越过关键人流。

const ROOFS := [Vector2(1040, 190), Vector2(1700, 190), Vector2(2380, 190)]
const ROOF_SIZE := Vector2(126, 24)

func _ready() -> void:
	z_index = 14
	for i in range(ROOFS.size()):
		var body := StaticBody2D.new()
		body.name = "LowRoof%d" % (i + 1)
		body.position = ROOFS[i]
		body.set_meta("blocks_jump", true)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = ROOF_SIZE
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
	queue_redraw()

func _draw() -> void:
	for i in range(ROOFS.size()):
		var p: Vector2 = ROOFS[i]
		var left: float = p.x - ROOF_SIZE.x * 0.5
		var right: float = p.x + ROOF_SIZE.x * 0.5
		draw_rect(Rect2(left + 7.0, p.y + 12.0, 4.0, 58.0), Color("#493a3b"))
		draw_rect(Rect2(right - 11.0, p.y + 12.0, 4.0, 58.0), Color("#493a3b"))
		draw_rect(Rect2(left, p.y - 12.0, ROOF_SIZE.x, 24.0), Color("#6d3f45"))
		for stripe in range(7):
			var color := Color("#d38a63") if stripe % 2 == 0 else Color("#8b4c50")
			draw_colored_polygon(PackedVector2Array([
				Vector2(left + stripe * 18.0, p.y - 12.0), Vector2(left + (stripe + 1) * 18.0, p.y - 12.0),
				Vector2(left + (stripe + 1) * 18.0 - 4.0, p.y + 12.0), Vector2(left + stripe * 18.0 - 4.0, p.y + 12.0),
			]), color)
		draw_line(Vector2(left, p.y + 12.0), Vector2(right, p.y + 12.0), Color("#f0bd77"), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(p.x - 22.0, p.y - 18.0), "慢行", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, Color("#f7dba2"))
