extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.fog_disabled = false
	game.capture_effect.set_process(false)
	var gate = game.active_spawners[0]
	gate.position = game.cell_center(game.current_core + Vector2i(28, 0))
	gate.waves_completed = 0
	gate.waves_before_conversion = 1
	game.wave = 8
	game.wave_in_progress = true
	game._reveal_map()
	var previous: Dictionary = game.visible_cells.duplicate()
	var camera_start: Vector2 = game.camera.position
	game._complete_wave()
	# A manual snapshot here tests cinematic-safe restoration; automatic saves now wait for launch.
	game.saves.capture()
	var effect = game.capture_effect
	check(effect.active and effect.banner.visible and effect.banner.text == "Core secured", "Core conversion starts the capture banner and pulse")
	check(game.paused and game.wave_timer == 360, "Capture preserves paused six-minute preparation")
	check(game.saves.load_snapshot(game.saves.current)[6] == effect.camera_target(), "Capture checkpoint focuses new core without replaying cinematic")
	check(game.saves.load_snapshot(game.saves.current)[7] == Vector2.ONE, "Capture checkpoint records the final 100 percent zoom")
	check(effect.origin == game.cell_center(game.current_core) and effect.old_visibility == previous, "Capture records new core and prior revealed terrain")
	var newly_revealed: Vector2i = game.INVALID
	for cell in game.visible_cells:
		if not previous.has(cell) and game.cell_center(cell).distance_to(effect.origin) > game.TILE * 5:
			newly_revealed = cell
			break
	check(newly_revealed != game.INVALID and not game.is_cell_visible(newly_revealed), "New terrain begins hidden behind the capture sweep")
	effect.advance(0.8)
	check(effect.reveal_radius == 0 and game.camera.position == camera_start and effect.banner.visible, "Pulse and banner precede terrain reveal and camera movement")
	effect.advance(0.8)
	check(not effect.banner.visible and effect.pan_started and game.camera.position == camera_start, "Camera pan starts only after banner disappears")
	effect.advance(0.7)
	var halfway: Vector2 = game.camera.position
	check(halfway.distance_to(camera_start) > 0 and halfway.distance_to(effect.camera_target()) > 1, "Camera eases through an intermediate position")
	effect.advance(0.7)
	check(game.camera.position.distance_to(effect.pan_points[1]) < 1, "Camera reaches the first active gate before the core")
	check(effect.pan_points.size() == 2 and game.camera.zoom == Vector2.ONE, "Capture pans directly to the core at 100 percent zoom")
	effect.advance(effect.tour_duration() - effect.PAN_DURATION)
	check(game.camera.position.distance_to(effect.camera_target()) < 1, "Tour finishes centered on captured core")
	effect.advance(1.7)
	check(not effect.active and game.is_cell_visible(newly_revealed) and game.paused, "Reveal completes without unpausing simulation")
	check(game.audio.streams.has("core_capture") and game.audio.streams.core_capture.get_length() > 2, "Capture has its own generated deep chime")
	effect.begin(game.current_core)
	effect.advance(1.7)
	effect.cancel_pan()
	var manual_position: Vector2 = game.camera.position + Vector2(48, 0)
	game.camera.position = manual_position
	effect.advance(1)
	check(game.camera.position == manual_position, "Manual pan can override automatic focus")
	check(game.saves.restore(game.saves.current) and not effect.active and not effect.banner.visible and game.paused, "Rollback cancels transient capture presentation")
	print("CORE CAPTURE PRESENTATION CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)



