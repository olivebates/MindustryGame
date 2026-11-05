extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func key_alt(held: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ALT
	key.pressed = held
	Input.parse_input_event(key)
	Input.flush_buffered_events()
func shot(name: String) -> void:
	game.hud.refresh()
	game.hud._process(0)
	game.tutorial.queue_redraw()
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/inspection_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio.muted = true
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.add_resource("copper", 5)
	game.select_building("drill")
	game.place_building(Vector2i(20, 22), "drill", 0)
	game.add_resource("copper", 2)
	game.select_building("belt")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.add_resource("copper", 10)
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
	game.select_tool("abolish")
	game.cancel_build_selection()
	game.launch_wave()
	game._damage_building(Vector2i(31, 22), 1)
	await shot("pause_intro")
	game.toggle_pause()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.enemies.clear()
	game._complete_wave()
	for offset in [Vector2i(2, 1), Vector2i(3, 2), Vector2i(4, 1)]:
		game.scraps.append({"pos": game.cell_center(game.current_core + offset), "amount": 1, "magnetized": false})
	await shot("scrap_glow")
	var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(game.current_core + Vector2i(6, 2)), "red")
	game.enemies.append(enemy)
	game.hover_cell = Vector2i((enemy.pos / game.TILE).floor())
	key_alt(true)
	game.hud._refresh_tooltip(game.get_canvas_transform() * enemy.pos)
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/inspection_enemy_range.png")
	key_alt(false)
	game.enemies.clear()
	while not game.scraps.is_empty(): game.collect_scrap(0.1, game.scraps[0].pos)
	game.add_resource("copper", 20)
	game.hud.show_tech_tree()
	game.hud.tech_buttons.barriers.button.pressed.emit()
	await shot("tech_known_materials")
	game.hud.close_modal()
	await process_frame
	await shot("alt_reminder")
	key_alt(true)
	await shot("shortcut_list")
	key_alt(false)
	game.tutorial.update_info_hover(2, true, "demo")
	await shot("unpause")
	game.toggle_pause()
	await shot("finished")
	for entry in game.saves.entries:
		DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
		if FileAccess.file_exists(game.saves.preview_path(entry.file)): DirAccess.remove_absolute(game.saves.preview_path(entry.file))
	print("INSPECTION CAPTURES COMPLETE")
	quit()
