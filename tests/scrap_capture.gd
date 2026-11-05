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
	root.get_texture().get_image().save_png("res://tests/scrap_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio.muted = true
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.add_resource("copper", 5)
	game.hud.toggle_category("Structures")
	game.hud.cards.drill.pressed.emit()
	game.place_building(Vector2i(20, 22), "drill", 0)
	await shot("mine_more")
	game.add_resource("copper", 2)
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.add_resource("copper", 10)
	game.select_building("solar")
	game.place_building(Vector2i(31, 22), "solar", 0)
	game.launch_wave()
	game._damage_building(Vector2i(31, 22), 1)
	game.toggle_pause()
	await shot("collect")
	game.select_tool("abolish")
	game.hover_cell = Vector2i(31, 22)
	await shot("glow_wrap")
	game.cancel_build_selection()
	var spot: Vector2 = game.cell_center(game.current_core + Vector2i(1, 2))
	game.scraps.append({"pos": spot, "amount": 27, "magnetized": false})
	game.collect_scrap(0.1, spot)
	game.hud.show_tech_tree()
	await shot("research")
	game.hud.tech_buttons.barriers.button.pressed.emit()
	game.hud.close_modal()
	await process_frame
	game.add_resource("copper", 20)
	game.hud.toggle_category("Defence")
	await shot("categories")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.hud.cards.solar.get_global_rect().get_center())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/scrap_turret_info.png")
	game.hud.category = ""
	game.hud.hide_tray()
	var enemy: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(34, 22)), "red")
	game.enemies.append(enemy)
	game.hover_cell = Vector2i(34, 22)
	game.hud._refresh_tooltip(game.get_canvas_transform() * enemy.pos)
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/scrap_enemy_info.png")
	print("SCRAP CAPTURES COMPLETE")
	quit()
