extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hud.refresh()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/update_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.add_resource("copper", 200)
	game.place_building(Vector2i(31, 22), "solar", 0)
	await shot("start")
	game.launch_wave()
	game.enemies.clear()
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	for number in 9:
		game.wave = number + 1
		game._complete_wave()
		if is_instance_valid(game.hud.modal):
			game.hud.close_modal()
			await process_frame
	await shot("toolbar")
	game.hud.save_browser.show_browser()
	await shot("saves")
	game.hud.save_browser.timeline.value = 8
	await shot("timeline")
	game.hud.save_browser.confirm_restore(2)
	await shot("confirmation")
	game.hud.close_modal()
	await process_frame
	game.research("barriers", true)
	game.research("solar_green", true)
	game.radial_kind = "solar"
	game.hud.show_affinity_picker(Vector2(650, 420))
	await shot("radial")
	game.hud.dismiss_picker()
	await process_frame
	game.hud.set_process(false)
	game.hud.refresh()
	game.hud._refresh_tooltip(game.hud.tool_buttons.clear.get_global_rect().get_center())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/update_tooltip.png")
	for entry in game.saves.entries: DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	print("UPDATE CAPTURES COMPLETE")
	quit()
