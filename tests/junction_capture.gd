extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.rocks.clear()
	game.fog_disabled = true
	for offset in [0, 4]:
		var center := Vector2i(23 + offset, 23)
		game._add_building(center, "belt", 0)
		game._add_building(center + Vector2i(-1, 0), "belt", 0)
		game._add_building(center + Vector2i(0, -1), "belt", 1)
		if offset == 4: game._add_building(center + Vector2i(0, 1), "belt", 3)
		game._add_building(center + Vector2i(1, 0), "belt", 0)
	game.camera.position = game.cell_center(Vector2i(25, 23))
	game.camera.zoom = Vector2(3, 3)
	game.queue_redraw()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/junctions_preview.png")
	game.research("barriers", true)
	game.research("conveyor_speed", true)
	game.research("turret_range", true)
	game.tutorial.tech_available = true
	game.inventory.copper = 35
	game.inventory.scrap = 15
	game.discovered_resources.copper = true
	game.discovered_resources.scrap = true
	game.hud.refresh()
	game.hud.show_tech_tree()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/storage_preview.png")
	quit()


