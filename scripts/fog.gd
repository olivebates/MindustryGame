extends Node2D
var game: Node2D
func _draw() -> void:
	if game == null or game.fog_disabled: return
	for y in game.HEIGHT:
		for x in game.WIDTH:
			var cell := Vector2i(x, y)
			if not game.is_cell_visible(cell):
				draw_rect(Rect2(Vector2(cell * game.TILE), Vector2.ONE * game.TILE), Color("09070a"))
