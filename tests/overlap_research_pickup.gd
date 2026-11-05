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
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	var prices: Dictionary = game.hud.tech_buttons.barriers.button.get_meta("cost_labels")
	check(prices.has("scrap") and not prices.has("copper") and game.discovered_resources.is_empty(), "Barrier research shows its scrap-only price without discovering materials")
	game.hud.close_modal()
	await process_frame
	var turret: Vector2i = game.current_core + Vector2i(8, 0)
	game._add_building(turret, "solar", 0)
	var route: Dictionary = game.enemy_navigation.route(game, game.cell_center(turret + Vector2i(4, 0)))
	check(route.target == turret, "Closest turret remains the objective despite its dangerous approach")
	game.begin_middle_blueprint(turret)
	game.finish_drag()
	check(game.selected == "solar" and game.active_tool == "build" and game.hud.category != "", "Middle click selects the placed structure and opens its menu")
	game.cancel_build_selection()
	game.remove_building(turret, false)
	game.research("barriers", true)
	game.research("conveyor_speed", true)
	game.research("turret_range", true)
	var visible: Array[String] = game.hud.visible_tech_ids()
	check(visible.has("copper_storage") and visible.has("auto_scrap") and visible.has("build_hotkeys") and not visible.has("industry") and not visible.has("solar_green"), "Only the current storage, pickup and hotkey branches follow the starter upgrades")
	check(game.TECH.auto_scrap.cost == {"copper": 10} and game.TECH.build_hotkeys.cost == {"copper": 10}, "New upgrades have the requested costs")
	game.hud.toggle_category("Infrastructure")
	game.hud.handle_number_hotkey(0)
	check(game.selected == "", "Building-number shortcuts remain locked before research")
	game.research("build_hotkeys", true)
	game.hud.handle_number_hotkey(0)
	check(game.selected == game.hud.cards.keys()[0], "Research enables building-number shortcuts")
	game.cancel_build_selection()
	game.research("auto_scrap", true)
	var origin: Vector2 = game.cell_center(game.current_core)
	game._drop_scrap(game.create_enemy("scout", origin, "red"))
	var pointer: Vector2 = origin + Vector2(160, 0)
	game.collect_scrap(1.9, pointer)
	check(game.scraps[0].pos.distance_to(origin) <= game.TILE * 2 and not game.scraps[0].magnetized, "Fresh scrap stays still during its two-second wait")
	game.collect_scrap(0.2, pointer)
	check(game.scraps[0].magnetized and game.scraps[0].pos != origin, "Auto pickup attracts aged scrap beyond normal hover range")
	for frame in 60: game.collect_scrap(0.02, pointer)
	check(game.inventory.scrap == 1 and game.scraps.is_empty(), "Automatic scrap arrival collects its resources")
	game.launch_wave()
	check(game.inter_wave_delay == 120 and game.wave_timer == 120, "Waves use a two-minute interval")
	while not game.spawn_queue.is_empty():
		game._spawn_enemy()
		game.spawn_remaining -= 1
	var survivors: int = game.enemies.size()
	var first_budget: int = game.last_wave_budget
	game.launch_wave()
	check(game.wave == 2 and game.enemies.size() == survivors and game.pending_waves.has(1) and game.pending_waves.has(2), "Next wave starts without removing surviving earlier enemies")
	check(game.last_wave_budget == game.active_spawners[0].budget(1), "Overlapping waves advance the authored credit schedule")
	while not game.spawn_queue.is_empty():
		game._spawn_enemy()
		game.spawn_remaining -= 1
	for enemy in game.enemies:
		if enemy.wave_id == 1: enemy.hp = 0
	game._update_enemies(0.01)
	game.simulate(0.01)
	check(game.saves.entries.size() == 1 and not game.pending_waves.has(1) and game.pending_waves.has(2), "Defeating one overlapping wave produces its checkpoint")
	var count: int = game.enemies.size()
	check(game.saves.restore(0) and game.paused and game.enemies.size() == count and game.enemies[0].wave_id == 2 and game.pending_waves.has(2), "Checkpoint restore preserves the remaining overlapping wave")
	print("OVERLAP RESEARCH PICKUP CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)


