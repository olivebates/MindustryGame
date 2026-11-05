extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hud.refresh()
	game.hud._process(0)
	game.tutorial.queue_redraw()
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/designated_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio.muted = true
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	await shot("mining")
	game.add_resource("copper", 5)
	game.select_building("drill")
	game.place_building(Vector2i(20, 22), "drill", 0)
	await shot("deselect")
	game.cancel_build_selection()
	await shot("mine_more")
	game.add_resource("copper", 20)
	game.select_building("belt")
	game.place_building(Vector2i(25, 23), "belt", 0)
	await shot("misplaced")
	game.select_tool("abolish")
	await shot("demolish")
	game.remove_building(Vector2i(25, 23))
	await shot("leave")
	game.cancel_build_selection()
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
	await shot("start")
	game.launch_wave()
	game._damage_building(Vector2i(31, 22), 1)
	game.toggle_pause()
	await shot("grid")
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.enemies.clear()
	game.scraps.append({"pos": game.cell_center(game.current_core), "amount": 3, "magnetized": false})
	game._complete_wave()
	game.collect_scrap(0.1, game.cell_center(game.current_core))
	game.inventory.copper = 20
	game.hud.show_tech_tree()
	game.hud.tech_buttons.barriers.button.pressed.emit()
	await shot("research")
	game.hud.close_modal()
	await process_frame
	await shot("categories")
	game.inventory.copper = 40
	game.inventory.scrap = 20
	game.research("conveyor_speed")
	await shot("upgraded_belts")
	for entry in game.saves.entries:
		DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
		if FileAccess.file_exists(game.saves.preview_path(entry.file)): DirAccess.remove_absolute(game.saves.preview_path(entry.file))
	print("DESIGNATED CAPTURES COMPLETE")
	quit()
