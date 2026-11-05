extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.get_node("Level/RockWalls").clear()
	var ores: TileMapLayer = game.get_node("Level/OreDeposits")
	ores.clear()
	game.ores.clear()
	var core: Vector2i = game.current_core
	for y in range(-2, 2):
		for x in range(-6, -3):
			var cell := core + Vector2i(x, y)
			ores.set_cell(cell, 0, Vector2i.ZERO)
			game.ores[cell] = "copper"
	for y in range(-2, 2):
		for x in range(3, 6):
			var cell := core + Vector2i(x, y)
			ores.set_cell(cell, 1, Vector2i.ZERO)
			game.ores[cell] = "iron"
	for x in range(-5, 5): game._add_building(core + Vector2i(x, 3), "belt", 0)
	game._add_building(core + Vector2i(5, 3), "belt", 3)
	game.buildings[core + Vector2i(5, 3)].input_dir = 0
	game._add_building(core + Vector2i(5, 2), "belt", 3)
	game.elapsed = 5.4
	game.hover_cell = core + Vector2i(-5, -1)
	game.manual_mining_cell = game.hover_cell
	game.manual_mining_progress = 0.62
	game.camera.position = game.cell_center(core)
	for zoom in game.ZOOM_LEVELS:
		game.set_camera_zoom(zoom)
		game.camera.position = (game.camera.position * game.camera.zoom).round() / game.camera.zoom
		game.camera.force_update_scroll()
		await shot("pixel_grid_%d" % roundi(zoom * 100))
	quit()
