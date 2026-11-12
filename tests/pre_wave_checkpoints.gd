extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.saves.entries.clear()
	game.saves.current = -1
	game.saves.pending_branch = false
	game.tutorial.skipped = true
	game.paused = false
	game.wave = 0
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.enemies.clear()
	game.pending_waves.clear()
	game.wave_in_progress = false
	game.wave_timer = 0
	for gate in game.active_spawners:
		gate.waves_before_conversion = 99
		gate.waves_completed = 0
	game.inventory.copper = 17
	game.launch_wave()
	check(game.saves.entries.is_empty(), "Calling a wave no longer creates a checkpoint")
	check(game.wave == 1 and game.spawn_remaining > 0, "New wave launches without a checkpoint")
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.wave_timer = 90
	game.inventory.copper = 23
	game._complete_wave(1)
	check(game.saves.entries.size() == 1 and game.saves.entries[0].wave == 1, "Completing the wave creates its labeled checkpoint")
	var data: Array = game.saves.load_snapshot(0)
	check(data[1][3] == 1 and data[1][23].is_empty() and data[1][24] == 0 and data[1][0].copper == 23, "Checkpoint captures post-wave resources and spawning state")
	check(game.saves.restore(0) and game.paused and game.wave == 1 and game.inventory.copper == 23, "Loading restores the post-wave checkpoint and pauses")
	game.toggle_pause()
	game.simulate(0.1)
	check(game.wave == 1 and game.wave_timer > 89, "Unpausing continues the saved inter-wave timer")
	var cell := Vector2i(26, 25)
	game._add_building(cell, "turret", 0)
	check(game.buildings[cell].ammo == 8 and game.turret_ammo_capacity("turret") == 8, "Sluggers spawn with eight rounds")
	check(not game.can_receive(cell, "iron"), "Full Slugger rejects more ammunition")
	game.buildings[cell].ammo = 7
	check(game.can_receive(cell, "iron"), "Slugger accepts an eighth round")
	check(preload("res://scripts/structure_info.gd").stats(game, "turret", game.buildings[cell]).contains("7 / 8"), "Tooltip shows the eight-round cap")
	game.enemies.assign([game.create_enemy("scout", game.cell_center(Vector2i(20, 25)), "red")])
	game._add_building(Vector2i(24, 25), "belt", 0)
	check(not game.buildings[Vector2i(24, 25)].pending, "Combat conveyors are immediately active")
	game.buildings[cell].ammo = 80
	game.saves.capture()
	check(game.saves.restore(game.saves.current) and game.buildings[cell].ammo == 8, "Loading older high-ammo Sluggers clamps them to eight rounds")
	print("POST-WAVE CHECKPOINT CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
