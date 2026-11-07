extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	game._add_building(Vector2i(27, 25), "wall", 0)
	game._add_building(Vector2i(28, 25), "wall", 0)
	game.buildings[Vector2i(28, 25)].hp = 15
	game.enemies.assign([game.create_enemy("scout", game.cell_center(Vector2i(20, 25)), "red")])
	game._add_building(Vector2i(27, 27), "wall", 0)
	game._add_building(Vector2i(29, 27), "solar", 0)
	game._add_building(Vector2i(25, 28), "turret", 0)
	game._add_building(Vector2i(26, 27), "belt", 1)
	game._add_building(Vector2i(24, 27), "drill", 0)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pending_construction.png")
	print("PENDING CONSTRUCTION CAPTURE FINISHED")
	game.free()
	quit()
