extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.set_camera_zoom(2.0)
	var core: Vector2i = game.current_core
	game._add_building(core + Vector2i(-2, 2), "solar", 0)
	game._add_building(core + Vector2i(2, 2), "turret", 0)
	game.camera.position = game.cell_center(core + Vector2i(1, 1))
	game.camera.force_update_scroll()
	game.saves.directory = "res://.godot/timeline_capture"
	game.saves.entries.clear()
	for number in 4:
		game.wave = number + 1
		game.saves.capture()
	await shot("timeline_art")
	game.hud.save_browser.begin_scrub()
	game.hud.save_browser.preview_save(1)
	await shot("timeline_scrub")
	game.hud.save_browser.finish_scrub()
	game.hud.close_modal()
	game.lost = true
	await shot("timeline_death")
	game.free()
	quit()
