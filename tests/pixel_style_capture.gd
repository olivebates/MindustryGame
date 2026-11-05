extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	var gate = game.active_spawners[0]
	gate.position = game.cell_center(game.current_core + Vector2i(15, 0))
	gate.waves_before_conversion = 2
	gate.waves_completed = 0
	var index: int = game.spawners.find(gate)
	game.wave = 2
	game.pending_waves = {1: [index], 2: [index]}
	game.wave_in_progress = true
	var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(game.current_core + Vector2i(8, 0)), "blue")
	enemy.wave_id = 1
	game.enemies.append(enemy)
	game._complete_wave(2)
	await shot("last_round_pixel")
	game.enemies.clear()
	game.simulate(0.01)
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	await shot("new_core_auto_pause")
	quit()
