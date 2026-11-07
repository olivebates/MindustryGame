extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.saves.directory = "res://.godot/test_wave_grid_" + str(Time.get_ticks_usec())
	game.saves.entries.clear()
	game.saves.current = -1
	game.saves.pending_branch = false
	var preview := preload("res://scripts/save_preview.gd").new()
	preview.configure(game)
	var bounds: Rect2 = preview.capture_bounds(game)
	check(bounds.size == Vector2(172, 172) and bounds.get_center() == game.cell_center(game.current_core), "A lone core screenshot has exactly two tiles of margin")
	game._add_building(Vector2i(28, 25), "turret", 0)
	game._add_building(Vector2i(60, 25), "solar", 0)
	preview.configure(game)
	bounds = preview.capture_bounds(game)
	check(bounds.end.x == 1024 and bounds.position.x == 730, "Framing includes full 2x2 footprints, adds two tiles, and excludes distant buildings")
	game.remove_building(Vector2i(28, 25), false)
	game.remove_building(Vector2i(60, 25), false)
	preview.free()
	game.saves.entries.clear()
	game.saves.current = -1
	game.tutorial.turret_loss_glow = false
	game.tutorial.ui_revealed.erase("loss_saves_revealed")
	check(game.Content.ENEMY_TYPES.heavy.reach == 96, "Heavy range is three tiles")
	check(game.enemy_health("bulwark", 1) == 50 and game.enemy_health("bulwark", 20) == 50 and game.Content.ENEMY_TYPES.bulwark.speed == 64 and game.Content.ENEMY_TYPES.bulwark.reload == 3 and game.Content.ENEMY_TYPES.bulwark.damage == 12, "Bulwark has 50 HP, two-tile speed and 12 damage every three seconds")
	var bulwark: Dictionary = game.create_enemy("bulwark", game.cell_center(game.current_core) - Vector2(48, 0), "red")
	bulwark.windup = 0.0
	game.enemies.assign([bulwark])
	var core_hp: float = game.buildings[game.current_core].hp
	for step in 29: game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == core_hp and bulwark.get("charge", 0.0) > 0.9, "Bulwark visibly charges before its first hit")
	game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == core_hp - 12 and bulwark.charge == 0, "Bulwark fires at three seconds and resets its charge")
	game.enemies.clear()
	check(game.inter_wave_delay == 180 and game.initial_wave_delay == 180, "Three minutes between waves")
	check(game.manual_mining_interval("copper") == 1 and game.manual_mining_interval("iron") == 1, "All hand mining takes one second")
	check(is_equal_approx(game.conveyor_items_per_second(), 0.5), "Belts transport 0.5 items per second")
	check(game.BUILDINGS.solar.reload == 1.0 and game.BUILDINGS.turret.reload == 4, "Solar and slug intervals updated")
	check(game.enemy_health("scout", 1) == 5 and game.enemy_health("heavy", 1) == 20 and game.enemy_health("heavy", 20) == 20, "Small tanks have 5 HP and heavies 20 HP")
	check(game.Content.ENEMY_TYPES.heavy.reload == 2 and game.Content.ENEMY_TYPES.heavy.damage == 4 and game.Content.ENEMY_TYPES.heavy.damage / game.Content.ENEMY_TYPES.heavy.reload == 2.0, "Heavy deals four damage every two seconds for two DPS")
	check(game.hud.tech_stat_summary("time_speed") == "Press E for x3 speed", "Exact acceleration description")
	var drill := Vector2i(23, 25)
	game.ores[drill] = "iron"
	game._add_building(drill, "drill", 0)
	game.advance_logistics(4.95)
	check(game.buildings[drill].item == "", "Extractor waits five seconds")
	game.advance_logistics(0.05)
	check(game.buildings[drill].item == "iron", "Extractor produces 0.2 ore per second")
	game.research("barriers", true)
	var wall := Vector2i(24, 24)
	game._add_building(wall, "wall", 0)
	game.buildings[wall].hp *= 0.5
	game.inventory.iron = 35
	game.inventory.scrap = 20
	check(not game.research("iron_barriers"), "Iron barriers require Slugger research")
	game.research("weapons", true)
	check(game.research("iron_barriers") and game.inventory.iron == 0 and game.inventory.scrap == 0, "Iron barriers cost 35 iron and 20 scrap")
	check(game.buildings[wall].max_hp == 120.0 and game.buildings[wall].hp == 60.0, "Existing barrier triples HP and preserves damage percentage")
	game._add_building(Vector2i(24, 23), "wall", 0)
	check(game.buildings[Vector2i(24, 23)].hp == 120.0, "Future barriers have triple health")
	for wave in range(1, 6):
		game.wave = wave
		check(game.saves.capture(), "Checkpoint captured")
	game.cores.append(Vector2i(45, 25))
	game.current_core = Vector2i(45, 25)
	game._add_building(game.current_core, "core", 0)
	game.wave = 1
	game.saves.capture()
	game.hud.refresh()
	check(not game.hud.saves_button.visible, "Saved waves button stays hidden before defeating wave two")
	game.tutorial.on_wave_completed(1)
	game.hud.refresh()
	check(not game.hud.saves_button.visible, "Defeating wave one does not reveal saved waves")
	game.tutorial.on_wave_completed(2)
	game.hud.refresh()
	check(not game.hud.save_browser.strip.visible and game.hud.saves_button.visible, "Browser replaces the persistent timeline")
	check(game.hud.saves_button.position.x < game.hud.next_button.position.x and game.hud.saves_button.position.x > game.hud.back_button.position.x, "Save button sits between rewind and Start")
	game.hud.save_browser.show_browser()
	var scroll: ScrollContainer = game.hud.modal.get_child(0).get_child(1)
	var list: HBoxContainer = scroll.get_child(0)
	check(list.get_child_count() == 8 and list.get_child(0).get_child(0).text == "Core 01" and list.get_child(6).get_child(0).text == "Core 02", "Chronological row separates core groups vertically")
	check(list.get_child(1).get_meta("save_index") == 0 and list.get_child(7).get_meta("save_index") == 5, "Every checkpoint appears oldest to newest")
	await process_frame
	await process_frame
	check(scroll.scroll_horizontal > 0 and scroll.slider.value == 1, "Browser opens scrolled to the newest save")
	scroll.slider.value = 0
	check(scroll.scroll_horizontal == 0, "Timeline slider reaches the oldest saves")
	scroll.slider.value = 1
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 100)
	scroll._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(320, 100)
	var before: int = scroll.scroll_horizontal
	scroll._gui_input(motion)
	check(scroll.scroll_horizontal < before, "Dragging the row scrolls to older saves")
	press.pressed = false
	scroll._gui_input(press)
	check(game.paused, "Browser pauses the game")
	list.get_child(5).pressed.emit()
	check(game.hud.modal.get_child(0).get_child(1).text.contains("wave 5?"), "Selecting a card confirms its corresponding wave")
	game.hud.close_modal()
	game.saves.mark_played(0)
	check(absi(game.saves.last_played(0) - int(Time.get_unix_time_from_system())) <= 1, "Last played timestamp persists separately from checkpoint")
	game.saves.restore(0)
	check(game.hud.saves_button.visible, "Rewinding preserves the revealed saved-waves button")
	check(not game.researched.has("iron_barriers") or game.buildings[wall].max_hp == 120.0, "Barrier upgrade state restores consistently")
	game.lost = true
	game.hud.save_browser.show_browser()
	check(game.hud.modal.get_child(0).get_child_count() == 3, "Dead save browser has no Cancel button")
	print("WAVE GRID AND BALANCE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
