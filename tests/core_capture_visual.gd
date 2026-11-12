extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.capture_effect.set_process(false)
	game.fog_disabled = false
	game.camera.position = game.cell_center(game.current_core)
	var gate = game.active_spawners[0]
	gate.position = game.cell_center(game.current_core + Vector2i(28, 0))
	gate.waves_completed = 0
	gate.waves_before_conversion = 1
	game.wave = 8
	game.wave_in_progress = true
	game._reveal_map()
	game._complete_wave()
	game.advance_final_wave_completion(1.0)
	game.capture_effect.advance(0.5)
	await shot("capture_banner")
	game.capture_effect.advance(1.8)
	await shot("capture_pan")
	game.capture_effect.advance(2.4)
	await shot("capture_finished")
	game.free()
	quit()

