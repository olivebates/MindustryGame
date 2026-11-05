extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.get_node("Level/RockWalls").clear()
	game.get_node("Level/OreDeposits").clear()
	game.ores.clear()
	game.set_camera_zoom(1.8)
	var core: Vector2i = game.current_core
	for index in 4:
		var cell := core + Vector2i(-3 + index * 2, 3)
		game._add_building(cell, "solar", 0)
		game.buildings[cell].aim = index * PI / 2
	for index in 2:
		var cell := core + Vector2i(-1 + index * 2, 5)
		game.ores[cell] = "copper" if index == 0 else "iron"
		game._add_building(cell, "drill", 0)
	game.camera.position = game.cell_center(core + Vector2i(0, 2))
	game.camera.force_update_scroll()
	await shot("geist_sprites")
	game.hud.toggle_category("Structures")
	await shot("geist_build_menu")
	quit()
