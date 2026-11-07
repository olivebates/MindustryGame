extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.TECH.time_speed.parent == "barriers" and game.TECH.time_speed.cost == {"copper": 10}, "Time acceleration is a ten-copper Barrier child")
	game.speed = 1
	game.cycle_speed()
	game.hud.refresh()
	check(game.speed == 1 and not game.hud.speed_button.visible, "E and its button are locked before research")
	game.researched.barriers = true
	check(game.research("time_speed"), "Time acceleration can be purchased after Barriers")
	game.cycle_speed()
	game.hud.refresh()
	check(game.speed == 3 and game.hud.speed_button.visible, "Purchased speed toggles to three times")
	game.cycle_speed()
	check(game.speed == 1, "Speed toggles back to normal")
	check(game.conveyor_items_per_second() == 1.25 and game.manual_mining_interval("copper") == 0.2 and game.manual_mining_interval("iron") == 1, "Conveyor and manual mining rates are five times faster")
	check(game.BUILDINGS.solar.reload == 0.1 and is_equal_approx(game.BUILDINGS.turret.reload, 0.8) and game.Content.ENEMY_TYPES.heavy.reload == 0.2, "Player and enemy attack intervals are divided by five")
	check(game.Content.ENEMY_TYPES.scout.speed == 160 and game.Content.ENEMY_TYPES.heavy.speed == 72.5 and game.Content.ENEMY_TYPES.siege.speed == 60, "Enemy movement speeds are multiplied by five")
	check(game.BUILDINGS.wall.hp == 137.5, "Barrier health is divided by twenty")
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	check(game.hud.tech_buttons.has("time_speed") and game.hud.tech_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and game.hud.tech_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Tech tree shows acceleration and hides both scrollbars")
	game.hud.close_modal()
	fresh()
	game.inventory.copper = 0
	game.ores[Vector2i(23, 25)] = "copper"
	game._add_building(Vector2i(23, 25), "drill", 0)
	game.advance_logistics(1.95)
	check(game.buildings[Vector2i(23, 25)].item == "", "Extractor waits two seconds")
	game.advance_logistics(0.05)
	check(game.buildings[Vector2i(23, 25)].item == "copper", "Extractor produces after two seconds")
	game._add_building(Vector2i(24, 25), "belt", 0)
	game.buildings[Vector2i(24, 25)].item = "copper"
	game.advance_logistics(0.8)
	check(game.inventory.copper >= 1, "A conveyor delivers an item within eight tenths of a second")
	fresh()
	var next: Vector2i = game.current_core + Vector2i(10, 0)
	game._add_building(next, "core", 0)
	game.cores.append(next)
	game.current_core = next
	game.camera.position = game.cell_center(next)
	game.camera.force_update_scroll()
	game.tutorial.on_new_core(next)
	check(game.tutorial.next_core_message().split("\n")[2] == "Use WASD to move the camera around", "Second core has the third camera tutorial line")
	game.tutorial.record_wasd_movement(96)
	check(game.tutorial.next_core_message().contains("Use WASD"), "Exactly three tiles keeps camera hint")
	game.tutorial.record_wasd_movement(0.1)
	check(not game.tutorial.next_core_message().contains("Use WASD"), "More than three tiles of WASD movement dismisses hint")
	fresh()
	game.tutorial.pause_exit_completed = false
	var cell: Vector2i = game.current_core + Vector2i.RIGHT
	game._add_building(cell, "drill", 0)
	game._damage_building(cell, 1000)
	game.hud.refresh()
	game.hud._process(0)
	check(game.tutorial.rewind_hint_active() and game.hud.tutorial_prompt.text.contains("arrow button or timeline") and game.hud.back_button.get_meta("tutorial_glow"), "First extractor loss introduces rewind and lights arrow")
	check(not game.saves.entries.is_empty() and game.hud.save_browser.strip.visible, "Extractor loss offers a usable initial checkpoint and timeline")
	game.hud.save_browser.begin_scrub()
	game.hud.save_browser.finish_scrub()
	game.hud.refresh()
	check(not game.tutorial.rewind_hint_active(), "Using timeline dismisses loss hint without requiring confirmation")
	game.lost = true
	game.hud.refresh()
	check(game.hud.tutorial_prompt.text == "Use the arrow button or timeline to roll back time.", "Death still shows rewind instructions")
	fresh()
	game._add_building(Vector2i(28, 25), "turret", 0)
	game.tutorial.ammo_tutorial_target = Vector2i(28, 25)
	game.tutorial.ammo_tutorial_stage = 1
	check(game.tutorial.central_message().contains("Build conveyor from extractor to turret."), "Slugger tutorial explicitly asks for a conveyor connection")
	check(game.inter_wave_delay == 120 and game.initial_wave_delay == 120, "Normal wave timers are two minutes")
	game.active_spawners[0].waves_before_conversion = 1
	game.active_spawners[0].waves_completed = 0
	game.wave_in_progress = true
	game._complete_wave()
	check(game.wave_timer == 240 and game.paused, "New cores have four minutes of paused preparation")
	fresh()
	game._add_building(Vector2i(23, 25), "drill", 0)
	game._add_building(Vector2i(24, 25), "wall", 0)
	var legacy: Array = game.saves.snapshot().duplicate(true)
	legacy[0] = 10
	legacy[1][game.saves.FIELDS.find("wave_timer")] = 600.0
	legacy[1][game.saves.FIELDS.find("speed")] = 5
	for row in legacy[2]:
		if row[1] == "drill": row[game.saves.BUILD_FIELDS.find("progress") + 1] = 5.0
		if row[1] == "wall":
			row[game.saves.BUILD_FIELDS.find("hp") + 1] = 1375.0
			row[game.saves.BUILD_FIELDS.find("max_hp") + 1] = 2750.0
	game.saves.migrate_fast_balance(legacy)
	check(legacy[0] == game.saves.VERSION and legacy[1][game.saves.FIELDS.find("wave_timer")] == 240 and legacy[1][game.saves.FIELDS.find("speed")] == 1, "Older saves migrate timer and locked speed setting")
	var migrated := true
	for row in legacy[2]:
		if row[1] == "drill": migrated = migrated and row[game.saves.BUILD_FIELDS.find("progress") + 1] == 1
		if row[1] == "wall": migrated = migrated and row[game.saves.BUILD_FIELDS.find("hp") + 1] == 68.75 and row[game.saves.BUILD_FIELDS.find("max_hp") + 1] == 137.5
	check(migrated, "Older extractor progress and damaged barriers migrate proportionally")
	fresh()
	var solar := Vector2i(27, 25)
	game._add_building(solar, "solar", 0)
	game.buildings[solar].cooldown = -500
	var enemy: Dictionary = game.create_enemy("heavy", game.building_center(solar) + Vector2(40, 0), "red")
	enemy.hp = 1000
	enemy.max_hp = 1000
	game.enemies.append(enemy)
	game._update_turret(solar, game.buildings[solar], 0.05)
	check(enemy.hp == 998 and game.shots.size() == 1, "Idle turrets do not accumulate instant bursts when a target appears")
	print("EXPEDITION REBALANCE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)




