extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hud.refresh()
	game.hud._process(0)
	game.queue_redraw()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/chrono_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.add_resource("copper", 40)
	game.place_building(Vector2i(31, 22), "solar", 0)
	game.tutorial.tech_available = true
	game.research("weapons", true)
	game.research("turret_red", true)
	game._add_building(Vector2i(27, 21), "turret", 0)
	game.buildings[Vector2i(27, 21)].ammo = 0
	game.buildings[Vector2i(27, 21)].hp = 100
	game.buildings[Vector2i(27, 21)].paid_cost = {"copper": 35, "iron": 12}
	game.paused = true
	game.active_tool = "abolish"
	game.hover_cell = Vector2i(27, 21)
	game.hud.refresh()
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(Vector2(700, 400))
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	print("INFO HEIGHT: ", game.hud.tooltip_body.size.y, " content=", game.hud.tooltip_body.get_content_height(), " lines=", game.hud.tooltip_body.get_line_count())
	root.get_texture().get_image().save_png("res://tests/chrono_info.png")
	alt.pressed = false
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud.tooltip.hide()
	game.remove_building(Vector2i(27, 21))
	game.update_demolition_effects(0.1)
	await shot("demolition")
	game.cancel_build_selection()
	for number in 5:
		game.wave = number + 1
		game.saves.capture()
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(game.saves.preview_path(game.saves.entries[0].file))
	game.hud.save_browser.show_browser()
	await shot("saves")
	game.hud.save_browser.timeline.value = 0
	await shot("oldest")
	game.hud.save_browser.confirm_restore(0)
	await shot("confirm")
	game.hud.close_modal()
	await process_frame
	game.hud.save_browser.show_browser(true)
	await shot("death")
	for entry in game.saves.entries:
		DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
		DirAccess.remove_absolute(game.saves.preview_path(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	print("CHRONO CAPTURES COMPLETE")
	quit()

