extends Node2D
var game: Node2D
func _process(_dt: float) -> void:
	visible = game.paused
	if visible: queue_redraw()
func grid_bounds() -> Rect2:
	var inverse := get_canvas_transform().affine_inverse()
	var view := get_viewport_rect()
	return Rect2(inverse * view.position, (inverse * view.end) - (inverse * view.position))
func _draw() -> void:
	if not game.paused: return
	var area := grid_bounds()
	var start: Vector2 = Vector2((area.position / game.TILE).floor()) * game.TILE
	var finish: Vector2 = Vector2((area.end / game.TILE).ceil()) * game.TILE
	var tint := Color(0.75, 0.90, 0.95, 0.11)
	var width: float = 1.0 / game.camera.zoom.x
	for x in range(int(start.x), int(finish.x) + 1, game.TILE): draw_line(Vector2(x, start.y), Vector2(x, finish.y), tint, width)
	for y in range(int(start.y), int(finish.y) + 1, game.TILE): draw_line(Vector2(start.x, y), Vector2(finish.x, y), tint, width)

