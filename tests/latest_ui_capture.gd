extends "res://tests/iron_supply_zoom.gd"
func snapshot(name: String) -> void:
	game.queue_redraw()
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s.png" % name)
func run() -> void:
	fresh()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	game._add_building(Vector2i(20, 25), "refinery", 0)
	game._add_building(Vector2i(26, 25), "iron_store", 0)
	game._add_building(Vector2i(29, 25), "turret", 0)
	game._add_building(Vector2i(19, 28), "drill", 0)
	game.hud.refresh()
	await snapshot("latest_building_status")
	var tower: Dictionary = game.buildings[Vector2i(29, 25)]
	tower.booster_type = "pink"
	tower.booster_count = 4
	game.hover_cell = Vector2i(29, 25)
	game.hud.show_structure_info("turret", tower, Vector2(1300, 1050))
	await snapshot("latest_boost_popup")
	var gate = game.active_spawners[0]
	for other in game.spawners: other.converted = other != gate
	game.active_spawners.assign([gate])
	gate.waves_before_conversion = 16
	gate.waves_completed = 0
	gate.allowed_enemies = PackedStringArray(["scout", "heavy", "bulwark", "siege"])
	gate.wave_enemy_lists.clear()
	gate.possible_colors = PackedStringArray(["blue"])
	gate.wave_color_palettes.clear()
	gate.credits_per_wave = PackedInt32Array(range(250, 266))
	game.wave = 4
	game.pending_waves.clear()
	var index: int = game.spawners.find(gate)
	var forecast: Dictionary = game.next_wave_forecast([index])
	game.hud.show_info(game.spawn_wave_title(gate), "", Vector2(1200, 700))
	var preview = preload("res://scripts/spawn_preview.gd").new()
	preview.hud = game.hud
	game.hud.info_root.add_child(preview)
	preview.show_forecast(forecast.by_spawn[index].counts, Vector2(1200, 700), 5, forecast.by_spawn[index].colored, index)
	await snapshot("latest_spawn_forecast")
	preview.hide_preview()
	game.hud.tooltip.hide()
	game.capture_effect.set_process(false)
	game.capture_effect.begin(game.current_core + Vector2i(20, 0))
	game.capture_effect.advance(2)
	await snapshot("latest_core_banner")
	print("LATEST UI CAPTURES FINISHED")
	game.free()
	quit()
