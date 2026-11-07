extends RefCounted
const MIN_STROKE := 3.0
static var shield_style: StyleBoxFlat
static func draw_construction(item: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	item.draw_texture_rect(texture, rect, false, Color(1, 1, 1, 0.33))
	var scale := maxf(0.001, item.get_screen_transform().x.length())
	var width := 3.0 / scale
	var dash := 5.0 / scale
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for edge in 4:
		var from: Vector2 = corners[edge]
		var to: Vector2 = corners[(edge + 1) % 4]
		var length := from.distance_to(to)
		var distance := 0.0
		while distance < length:
			item.draw_line(from.lerp(to, distance / length), from.lerp(to, minf(length, distance + dash) / length), Color("f3ded5"), width)
			distance += dash * 2
static func draw_shield(item: CanvasItem, rect: Rect2, alpha: float, width: float) -> void:
	if shield_style == null:
		shield_style = StyleBoxFlat.new()
		shield_style.set_corner_radius_all(7)
		shield_style.anti_aliasing = false
	shield_style.set_border_width_all(maxi(1, roundi(width)))
	shield_style.bg_color = Color(0.2, 0.65, 1, 0.06 * alpha)
	shield_style.border_color = Color(0.35, 0.75, 1, 0.85 * alpha)
	item.draw_style_box(shield_style, rect)
static func stroke(item: CanvasItem) -> float:
	var transform := item.get_screen_transform()
	var scale := minf(transform.x.length(), transform.y.length())
	# Two grid cells retain at least three physical pixels after snapping.
	return maxf(MIN_STROKE, 4.0 / maxf(0.001, scale))
