extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.rocks.clear()
	var turret: Vector2i = game.current_core + Vector2i(8, 0)
	game._add_building(turret, "solar", 0)
	var position: Vector2 = game.cell_center(turret + Vector2i(1, 0))
	check(game.enemy_navigation.route(game, position).target == turret and game.enemy_navigation.route(game, position, true).target == game.current_core, "Runners bypass a nearby turret while other enemies target it")
	var runner: Dictionary = game.create_enemy("runner", position, "red")
	runner.hp = 100.0
	runner.windup = 0.0
	runner.cooldown = 0.0
	game.enemies.append(runner)
	game._update_enemies(0.1)
	check(game.buildings[turret].hp == game.buildings[turret].max_hp and runner.navigation.target == game.current_core, "Runner does not fire at a turret in range")
	game.enemies.clear()
	game.remove_building(turret, false)
	var gate = game.active_spawners[0]
	gate.allowed_enemies = PackedStringArray(["scout", "runner"])
	gate.wave_enemy_lists.assign([PackedStringArray(["heavy"]), PackedStringArray()])
	gate.credits_per_wave = PackedInt32Array([8, 3, 4])
	check(gate.enemies_for_wave() == PackedStringArray(["heavy"]), "First per-wave list overrides the default enemy roster")
	check(gate.enemies_for_wave(1) == gate.allowed_enemies and gate.enemies_for_wave(2) == gate.allowed_enemies, "Empty and missing wave lists both use the spawn's default roster")
	game.wave = 1
	game._prepare_colors(1)
	game._plan_wave()
	check(game.spawn_queue.size() == 1 and game.spawn_queue[0].kind == "heavy", "Explicit wave roster permits an authored early heavy wave")
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	var point: Vector2 = game.cell_center(game.current_core)
	game._drop_scrap(game.create_enemy("scout", point, "red"))
	game.collect_scrap(0.01, point)
	check(game.inventory.scrap == 1 and game.scraps.is_empty(), "Normal hover pickup collects fresh scrap without Auto Pickup")
	game.research("auto_scrap", true)
	game._drop_scrap(game.create_enemy("scout", point, "red"))
	game.collect_scrap(0.01, point)
	check(game.inventory.scrap == 2 and game.scraps.is_empty(), "Normal hover pickup remains immediate after Auto Pickup research")
	game._drop_scrap(game.create_enemy("scout", point, "red"))
	game.collect_scrap(1.9, point + Vector2(200, 0))
	check(not game.scraps[0].magnetized, "Automatic attraction still waits two seconds outside hover range")
	game.scraps.clear()
	game.researched.erase("auto_scrap")
	game.wave = 1
	game.saves.capture()
	game.research("barriers", true)
	game.wave = 2
	game.saves.capture()
	var captured: Vector2i = game.current_core + Vector2i(10, 0)
	game._add_building(captured, "core", 0)
	game.cores.append(captured)
	game.current_core = captured
	game.wave = 3
	game.saves.capture()
	var events: Array[Dictionary] = game.saves.timeline_events()
	check(events[0].research.is_empty() and events[1].research == ["Barriers"] and events[2].cores == 1, "Timeline detects research unlock and core-capture checkpoints without repeating them")
	game.hud.save_browser.show_browser()
	var markers: Array[Button] = game.hud.save_browser.milestone_markers
	check(markers.size() == 2 and markers[0].get_meta("save_index") == 1 and markers[1].get_meta("save_index") == 2, "Milestone icons are attached to the matching timeline checkpoints")
	markers[0].pressed.emit()
	check(game.hud.save_browser.selected == 1, "Clicking a milestone selects and scrolls to its checkpoint")
	game.hud.close_modal()
	await process_frame
	check(game.saves.restore(0) and game.paused and is_instance_valid(game.hud.rewind_effect), "Loading triggers the reverse effect while keeping gameplay paused")
	check(game.audio.streams.has("rewind") and game.audio.streams.rewind.get_length() > 0.4, "Generated descending rewind sound is available")
	await create_timer(0.6).timeout
	check(not is_instance_valid(game.hud.rewind_effect) and game.paused, "The brief rewind effect finishes without resuming simulation")
	print("RUNNER REWIND MILESTONE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

