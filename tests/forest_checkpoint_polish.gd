extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.buildings[game.current_core].max_hp == 200 and game.core_health == 200, "Core starts with two hundred health")
	var status = preload("res://scripts/building_status.gd").new()
	status.game = game
	var drill := Vector2i(20, 25)
	game._add_building(drill, "drill", 0)
	game.buildings[drill].item = "copper"
	status.refresh()
	check(not status.statuses.any(func(entry): return entry.cell == drill and entry.no_output), "Disconnected extractors never show No output")
	status.free()
	var enemy: Dictionary = game.create_enemy("scout", game.building_center(game.current_core) + Vector2(45, 0), "red")
	enemy.cooldown = 0
	enemy.aim = PI
	game.enemies.append(enemy)
	game.enemy_visual_offsets[enemy.info_id] = Vector2(0, 16)
	game._update_enemies(0.01)
	check(not game.shots.is_empty() and game.shots.back().from.y > enemy.pos.y + 10, "Stack-offset enemy shots originate at the displayed sprite")
	fresh()
	var gate = game.active_spawners[0]
	var selected: int = game.spawners.find(gate)
	for other in game.spawners: other.converted = other != gate
	gate.waves_before_conversion = 12
	gate.waves_completed = 0
	gate.allowed_enemies = PackedStringArray(["scout"])
	gate.wave_enemy_lists.clear()
	gate.credits_per_wave = PackedInt32Array([3])
	game.wave = 0
	game.pending_waves.clear()
	var lookahead = preload("res://scripts/spawn_lookahead.gd")
	var rows: Array = lookahead.build(game, selected)
	check(rows.size() == 7 and rows[0].local == 1 and rows[6].local == 7, "Preview contains the next wave and six future waves")
	var future = game.spawners.back()
	if future == gate: future = game.spawners[1]
	future.converted = false
	future.Order = gate.Order + 1
	gate.waves_before_conversion = 2
	rows = lookahead.build(game, selected)
	check(rows.size() == 2 and rows.back().order == gate.Order, "Future waves stop before the next core")
	game.wave = 2
	game.pending_waves[2] = [selected]
	gate.waves_completed = 1
	rows = lookahead.build(game, selected)
	check(rows.size() == 1, "The final queued wave has no preview from the next core")
	game.hud.show_info("Enemy spawn", "", Vector2(900, 600))
	var preview = preload("res://scripts/spawn_preview.gd").new()
	preview.hud = game.hud
	game.hud.info_root.add_child(preview)
	game.wave = 0
	game.pending_waves.clear()
	gate.waves_completed = 0
	gate.waves_before_conversion = 12
	preview.show_forecast({"scout": 3}, Vector2(900, 600), 1, {"red": {"scout": 3}}, selected)
	check(preview.summary.get_children().any(func(node): return node is Label and node.text == "Future waves"), "Future waves has its own small heading below the current wave")
	check(preview.summary.get_children().filter(func(node): return node is Label and node.text.begins_with("Wave ")).size() == 6, "Popup renders exactly six future-wave rows")
	var portrait: TextureRect = preview.get_child(0).get_child(0)
	check(portrait.get_child_count() == 1, "Enemy preview portraits have a separate color frame")
	preview.hide_preview()
	fresh()
	game.saves.entries.clear()
	game.saves.current = -1
	game.tutorial.skip_to_ready()
	game.paused = false
	for spawn in game.active_spawners: spawn.waves_before_conversion = 99
	game.inventory.copper = 17
	game.launch_wave()
	check(game.wave == 1 and game.saves.entries.is_empty(), "Calling a wave no longer saves before it starts")
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.inventory.copper = 29
	game.inventory.iron = 7
	game.inventory.pink = 3
	game._complete_wave(1)
	check(game.saves.entries.size() == 1, "Defeating the final enemy creates one checkpoint")
	var snapshot: Array = game.saves.load_snapshot(0)
	check(snapshot[1][0].copper == 29 and snapshot[1][0].iron == 7 and snapshot[1][0].pink == 3 and snapshot[1][22].is_empty(), "Checkpoint stores the exact current resources and no remaining enemies")
	game.inventory.copper = 0
	check(game.saves.restore(0) and game.inventory.copper == 29 and game.paused and game.wave == 1 and game.spawn_remaining == 0, "Loading restores post-wave resources and pauses without spawning a wave")
	var previous: Array = game.saves.snapshot().duplicate(true)
	previous[0] = 16
	for row in previous[2]:
		if row[1] == "core":
			row[4] = 1000.0
			row[5] = 2000.0
	var path: String = game.saves.directory.path_join("old_core_health.ews")
	game.saves.write_snapshot(path, previous)
	var migrated: Array = game.saves.read_snapshot(path)
	var core_row: Array = migrated[2].filter(func(row): return row[1] == "core")[0]
	check(core_row[4] == 100 and core_row[5] == 200 and migrated[1][13] == 100, "Old core health migrates to two hundred while preserving its damage fraction")
	fresh()
	for spawn in game.active_spawners: spawn.waves_before_conversion = 99
	game.wave = 2
	selected = game.spawners.find(game.active_spawners[0])
	game.pending_waves = {1: [selected], 2: [selected]}
	enemy = game.create_enemy("scout", game.cell_center(Vector2i(20, 25)), "red")
	enemy.wave_id = 2
	game.enemies.append(enemy)
	game._complete_wave(1)
	check(game.saves.entries.is_empty(), "Finishing an overlapped wave waits for all other enemies")
	game.enemies.clear()
	game._complete_wave(2)
	check(game.saves.entries.size() == 1 and game.saves.load_snapshot(0)[1][3] == 2, "Overlapped waves save once when every enemy has been defeated")
	fresh()
	game.tutorial.skipped = false
	game.tutorial.onboarding_completed = true
	game.tutorial.turrets_ever_built = 1
	game.wave = 2
	game.paused = true
	check(game.tutorial.second_turret_hint_active() and game.tutorial.building_should_glow("solar"), "Pausing on first-core wave two highlights the turret until a second is built")
	game.paused = false
	check(game.tutorial.second_turret_hint_active(), "Second-turret guidance remains after unpausing")
	game._add_building(Vector2i(20, 25), "solar", 0)
	game.tutorial.on_building_placed("solar", Vector2i(20, 25))
	check(not game.tutorial.second_turret_hint_active(), "Building the second turret permanently clears its guidance")
	check(game.TECH.time_speed.parent == "barriers" and game.TECH.time_speed.cost == {"copper": 20}, "Time acceleration follows barriers and costs twenty nuggets")
	game.fog_disabled = false
	game.visible_cells = {Vector2i.ZERO: true}
	game.visibility_revision += 1
	var point: Vector2 = game.clamp_camera_position(Vector2(-5000, -5000))
	check(point.x < 0 and point.y < 0 and point.length() <= 640.001, "Camera allows negative coordinates but stays within twenty tiles of revealed land")
	check(game.clamp_camera_position(Vector2(-100, 10)) == Vector2(-100, 10), "Camera movement within the fog margin remains free")
	game.camera.position = point
	game.camera.force_update_scroll()
	check(game.fog.visible_view().position.x < 0 and game.fog.visible_view().position.y < 0, "Fog coverage follows the viewport through negative world coordinates")
	var forest = preload("res://scripts/forest_terrain.gd")
	forest.initialize()
	check(forest.masks.size() == 47, "Forest supports every outer/inner corner, edge and center connection")
	var authored: TileSet = load("res://resources/rock_tiles.tres")
	check(authored.get_source(0).get_tiles_count() == 191 and authored.get_terrain_name(0, 0) == "Pine forest", "Editor terrain includes forty-seven shapes and seven interior variants")
	var painted := TileMapLayer.new()
	game.add_child(painted)
	painted.tile_set = authored
	var stroke: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	painted.set_cells_terrain_connect(stroke, 0, 0)
	check(painted.get_used_cells().size() == 3 and stroke.all(func(cell): return painted.get_cell_tile_data(cell).terrain == 0), "Editor terrain painting connects a forest stroke without adding blocking cells")
	var layer := TileMapLayer.new()
	game.add_child(layer)
	layer.tile_set = authored
	var cells := {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(0, 1): true, Vector2i(-1, 0): true}
	for cell in cells: layer.set_cell(cell, 0, Vector2i.ZERO)
	forest.configure(layer, 16)
	check(layer.get_used_cells().size() == cells.size() and layer.get_cell_atlas_coords(Vector2i.ZERO) == forest.atlas_coords(cells, Vector2i.ZERO), "Autotiling preserves all painted cells, including negatives")
	var coords: Vector2i = layer.get_cell_atlas_coords(Vector2i.ZERO)
	forest.configure(layer, 64)
	check(layer.get_cell_atlas_coords(Vector2i.ZERO) == coords and layer.scale == Vector2.ONE * 0.5, "Zoom changes keep the same deterministic forest variants")
	var image: Image = forest.texture(64).get_image()
	var center_index: int = forest.tile_index(255, 0)
	var center: Vector2i = Vector2i(center_index % 16, center_index / 16) * 64
	var forest_pixels := 0
	var transparent_pixels := 0
	for y in 64:
		for x in 64:
			var color := image.get_pixelv(center + Vector2i(x, y))
			if color.a > 0.5 and color.g > color.r: forest_pixels += 1
			if color.a < 0.5: transparent_pixels += 1
	check(forest_pixels > 3900 and transparent_pixels == 0, "Interior forest forms a dense connected canopy with foliage hollows instead of dirt gaps")
	var complete_outside_edges := true
	for mask in forest.masks:
		for variant in forest.variant_count(mask):
			var tile_index: int = forest.tile_index(mask, variant)
			var origin := Vector2i(tile_index % 16, tile_index / 16) * 64
			for pixel in 64:
				for side in 4:
					if mask & (1 << side): continue
					var offset: Vector2i = [Vector2i(pixel, 0), Vector2i(63, pixel), Vector2i(pixel, 63), Vector2i(0, pixel)][side]
					if image.get_pixelv(origin + offset).a > 0: complete_outside_edges = false
	check(complete_outside_edges, "Exposed forest edges keep complete canopy silhouettes without tile boundary cuts")
	var stable_edges := true
	for mask in forest.masks:
		var base_index: int = forest.tile_index(mask, 0)
		var base: Vector2i = Vector2i(base_index % 16, base_index / 16) * 64
		for variant in range(1, forest.variant_count(mask)):
			var other_index: int = base_index + variant
			var other := Vector2i(other_index % 16, other_index / 16) * 64
			for edge in 64:
				for offset in [Vector2i(edge, 0), Vector2i(edge, 63), Vector2i(0, edge), Vector2i(63, edge)]:
					if image.get_pixelv(base + offset) != image.get_pixelv(other + offset): stable_edges = false
	check(stable_edges, "Every variation has identical boundary pixels so mixed variants join seamlessly")
	var outline_counts := {}
	for mask in [0,239,255]:
		var index: int = forest.tile_index(mask,0)
		var origin := Vector2i(index % 16,index / 16) * 64
		var outline_pixels := 0
		for y in 64:
			for x in 64:
				if image.get_pixelv(origin + Vector2i(x,y)) == Color("173d35"): outline_pixels += 1
		outline_counts[mask] = outline_pixels
	check(outline_counts[0] > 50 and outline_counts[239] > 20 and outline_counts[255] == 0, "Dark green outlines follow outer and inner forest corners without outlining joined interior tiles")
	print("FOREST CHECKPOINT POLISH CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
