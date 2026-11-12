extends "res://tests/iron_supply_zoom.gd"
func capture(name: String) -> void:
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s.png" % name)
func run() -> void:
	fresh()
	game.base_copper_capacity = 100
	game.tutorial.skip_to_ready()
	game.tutorial.waves_started = true
	game.tutorial.tech_available = true
	game.wave = 4
	game.camera.position = game.cell_center(game.current_core)
	game.set_camera_zoom(2)
	for index in 7:
		var kind: String = game.Content.ENEMY_TYPES.keys()[index]
		var enemy: Dictionary = game.create_enemy(kind, game.cell_center(Vector2i(16 + index * 3, 22)), ["red", "green", "blue"][index % 3])
		enemy.angle = 0.0
		enemy.aim = 0.0
		game.enemies.append(enemy)
	for pair in [[Vector2i(19, 27), "healer"], [Vector2i(22, 27), "refinery"], [Vector2i(26, 27), "copper_store"], [Vector2i(29, 27), "iron_store"], [Vector2i(20, 28), "wall"]]:
		game._add_building(pair[0], pair[1], 0)
	for b in game.buildings.values(): b.pending = false
	game.buildings[Vector2i(19, 27)].buffer.pink = 4
	game.buildings[Vector2i(26, 27)].buffer.pink = 3
	game.buildings[Vector2i(29, 27)].buffer.pink = 3
	game.buildings[Vector2i(20, 28)].hp = 12
	game._update_healer(Vector2i(19, 27), game.buildings[Vector2i(19, 27)], 0.1)
	game.buildings[Vector2i(22, 27)].buffer.copper = 3
	game.buildings[Vector2i(22, 27)].buffer.iron = 3
	game.buildings[Vector2i(22, 27)].progress = 5
	game.inventory.copper = 149
	game.inventory.iron = 40
	game.inventory.pink = 8
	game.ores[Vector2i(19, 22)] = "copper"
	game.hover_cell = Vector2i(19, 22)
	game.hud.refresh()
	await create_timer(0.5).timeout
	game.add_resource("copper", 1)
	await capture("food_fuel_world")
	game.hud.show_structure_info("healer", game.buildings[Vector2i(19, 27)], Vector2(1500, 900))
	await capture("food_fuel_healer_info")
	game.cores.append_array([Vector2i(60, 25), Vector2i(90, 25)])
	for id in ["barriers", "solar_speed", "turret_range", "weapons"]: game.research(id, true)
	game.hud.show_tech_tree()
	await capture("food_fuel_tech")
	game.hud.close_modal()
	await process_frame
	game.fog_disabled = false
	game._reveal_map()
	game.camera.position = game.clamp_camera_position(Vector2(-500, -500))
	game.camera.force_update_scroll()
	await capture("forest_fog_negative")
	print("FOOD FUEL CAPTURES FINISHED")
	game.free()
	quit()
