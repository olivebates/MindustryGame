extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var splitter := Vector2i(22, 25)
	var tower := Vector2i(23, 25)
	game._add_building(splitter, "splitter", 0)
	game._add_building(tower, "turret", 0)
	game.buildings[tower].ammo = 0
	game.buildings[splitter].item = "iron"
	game._update_items(2.1)
	check(game.buildings[tower].ammo == 1 and game.buildings[splitter].item == "", "Splitter feeds iron directly into an adjacent Slugger")
	check(not game.splitter_outputs(splitter, "copper").has(0), "Wrong ammunition is not a splitter output")
	game.buildings[tower].ammo = 8
	check(not game.splitter_outputs(splitter, "iron").has(0), "A full building is skipped")
	game._add_building(splitter + Vector2i.DOWN, "belt", 1)
	game.buildings[splitter].item = "iron"
	game._update_items(2.1)
	check(game.buildings[splitter + Vector2i.DOWN].item == "iron", "Splitter skips the full Slugger and feeds its available belt")
	fresh()
	game._add_building(Vector2i(24, 25), "splitter", 0)
	game.buildings[Vector2i(24, 25)].item = "copper"
	var copper: int = game.inventory.copper
	game.inventory.copper = copper - 1
	game._update_items(2.1)
	check(game.inventory.copper == copper, "Splitter delivers directly into the core")
	var gate = game.active_spawners[0]
	game.active_spawners.assign([gate])
	game.pending_waves.clear()
	gate.waves_before_conversion = 3
	gate.waves_completed = 2
	game.wave = 2
	game.hud.refresh()
	check(game.hud.next_wave_label.text == "Next wave: Last Wave", "Upcoming final wave has the requested label")
	check(game.spawn_wave_title(gate).ends_with("Wave 3/3"), "Spawn hover title includes local wave and total")
	game.pending_waves[3] = [game.spawners.find(gate)]
	game.wave = 3
	game.hud.refresh()
	game.hud.announce_wave(3)
	check(game.hud.next_wave_label.text == "Last Wave" and game.hud.wave_announcement.text == "Last Wave", "Launched final wave updates both HUD labels")
	print("SPLITTER AND FINAL WAVE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
