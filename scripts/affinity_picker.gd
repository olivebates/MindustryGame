extends Control
const COLORS := {"red": Color("f16e64"), "green": Color("83d780"), "blue": Color("7aa7f0")}
const ANGLES := [-PI / 2, PI / 6, PI * 5 / 6]
var choice := ""
var available: Array[String] = ["red", "green", "blue"]
func selected_at(pointer: Vector2) -> String:
	if pointer.length() <= 20: return ""
	var best := INF
	var selected := ""
	var index := 0
	for color in COLORS:
		var delta: float = absf(wrapf(pointer.angle() - ANGLES[index], -PI, PI))
		if delta < best:
			best = delta
			selected = color
		index += 1
	return selected if available.has(selected) else ""
func _process(_dt: float) -> void:
	choice = selected_at(get_local_mouse_position())
	queue_redraw()
func _draw() -> void:
	var index := 0
	for color in COLORS:
		var start: float = ANGLES[index] - PI / 3
		var points := PackedVector2Array([Vector2.ZERO])
		for step in 33: points.append(Vector2.from_angle(start + (TAU / 3) * step / 32.0) * 105)
		var tint: Color = COLORS[color]
		var unlocked := available.has(color)
		draw_colored_polygon(points, Color(tint if unlocked else Color("252022"), 0.65 if choice == color else 0.25))
		draw_line(Vector2.from_angle(start) * 20, Vector2.from_angle(start) * 105, Color("edb183"), 1)
		var p := Vector2.from_angle(ANGLES[index]) * 65
		draw_circle(p, 10, tint if unlocked else Color("54494a"))
		if not unlocked: draw_string(ThemeDB.fallback_font, p + Vector2(-17, 27), "Locked", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b29a91"))
		index += 1
	draw_arc(Vector2.ZERO, 105, 0, TAU, 96, Color("edb183"), 1)
	draw_circle(Vector2.ZERO, 20, Color("140c10"))
	draw_arc(Vector2.ZERO, 20, 0, TAU, 40, Color("edb183"), 1)
