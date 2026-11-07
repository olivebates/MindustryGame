extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.saves.entries.clear()
	game.saves.current = -1
	game.saves.pending_branch = false
	game.research("barriers", true)
	game._add_building(Vector2i(27, 25), "wall", 0)
	game._add_building(Vector2i(28, 25), "solar", 0)
	for wave in range(1, 6):
		game.wave = wave
		game.saves.capture()
		await RenderingServer.frame_post_draw
	game.cores.append(Vector2i(45, 25))
	game.current_core = Vector2i(45, 25)
	game._add_building(game.current_core, "core", 0)
	game._add_building(Vector2i(47, 25), "turret", 0)
	game.research("iron_barriers", true)
	game.wave = 1
	game.saves.capture()
	await RenderingServer.frame_post_draw
	game.hud.refresh()
	game.hud.save_browser.show_browser()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/wave_grid_browser.png")
	print("WAVE GRID NATIVE CAPTURE FINISHED")
	game.free()
	quit()
