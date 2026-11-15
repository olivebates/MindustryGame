extends "res://tests/iron_supply_zoom.gd"
const State = preload("res://scripts/save_state.gd")
func payload(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	file.get_buffer(4)
	var compression := file.get_8()
	var size := file.get_32()
	file.get_buffer(4)
	return bytes_to_var(file.get_buffer(file.get_length() - file.get_position()).decompress(size, compression))
func legacy_file(path: String, data: Array) -> void:
	var raw := var_to_bytes(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("EWS1".to_ascii_buffer())
	file.store_8(FileAccess.COMPRESSION_DEFLATE)
	file.store_32(raw.size())
	file.store_buffer(game.saves.checksum(raw))
	file.store_buffer(raw.compress(FileAccess.COMPRESSION_DEFLATE))
func run() -> void:
	fresh()
	game.inventory.erase("scrap")
	game.inventory.verdite = 100
	game.tutorial_enabled = false
	game.research("barriers", true)
	game.research("emergency_injector", true)
	game.research("isotope_lance", true)
	var belt_cell := Vector2i(28, 25)
	game._add_building(belt_cell, "belt", 1)
	check(game.buildings[belt_cell].dir == 1, "Creates a directed belt for save restoration")
	var tower_cell := Vector2i(32, 25)
	game._add_building(tower_cell, "isotope_lance", 0)
	var tower: Dictionary = game.buildings[tower_cell]
	tower.hp = 123.0
	tower.buffer.verdite = 4
	tower.buffer.coolant = 2
	tower.cooldown = 8.0
	tower.flash = 1.0
	tower.nuclear = {"heat":45.0, "shots":7, "fuel":12.5, "blackout":10.0, "zones":[{"pos":Vector2.ZERO,"life":6.0}], "charge":5.0}
	game.wave = 2
	game.wave_in_progress = true
	game.enemies.append(game.create_enemy("scout", game.cell_center(Vector2i(40, 25)), "green"))
	game.spawn_queue.assign([{"kind":"scout", "pos":Vector2.ZERO, "color":"red", "wave_id":2}])
	game.spawn_remaining = 1
	game.pending_waves[2] = [0]
	game.speed = 5
	game.elapsed = 999.0
	game.kills = 999
	game.delivered = 999
	game.wave_timer = 1.0
	game.rng.seed = 937
	game.tutorial.ui_revealed.test_secret = true
	game.debug_resource_capacity = true
	game.camera.position = Vector2(1700, 1900)
	game.set_camera_zoom(0.5)
	var resources: Dictionary = game.inventory.duplicate(true)
	var tech: Dictionary = game.researched.duplicate(true)
	var core: Vector2i = game.current_core
	check(game.saves.save_slot(1), "Writes compact save to a quick slot")
	var saved := payload(game.saves.slot_path(1))
	check(saved.size() == 5 and ["version","resources","buildings","tech","progress"].all(func(field): return saved.has(field)), "Disk payload contains only the four state categories and a format version")
	check(saved.progress.size() == 2 and saved.progress.core == core and saved.progress.wave == 2, "Only current core and wave-to-defend are stored as progress")
	check(saved.resources == resources and saved.tech == tech, "Resource amounts and researched technology are saved exactly")
	var record: Dictionary = saved.buildings.filter(func(b): return b.cell == tower_cell)[0]
	check(not record.has("cooldown") and not record.has("flash") and not record.has("max_hp") and not record.nuclear.has("zones") and not record.nuclear.has("charge") and not record.nuclear.has("blackout"), "Derived and combat presentation state is excluded from buildings")
	check(record.hp == 123 and record.nuclear.heat == 45 and record.buffer.coolant == 2, "Durable building health, heat and stored resources are retained")
	check(not FileAccess.file_exists(game.saves.directory.path_join("tutorial.learned")), "Saving writes no separate tutorial-state file")
	game.inventory.copper = 0
	game.researched.clear()
	game.buildings[tower_cell].hp = 1
	check(game.saves.load_slot(1), "Loads a compact save")
	check(game.inventory == resources and game.researched == tech and game.current_core == core, "Load restores only the saved resources, research and current core")
	check(game.buildings[tower_cell].hp == 123 and game.buildings[tower_cell].buffer.verdite == 4 and game.buildings[tower_cell].nuclear.shots == 7, "Load restores durable building contents and operating reserves")
	check(game.enemies.is_empty() and game.spawn_queue.is_empty() and game.spawn_remaining == 0 and game.pending_waves.is_empty(), "Load rebuilds combat without serializing individual enemies or queues")
	check(game.wave == 1 and game.active_spawners[0].waves_completed == 1 and not game.wave_in_progress, "An interrupted second wave is prepared again from its beginning")
	check(game.speed == 1 and game.elapsed == 0 and game.kills == 0 and game.delivered == 0 and game.wave_timer == 120, "Simulation speed, counters and preparation timer are rebuilt")
	check(not game.debug_resource_capacity and not game.tutorial.ui_revealed.has("test_secret"), "Debug flags and unrelated tutorial history do not leak across loading")
	check(game.camera.zoom == Vector2.ONE and game.camera.position == game.cell_center(core), "Camera and zoom are derived from the current core")
	check(game.buildings[tower_cell].cooldown == 0 and game.buildings[tower_cell].flash == 0 and not game.buildings[tower_cell].pending, "Firing presentation and pending construction are rebuilt for the cleared wave")
	check(game.buildings[belt_cell].kind == "belt" and game.buildings[belt_cell].dir == 1 and game.buildings[belt_cell].has("pending"), "Belts reconstruct with usable direction and runtime fields")
	preload("res://scripts/debug_tools.gd").next_core(game)
	var second: Vector2i = game.current_core
	game.wave = 1
	check(game.saves.save_slot(2), "Saves second-core progress")
	for gate in game.spawners:
		gate.converted = true
		gate.waves_completed = 99
	game.current_core = core
	check(game.saves.load_slot(2) and game.current_core == second and game.cores.size() == 2, "Captured core order is derived from retained core buildings")
	check(game.spawners[0].converted and game.spawners[0].waves_completed == game.spawners[0].waves_before_conversion and not game.active_spawners.is_empty(), "Spawner conversion and the next frontier are reconstructed from core progress")
	var legacy: Array = game.saves.snapshot().duplicate(true)
	legacy[0] = 18
	legacy[1][5] = 222
	legacy[1][7] = 333.0
	legacy[3][game.saves.TUTORIAL_FIELDS.find("ui_revealed")].old_secret = true
	var old_path := "res://.godot/legacy_minimal_save.ews"
	legacy_file(old_path, legacy)
	var migrated: Array = game.saves.read_snapshot(old_path)
	check(not migrated.is_empty() and migrated[0] == 19 and migrated[1][5] == 0 and migrated[1][7] == 0, "Legacy saves migrate and discard stored counters and elapsed time")
	check(not migrated[3][game.saves.TUTORIAL_FIELDS.find("ui_revealed")].has("old_secret"), "Legacy tutorial history is rebuilt rather than restored")
	var invalid := saved.duplicate(true)
	invalid.buildings.append(invalid.buildings[0].duplicate(true))
	check(State.expand(game, invalid).is_empty(), "Malformed saves with overlapping buildings are rejected")
	var noncore := saved.duplicate(true)
	var was_core: bool = game.spawners[0].turns_into_core
	game.spawners[0].turns_into_core = false
	noncore.progress.wave = game.spawners[0].waves_before_conversion + 2
	var rebuilt: Array = State.expand(game, noncore)
	check(rebuilt[4][0][1] and rebuilt[4][1][0] == 1 and not rebuilt[4][1][1], "Non-core gate groups are reconstructed dynamically from wave progress")
	game.spawners[0].turns_into_core = was_core
	print("MINIMAL SAVES: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
