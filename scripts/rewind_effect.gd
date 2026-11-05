extends Control
var frame: Texture2D
var ghosts: Array = []
var traces: Array = []
var age := 0.0
const DURATION := 0.48
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(dt: float) -> void:
	age += dt
	if age >= DURATION: queue_free()
	else: queue_redraw()
func _draw() -> void:
	var progress := clampf(age / DURATION, 0.0, 1.0)
	var fade := 1.0 - progress
	if frame != null:
		var dimensions := size * lerpf(1.0, 0.94, progress)
		draw_texture_rect(frame, Rect2((size - dimensions) / 2, dimensions), false, Color(0.75, 0.95, 1.0, fade * 0.65))
	for ghost in ghosts:
		var position: Vector2 = ghost.pos - ghost.velocity * age
		draw_set_transform(position, ghost.angle, Vector2.ONE * ghost.scale)
		draw_texture_rect(ghost.texture, Rect2(-Vector2.ONE * ghost.size / 2, Vector2.ONE * ghost.size), false, Color(ghost.color, fade * 0.8))
	draw_set_transform(Vector2.ZERO)
	for trace in traces:
		var point: Vector2 = trace.to.lerp(trace.from, progress)
		draw_line(point, point.lerp(trace.from, 0.15), Color(trace.color, fade), 2)
	for line in 10:
		var y := fposmod(size.y * (float(line) / 10.0 - progress * 0.6), size.y)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.85, 1.0, fade * 0.12), 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.65, 0.85, sin(progress * PI) * 0.06))
