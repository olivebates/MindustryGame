extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var status = preload("res://scripts/building_status.gd")
	var refinery := Vector2i(20, 25)
	game._add_building(refinery, "refinery", 0)
	var machine: Dictionary = game.buildings[refinery]
	check(status.missing_inputs(game, machine) == ["copper", "iron"], "Empty refinery requires both input icons")
	machine.buffer.copper = 1
	check(status.missing_inputs(game, machine) == ["iron"], "Only missing inputs are shown")
	machine.buffer.iron = 1
	check(status.missing_inputs(game, machine).is_empty(), "One of each input hides Requires")
	check(not status.has_output(game, refinery, machine), "Disconnected producer reports No output")
	game._add_building(Vector2i(22, 25), "belt", 0)
	game.buildings[Vector2i(22, 25)].item = "iron"
	check(status.has_output(game, refinery, machine), "Connected full output is distinguished from missing output")
	game.buildings[Vector2i(22, 25)].dir = 2
	check(not status.has_output(game, refinery, machine), "An incoming conveyor is not an output")
	var silo := Vector2i(26, 25)
	game._add_building(silo, "iron_store", 0)
	check(game.footprint_size("iron_store") == 2 and game.anchor_at(silo + Vector2i.ONE) == silo, "Iron silo occupies two by two tiles")
	check(status.missing_inputs(game, game.buildings[silo]) == ["pink"], "Silo requires Pink Stuff fuel")
	var tower := Vector2i(29, 25)
	game._add_building(tower, "turret", 0)
	var building: Dictionary = game.buildings[tower]
	check(status.missing_inputs(game, building).is_empty(), "Empty booster slots do not show Requires")
	building.ammo = 0
	check(status.missing_inputs(game, building) == ["iron"], "Empty ammunition still shows Requires")
	building.ammo = 8
	building.booster_type = "pink"
	building.booster_count = 2
	game.hud.show_structure_info("turret", building, Vector2(500, 500))
	var body: String = game.hud.tooltip_body.text
	check(body.contains("[s][base_stat]4s[/base_stat][/s]") and body.contains("#83d780]2s"), "Boosted interval stays inline with a thin strike")
	check(body.contains("[s][base_stat]5[/base_stat][/s]") and body.contains("#83d780]10"), "Boost tooltip compares base and boosted DPS inline")
	check(body.contains("stat_dps.svg") and body.find("DPS:") < body.find("Range:"), "Boosted DPS retains its original icon and position")
	var ammo: Rect2 = game.ammo_bar_rect(tower)
	var booster: Rect2 = game.booster_bar_rect(tower)
	check(ammo.end.y == booster.position.y and ammo.size == booster.size and ammo.position.x == booster.position.x, "Booster bar touches ammo directly below at full width")
	fresh()
	var gate = game.active_spawners[0]
	for other in game.spawners: other.converted = other != gate
	gate.waves_completed = 0
	gate.waves_before_conversion = 16
	gate.possible_colors = PackedStringArray(["blue"])
	gate.wave_color_palettes.clear()
	gate.allowed_enemies = PackedStringArray(["scout"])
	gate.wave_enemy_lists.clear()
	gate.credits_per_wave = PackedInt32Array(range(1, 17))
	game.wave = 0
	game.pending_waves.clear()
	var index: int = game.spawners.find(gate)
	var rng_state: int = game.rng.state
	var rows: Array[Dictionary] = preload("res://scripts/spawn_lookahead.gd").build(game, index)
	check(rows.size() == 7 and rows[6].local == 7 and rows[6].variants[0].count == 7, "Forecast includes the next wave and six following waves")
	check(game.rng.state == rng_state and gate.waves_completed == 0, "Forecast does not mutate gameplay state or randomness")
	var forecast: Dictionary = game.next_wave_forecast([index])
	var preview = preload("res://scripts/spawn_preview.gd").new()
	preview.hud = game.hud
	game.hud.info_root.add_child(preview)
	game.hud.show_info("Enemy spawn", "", Vector2(500, 400))
	preview.show_forecast(forecast.by_spawn[index].counts, Vector2(500, 400), 1, forecast.by_spawn[index].colored, index)
	var colored := false
	for child in preview.get_child(0).get_children():
		if child is TextureRect and child.get_child_count() == 1: colored = true
	check(colored, "Spawn portraits use selective color textures and team-colored frames")
	var row_count := 0
	for child in preview.summary.get_children():
		if child is Label and child.text.begins_with("Wave "): row_count += 1
	check(row_count == 6, "Tooltip shows six compact future-wave rows")
	if game.spawners.size() > 1:
		var future_gate = game.spawners[1 if index == 0 else 0]
		future_gate.converted = false
		future_gate.Order = gate.Order + 1
		future_gate.waves_completed = 0
		future_gate.waves_before_conversion = 16
		future_gate.allowed_enemies = PackedStringArray(["scout"])
		future_gate.wave_enemy_lists.clear()
		future_gate.possible_colors = PackedStringArray(["green"])
		future_gate.wave_color_palettes.clear()
		future_gate.credits_per_wave = PackedInt32Array([3])
		gate.waves_before_conversion = 2
		gate.turns_into_core = true
		rows = preload("res://scripts/spawn_lookahead.gd").build(game, index)
		check(rows.size() == 2 and rows[1].order == gate.Order, "Lookahead stops at the selected core's final wave")
		game.wave = 2
		game.pending_waves[1] = [index]
		game.pending_waves[2] = [index]
		rows = preload("res://scripts/spawn_lookahead.gd").build(game, index)
		check(rows.size() == 1, "During the final wave no following-core rows are shown")
	print("BUILDING STATUS AND FORECAST CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
