extends RefCounted
var last_position := Vector2(INF, INF)
var last_result := Vector2.ZERO
var last_revision := -1
var last_fog_disabled := false
func clamp_position(game: Node2D, point: Vector2) -> Vector2:
	if (point == last_position or point == last_result) and last_revision == game.visibility_revision and last_fog_disabled == game.fog_disabled: return last_result
	last_position = point
	last_revision = game.visibility_revision
	last_fog_disabled = game.fog_disabled
	var closest: Vector2 = game.cell_center(game.current_core)
	if game.fog_disabled:
		closest = point.clamp(Vector2.ZERO, Vector2(game.WIDTH, game.HEIGHT) * game.TILE)
	elif game.visible_cells.has(Vector2i((point / game.TILE).floor())):
		closest = point
	else:
		var distance := INF
		for cell in game.visible_cells:
			var corner := Vector2(cell * game.TILE)
			var candidate := point.clamp(corner, corner + Vector2.ONE * game.TILE)
			var squared := point.distance_squared_to(candidate)
			if squared < distance:
				distance = squared
				closest = candidate
	last_result = closest + (point - closest).limit_length(game.TILE * 20.0)
	return last_result
