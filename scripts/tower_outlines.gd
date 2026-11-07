extends Node2D
var game: Node2D
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	var width := 1.0 / get_screen_transform().x.length()
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.get("pending", false): continue
		if not game.is_turret(b.kind) or not game.is_cell_visible(cell): continue
		var area := Rect2(Vector2(cell * game.TILE) - Vector2.ONE * width / 2, Vector2.ONE * (game.TILE * game.footprint_size(b.kind) + width))
		draw_rect(area, game.TEAM_COLORS[b.color], false, width)
