extends "res://tests/iron_supply_zoom.gd"
func number_key(slot: int, shift: bool, ctrl: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_1 + slot - 1
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	return event
func run() -> void:
	fresh()
	game.saves.entries.clear()
	game.saves.current = -1
	game.saves.pending_branch = false
	check(game.BUILDINGS.solar.hp == 40 and game.BUILDINGS.wall.hp == 40, "Requested building health")
	game._add_building(Vector2i(24, 25), "solar", 0)
	game._add_building(Vector2i(23, 25), "wall", 0)
	check(game.buildings[Vector2i(24, 25)].hp == 40 and game.buildings[Vector2i(23, 25)].hp == 40, "New structures use updated health")
	game.saves.capture()
	var history_size: int = game.saves.entries.size()
	for slot in range(1, 10):
		game.inventory.copper = slot * 10
		game.wave_timer = slot * 3.0
		game.wave_in_progress = true
		game.enemies.assign([game.create_enemy("scout", Vector2(400 + slot, 400), "red")])
		check(game.handle_savestate_shortcut(number_key(slot, true, false)), "Shift-number saves slot")
	check(game.saves.entries.size() == history_size, "Quick saves do not pollute wave history")
	for slot in range(1, 10):
		check(game.handle_savestate_shortcut(number_key(slot, false, true)), "Control-number loads slot")
		check(game.inventory.copper == slot * 10 and game.wave_timer == slot * 3 and game.enemies.size() == 1 and game.enemies[0].pos.x == 400 + slot and game.wave_in_progress and game.paused, "Slot restores mid-wave resources, timer and enemies, paused")
	game.inventory.copper = 777
	check(game.saves.save_slot(1), "An existing slot can be overwritten")
	game.inventory.copper = 1
	check(game.saves.load_slot(1) and game.inventory.copper == 777, "Overwritten slot loads its latest snapshot")
	var directory: String = game.saves.directory
	var reader = preload("res://scripts/wave_saves.gd").new(game)
	reader.directory = directory
	reader.read_index()
	game.inventory.copper = 2
	check(reader.load_slot(9) and game.inventory.copper == 90, "Slots persist across save-manager instances")
	check(not game.handle_savestate_shortcut(number_key(1, false, false)), "Plain digits remain available to building hotkeys")
	var repeat := number_key(1, true, false)
	repeat.echo = true
	check(not game.handle_savestate_shortcut(repeat), "Held shortcut does not repeatedly save")
	var before: int = game.inventory.copper
	reader.directory += "_missing"
	check(not reader.load_slot(1) and game.inventory.copper == before, "Missing slots do not change the game")
	# Use a shared root to exercise the production behavior without player files.
	game.saves.quick_slots_directory = directory.path_join("shared_slots")
	game.inventory.copper = 321
	check(game.saves.save_slot(2), "Global slot is written separately from its expedition")
	game.saves.directory = directory + "_new_expedition"
	game.saves.entries.clear()
	game.saves.current = -1
	game.inventory.copper = 0
	check(game.saves.load_slot(2) and game.inventory.copper == 321 and game.saves.directory == directory, "Global slot loads after starting a different expedition and reconnects its original history")
	check(game.saves.entries.size() == history_size, "Global slot restores its original wave checkpoint list")
	print("QUICK SLOT CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
