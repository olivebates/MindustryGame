extends Node2D
var game: Node2D
func _ready() -> void:
	material = game.material
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
	var width: float = game.WORLD_PIXEL_SIZE
	for x in range(int(start.x), int(finish.x) + 1, game.TILE):
		draw_rect(Rect2(Vector2(x, start.y), Vector2(width, finish.y - start.y)), tint)
	for y in range(int(start.y), int(finish.y), game.TILE):
		for x in range(int(start.x), int(finish.x), game.TILE):
			draw_rect(Rect2(Vector2(x + width, y), Vector2(game.TILE - width, width)), tint)


