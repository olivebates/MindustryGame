extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hud.refresh()
	game.hud._process(0)
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/alt_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio.muted = true
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	await shot("initial")
	game.add_resource("copper", 7)
	game.hud.toggle_category("Structures")
	game.hud.cards.drill.pressed.emit()
	game.place_building(Vector2i(20, 22), "drill", 0)
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	await shot("waiting")
	game.add_resource("copper", 10)
	game.select_building("solar")
	game.place_building(Vector2i(31, 22), "solar", 0)
	game._damage_building(Vector2i(31, 22), 3)
	game.select_tool("abolish")
	game.hover_cell = Vector2i(31, 22)
	await shot("demolish")
	game.toggle_pause()
	await shot("paused_demolish")
	game.cancel_build_selection()
	await shot("paused")
	game.hud.toggle_category("Structures")
	game.hud.refresh()
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.hud.cards.solar.get_global_rect().get_center())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/alt_menu_info.png")
	game.hud.category = ""
	game.hud.hide_tray()
	game.hover_cell = Vector2i(31, 22)
	game.hud._refresh_tooltip(Vector2(700, 400))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/alt_placed_info.png")
	print("ALT CAPTURES COMPLETE")
	quit()
