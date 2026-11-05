extends SceneTree
var game
func _initialize() -> void:
	call_deferred("capture")
func save_view(name: String) -> void:
	await create_timer(0.22).timeout
	game.hud.refresh()
	game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var dimensions: Vector2i = root.get_texture().get_size()
	root.get_texture().get_image().save_png("res://tests/%s_%d.png" % [name, dimensions.x])
func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	game.core_build_radius = 100000
	game.separate_build_categories = true
	game.researched["barriers"] = true
	game.researched["weapons"] = true
	game.researched["industry"] = true
	for kind in ["turret", "repeater", "cannon"]:
		for color in ["red", "green", "blue"]: game.researched[kind + "_" + color] = true
	game.base_copper_capacity = 500
	root.add_child(game)
	game.tutorial.extractors_ever_built = 1
	game.tutorial.extractor_connected_once = true
	game.tutorial.waves_started = true
	game.tutorial.tech_available = true
	game.selected = "belt"
	game.audio.muted = true
	game.set_process(false)
	for i in 200: game.simulate(0.05)
	await save_view("preview")
	game.hud.toggle_category("Defense")
	await save_view("categories")
	game.hud.show_tech_tree()
	await save_view("tech_tree")
	game.hud.close_modal()
	await process_frame
	game.hud.category = ""
	game.hud._rebuild_cards()
	game.selected = "turret"
	game.begin_drag(Vector2i(27, 22))
	game.hud.radial.position = game.get_canvas_transform() * game.cell_center(Vector2i(27, 22))
	await save_view("radial")
	game.finish_affinity("blue")
	game.rocks.erase(Vector2i(27, 22))
	game.active_tool = "build"
	game.selected = "belt"
	game._add_building(Vector2i(27, 20), "belt", 1)
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(29, 20))
	game.finish_drag()
	game.hover_cell = Vector2i(26, 20)
	await save_view("tunnel")
	game.capture_blueprint(Vector2i(25, 19), Vector2i(29, 23))
	game.hover_cell = Vector2i(24, 24)
	await save_view("blueprint")
	game.active_tool = "build"
	game.selected = ""
	game.hover_cell = game.INVALID
	game.base_material_capacity = 10000
	for resource in game.inventory: game.inventory[resource] = 900
	game.researched.forge = true
	game.researched.healer = true
	game.researched.cannon = true
	game.researched.repeater = true
	game.place_building(Vector2i(25, 17), "splitter", 0)
	for config in [[Vector2i(24, 17), 0], [Vector2i(26, 17), 0], [Vector2i(25, 18), 1], [Vector2i(25, 16), 3]]:
		game._add_building(config[0], "belt", config[1])
	game.buildings[Vector2i(24, 17)].item = "verdite"
	game.place_building(Vector2i(27, 24), "healer", 0)
	game.place_building(Vector2i(25, 25), "forge", 0)
	game.place_building(Vector2i(30, 22), "repeater", 0, "green")
	game.place_building(Vector2i(30, 24), "cannon", 0, "blue")
	game.launch_wave()
	for i in 300: game.simulate(0.05)
	var index := 0
	for kind in game.Content.ENEMY_TYPES:
		game.enemies.append(game.create_enemy(kind, game.cell_center(Vector2i(36 + (index % 3) * 2, 17 + (index / 3) * 3)), game.current_wave_color))
		index += 1
	game._drop_scrap(game.enemies[0])
	game._drop_scrap(game.enemies[1])
	await save_view("combat")
	game.toggle_pause()
	await save_view("paused")
	game.toggle_pause()
	game.hud.toggle_category("Storage")
	await save_view("storage")
	game.hud.toggle_category("Storage")
	game.enemies.clear()
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.active_spawners[0].waves_completed = game.active_spawners[0].waves_before_conversion - 1
	game._complete_wave()
	await save_view("frontier")
	print("VISUAL CAPTURES COMPLETE")
	quit()


