extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
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
	game.set_process(false)
	game.fog_disabled = true
	game.fog.queue_redraw()
	game.hud.root.hide()
	for cell in game.buildings.keys():
		if cell != game.CORE: game.remove_building(cell, false)
	var route: Array[Vector2i] = []
	for x in range(4, 9): route.append(Vector2i(x, 4))
	for y in range(5, 9): route.append(Vector2i(8, y))
	for x in range(7, 3, -1): route.append(Vector2i(x, 8))
	for y in range(7, 4, -1): route.append(Vector2i(4, y))
	for i in route.size():
		var cell := route[i]
		game._add_building(cell, "belt", game.direction_for(route[(i + 1) % route.size()] - cell))
		game.buildings[cell].input_dir = game.direction_for(cell - route[posmod(i - 1, route.size())])
	game.buildings[route[1]].item = "copper"
	game.buildings[route[8]].item = "iron"
	game.camera.position = game.cell_center(Vector2i(6, 6))
	game.camera.zoom = Vector2.ONE * 4.0
	game.elapsed = 0.52
	for index in 3:
		game.queue_redraw()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/conveyor_loop_%d.png" % index)
		game.simulate(0.02)
	print("CONVEYOR LOOP CAPTURES COMPLETE")
	quit()


