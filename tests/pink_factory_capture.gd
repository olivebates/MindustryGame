extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	for id in ["barriers", "turret_range", "copper_storage", "weapons", "refining"]: game.research(id, true)
	var refinery := Vector2i(20, 25)
	game._add_building(refinery, "refinery", 0)
	game.buildings[refinery].buffer.copper = 4
	game.buildings[refinery].buffer.iron = 3
	game.buildings[refinery].progress = 1.9
	game._add_building(Vector2i(26, 25), "turret", 0)
	game.buildings[Vector2i(26, 25)].booster_type = "pink"
	game.buildings[Vector2i(26, 25)].booster_count = 6
	game._add_building(Vector2i(24, 28), "iron_store", 0)
	game.buildings[Vector2i(24, 28)].buffer.pink = 4
	game._add_building(Vector2i(22, 26), "belt", 0)
	game.buildings[Vector2i(22, 26)].item = "pink"
	game.inventory.pink = 6
	game.tutorial.on_building_placed("refinery", refinery)
	game.hud.refresh()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pink_factory.png")
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pink_tech.png")
	print("PINK FACTORY NATIVE CAPTURE FINISHED")
	game.free()
	quit()
