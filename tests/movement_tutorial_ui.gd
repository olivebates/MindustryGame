extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.camera.zoom == Vector2(2, 2) and game.raster_tile_size == 64, "New games start at two hundred percent with the matching sprites")
	check(game.inter_wave_delay == 300, "Waves are five minutes apart")
	var lines: Array[String] = game.tutorial.shortcut_lines()
	check(lines[0].begins_with("Left") and lines[1] == "Middle Drag - Copy Paste" and lines[2].begins_with("Right"), "Middle drag hint sits between left and right click")
	game.tutorial.ui_revealed.split = true
	check(not "\n".join(game.tutorial.shortcut_lines()).contains("1–9"), "Number hotkeys are omitted from the controls hint")
	game.tutorial.pause_exit_completed = false
	game.tutorial.skipped = false
	game.hud.refresh()
	check(not game.hud.save_browser.strip.visible, "Timeline stays hidden during pause tutorial")
	game.tutorial.pause_exit_completed = true
	game.hud.refresh()
	check(game.hud.save_browser.strip.visible, "Completing pause tutorial reveals timeline")
	game.tutorial.tech_available = true
	game.inventory.scrap = 0
	game.hud.refresh()
	check(not game.hud.tech_button.get_meta("tutorial_glow"), "Tech button does not glow without barrier resources")
	game.inventory.scrap = 3
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow"), "Affordable tutorial research lights tech button")
	game.researched.barriers = true
	game.wave = 4
	game.inventory.copper = game.material_capacity("copper")
	game.hud.refresh()
	check(not game.hud.tech_button.get_meta("tutorial_glow"), "Storage hint waits for all Solar range costs")
	game.inventory.scrap = 7
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow"), "Storage hint glows once Solar range is affordable")
	game.researched.turret_range = true
	game.inventory.copper = 9
	game.hud.refresh()
	check(not game.hud.tech_button.get_meta("tutorial_glow"), "Copper storage glow waits for enough copper")
	game.inventory.copper = 10
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow"), "Copper storage glows when all costs are available")
	fresh()
	var nav = game.enemy_navigation
	nav.invalidate(game)
	check(nav.grid.diagonal_mode == AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES and nav.runner_grid.diagonal_mode == nav.grid.diagonal_mode, "All enemies use safe diagonal routing")
	var origin := Vector2i(10, 10)
	var goal := Vector2i(12, 12)
	var path: Array[Vector2i] = nav.runner_grid.get_id_path(origin, goal)
	check(path.size() == 3 and path[1] == Vector2i(11, 11), "Open diagonals use a direct diagonal path")
	game.rocks[Vector2i(11, 10)] = true
	nav.invalidate(game)
	path = nav.runner_grid.get_id_path(origin, goal)
	check(path.size() > 3 and path[1] != Vector2i(11, 11), "A blocked cardinal side prevents corner cutting")
	var first: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(20, 20)), "red")
	var second: Dictionary = game.create_enemy("scout", first.pos, "red")
	first.windup = 0
	second.windup = 0
	first.cooldown = 999
	second.cooldown = 999
	var intended: Vector2 = game.cell_center(Vector2i(23, 23))
	first.intended_pos = intended
	first.navigation = {"target": game.current_core, "waypoint": game.cell_center(Vector2i(21, 21)), "destination": intended, "cost": 4.0}
	game.enemies.assign([first, second])
	game.enemy_separation.begin(game)
	var detour = game.enemy_separation.waypoint(game, first)
	var other_detour = game.enemy_separation.waypoint(game, second)
	check(detour == null and other_detour != null and not first.has("separation_goal"), "Only the newer overlapping tank steps aside")
	check(first.intended_pos == intended and first.navigation.destination == intended, "A separation detour preserves the original destination")
	for i in 400: game._update_enemies(0.05)
	check(first.pos != game.cell_center(Vector2i(20, 20)) and second.pos != game.cell_center(Vector2i(20, 20)), "Both tanks continue toward their goals after the optional sidestep")
	check(not first.has("separation_goal") and not second.has("separation_goal") and first.navigation.target == game.current_core, "Separated tanks resume their original building objective")
	fresh()
	game.saves.directory = "res://.godot/second_core_slugger_hint"
	game.saves.entries.clear()
	game.saves.current = -1
	var captured: Vector2i = game.current_core + Vector2i(20, 0)
	game._add_building(captured, "core", 0)
	game.cores.append(captured)
	game.current_core = captured
	game.researched = {"barriers": true, "turret_range": true, "copper_storage": true}
	game.tutorial.tech_available = true
	game.inventory.scrap = 70
	game.inventory.iron = 5
	game.saves.capture()
	game.inventory.scrap = 0
	game.saves.restore(0)
	check(game.tutorial.slugger_rewind_hint_active() and game.hud.tech_button.get_meta("tutorial_glow"), "Rewinding on the second core highlights affordable Slugger research")
	game.hud.show_tech_tree()
	check(game.hud.tech_buttons.weapons.button.get_meta("tutorial_glow"), "Slugger tech card glows after that rewind")
	game.inventory.iron = 4
	game.hud.refresh()
	check(not game.tutorial.slugger_rewind_hint_active() and not game.hud.tech_buttons.weapons.button.get_meta("tutorial_glow"), "Slugger rewind hint waits for every required material")
	game.hud.close_modal()
	fresh()
	var gate = game.active_spawners[0]
	gate.waves_completed = gate.waves_before_conversion - 1
	game.pending_waves[1] = [game.spawners.find(gate)]
	game.hud.refresh()
	check(game.hud.next_wave_label.text == "Next Wave: Last", "Spawn's final scheduled round displays Last")
	print("MOVEMENT AND TUTORIAL UI CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)



