extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.wave = 1
	game.saves.capture()
	game.research("barriers", true)
	game.wave = 2
	game.saves.capture()
	var core: Vector2i = game.current_core + Vector2i(10, 0)
	game._add_building(core, "core", 0)
	game.cores.append(core)
	game.current_core = core
	game.wave = 3
	game.saves.capture()
	game.research("conveyor_speed", true)
	game.wave = 4
	game.saves.capture()
	game.hud.refresh()
	game.hud.save_browser.show_browser()
	await shot("res://tests/rewind_markers.png")
	game.hud.close_modal()
	await process_frame
	var enemy: Dictionary = game.create_enemy("runner", game.cell_center(core + Vector2i(-3, 0)), "red")
	enemy.velocity = Vector2(80, 0)
	game.enemies.append(enemy)
	game.queue_redraw()
	await shot("res://tests/before_rewind.png")
	game.saves.restore(0)
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rewind_effect.png")
	quit()
