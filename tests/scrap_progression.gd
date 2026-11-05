extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
func run() -> void:
	fresh()
	game.add_resource("copper", 4)
	check(not game.hud.palette.visible, "Structures stays hidden at four copper")
	game.add_resource("copper", 1)
	check(game.hud.palette.visible and game.building_cost("drill") == {"copper": 5}, "Five copper reveals a normally priced extractor")
	game.select_building("drill")
	game.place_building(Vector2i(20, 22), "drill", 0)
	check(game.inventory.copper == 0 and game.tutorial.connection_cost_remaining() == 2, "Connection quote counts only the missing two belts")
	game.hud.refresh()
	check(game.hud.tutorial_prompt.text == "Right click to deselect", "Running out before the connection shows the mining recovery prompt")
	game.add_resource("copper", 1)
	game.hud.refresh()
	check(game.hud.tutorial_prompt.text == "Right click to deselect", "Recovery prompt remains until the full remaining connection is affordable")
	game.add_resource("copper", 1)
	game.hud.refresh()
	check(not game.hud.tutorial_prompt.visible, "Recovery prompt disappears when the whole connection can be built")
	game.place_building(Vector2i(21, 22), "belt", 0)
	check(game.tutorial.connection_cost_remaining() == 1, "Existing belts are excluded from the remaining connection quote")
	game.place_building(Vector2i(22, 22), "belt", 0)
	check(game.tutorial.extractor_connected_once, "Affordable starter route connects the extractor to the core")
	game.add_resource("copper", 30)
	game.place_building(Vector2i(25, 20), "belt", 0)
	game.place_building(Vector2i(25, 19), "belt", 0)
	check(game.buildings[Vector2i(25, 20)].dir == 0 and game.belt_connected(Vector2i(25, 20)), "The fresh belt connects without rotating an older neighbor")
	game.place_building(Vector2i(26, 19), "belt", 0)
	check(game.buildings[Vector2i(25, 19)].dir == 1 and game.buildings[Vector2i(25, 20)].dir == 0, "Extending a chain preserves its established flow")
	check(game.FLOW_INTERVAL == 1.0 and game.ConveyorMotion.SPEED == 32.0, "Belts and their arrows transport exactly one tile per second")
	check(game.BUILDINGS.solar.range == 3 * game.TILE, "Solar turret has exactly three tiles of range")
	var info = load("res://scripts/structure_info.gd")
	check(info.number(3.0) == "3" and info.number(0.6) == "0.6" and info.number(1.25) == "1.25" and info.number(10.0) == "10", "Stat formatter strips only redundant decimal zeros")
	var stats: String = info.stats(game, "solar")
	check(stats.contains("DPS: 3.33") and stats.contains("Range: 3 tiles") and not stats.contains("Ammo:") and not stats.contains("colors") and not stats.contains(".00"), "Solar stats show DPS and clean values without ammo or color prose")
	check(not info.stats(game, "drill").contains("Outputs:"), "Extractor stats omit outputs")
	game.hud.show_structure_info("solar", {}, Vector2(700, 400))
	check(game.hud.color_dots.visible and game.hud.color_dots.colors == ["red"], "Solar info shows a red unlock dot")
	game.research("solar_blue", true)
	game.hud.show_structure_info("solar", {}, Vector2(700, 400))
	check(game.hud.color_dots.colors.has("blue") and not game.hud.color_dots.colors.has("green"), "Color dots reflect per-turret research")
	game.cancel_build_selection()
	var count_before: int = game.buildings.size()
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(27, 20))
	game.finish_drag()
	check(game.buildings[Vector2i(25, 20)].dir == 0 and game.buildings.size() == count_before, "Dragging an existing belt turns its output without constructing new tiles")
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(25, 19))
	game.finish_drag()
	check(game.buildings[Vector2i(25, 20)].dir == 0 and game.buildings[Vector2i(25, 19)].dir == 1, "Dragging toward a neighboring belt connects into it while preserving its output")
	game.selected = "belt"
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(25, 19))
	game.finish_drag()
	check(game.tunnel_pending == game.INVALID and game.buildings[Vector2i(25, 19)].dir == 3 and game.buildings[Vector2i(25, 20)].dir == 3, "Click-dragging existing neighbors with Belt selected connects without making a tunnel")
	game.selected = ""
	game._add_building(Vector2i(24, 20), "belt", 0)
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(24, 20))
	game.finish_drag()
	check(game.buildings[Vector2i(25, 20)].dir == 3 and game.buildings[Vector2i(24, 20)].dir == 0, "Dragging toward an incoming belt cannot create a two-belt loop")
	game.selected = "belt"
	game.begin_drag(Vector2i(25, 20))
	game.extend_drag(Vector2i(24, 20))
	game.finish_drag()
	check(game.buildings[Vector2i(25, 20)].dir == 2 and game.buildings[Vector2i(24, 20)].dir == 2, "Construction painting reorients both explicitly touched belts")
	game.tutorial.skip_to_ready()
	game.wave = 0
	game.launch_wave()
	check(game.last_wave_budget == game.active_spawners[0].budget() and game.spawn_queue.size() == game.last_wave_budget / game.Content.ENEMY_TYPES.scout.credits, "First wave respects the user-authored spawner credit budget")
	var tanks := true
	for enemy in game.spawn_queue: tanks = tanks and enemy.kind == "scout" and enemy.color == "red"
	check(tanks, "First wave contains three red small tanks")
	game.enemies.clear()
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.wave_in_progress = false
	game.tutorial.skipped = false
	game._damage_building(game.current_core, 1)
	game.tutorial.on_wave_completed(1)
	check(game.tutorial.central_message() == "Press space to pause and build.", "First damage still prompts pausing")
	game.tutorial.on_wave_completed(1)
	game.scraps.append({"pos": game.cell_center(game.current_core), "amount": 3, "magnetized": false})
	game.toggle_pause()
	game.hud.refresh()
	game.hud._process(0)
	var outlines: PackedVector4Array = game.hud.screen_edges.material.get_shader_parameter("panels")
	var inventory_rect: Rect2 = game.hud.inventory_panel.get_global_rect()
	var bottom_rect: Rect2 = game.hud.palette.get_global_rect()
	check(outlines.has(Vector4(inventory_rect.position.x, inventory_rect.position.y, inventory_rect.size.x, inventory_rect.size.y)), "Mode glow wraps around the visible inventory panel")
	check(outlines.has(Vector4(bottom_rect.position.x, bottom_rect.position.y, bottom_rect.size.x, bottom_rect.size.y)), "Mode glow follows the top edge of the bottom GUI")
	check(game.hud.tutorial_prompt.visible and game.hud.tutorial_prompt.text == "Mouse over the scraps to collect.", "First pause shows the central scrap instruction")
	check(not game.tutorial.tech_available, "Research remains hidden until the tutorial scrap is collected")
	game.scraps.assign([{"pos": game.cell_center(game.current_core + Vector2i(2, 1)), "amount": 3, "magnetized": false}])
	var pointer: Vector2 = game.scraps[0].pos
	game.collect_scrap(0.1, pointer)
	check(game.paused and game.inventory.scrap == 3 and game.scraps.is_empty(), "Scrap can be collected while combat is paused")
	check(game.tutorial.tech_available and game.hud.tech_button.visible and game.hud.tech_button.get_meta("tutorial_glow"), "Collecting the tutorial salvage reveals glowing research")
	check(game.TECH.barriers.cost == {"scrap": 3}, "Barrier research costs the scrap from three small tanks")
	game.researched.erase("solar_blue")
	game.hud.show_tech_tree()
	check(game.hud.tech_buttons.size() == 1 and game.hud.tech_buttons.barriers.button.get_meta("tutorial_glow"), "Barrier is the first glowing research item")
	game.hud.tech_buttons.barriers.button.pressed.emit()
	check(game.researched.has("barriers") and game.inventory.scrap == 0, "Barrier research consumes three scrap and twenty copper")
	check(not game.hud.category_buttons.Structures.visible and game.hud.category_buttons.Infrastructure.visible and game.hud.category_buttons.Defence.visible, "Barrier research splits Structures into Infrastructure and Defence")
	check(game.hud.unlocked_in_category("Infrastructure").has("drill") and not game.hud.unlocked_in_category("Infrastructure").has("solar") and game.hud.unlocked_in_category("Defence").has("wall") and game.hud.unlocked_in_category("Defence").has("solar"), "The two categories divide factory and defensive buildings correctly")
	check(game.building_cost("wall").copper == 3, "Barrier blocks start at three copper")
	game.placement_counts.wall = 10
	check(game.building_cost("wall", 10).copper == roundi(3 * pow(1.05, 10)), "Barriers inflate five percent per block during a round")
	game.hud.close_modal()
	await process_frame
	game.hud.refresh()
	check(game.hud.tutorial_prompt.text == "Hold alt while mousing over something for info.", "Closing researched Barriers starts the central info tutorial")
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.tutorial.update_info_hover(0.1, true, "building:one")
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.tutorial.update_info_hover(0.1, true, "building:one")
	check(game.tutorial.inspected_things.size() == 1 and game.tutorial.central_message() != "", "Repeated hover on the same object counts only once")
	game.tutorial.update_info_hover(0.1, true, "building:two")
	game.tutorial.update_info_hover(0.1, true, "enemy:three")
	check(game.tutorial.central_message() == "Press space to unpause", "Inspecting three different things starts the final unpause instruction")
	game.tutorial.inspected_things.clear()
	game.tutorial.info_hover_time = 0
	game.tutorial.update_info_hover(2.0, true, "one")
	check(game.tutorial.central_message() == "Press space to unpause", "Two seconds on one object also starts the final unpause instruction")
	var target: Dictionary = game.create_enemy("scout", game.cell_center(game.current_core + Vector2i(3, 2)), "red")
	game.enemies.append(target)
	game.hover_cell = Vector2i((target.pos / game.TILE).floor())
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.get_canvas_transform() * target.pos)
	check(game.hud.tooltip.visible and game.hud.tooltip_title.text == "Small tank" and game.hud.tooltip_body.text.contains("DPS:") and game.hud.tooltip_body.text.contains("Scrap: 1"), "Alt-hover on enemies shows their live stats and salvage")
	alt.pressed = false
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.enemies.clear()
	game.wave_in_progress = true
	game._complete_wave()
	var saved: Array = game.saves.snapshot().duplicate(true)
	game.tutorial.collected_tutorial_scrap = 0
	game.tutorial.barrier_tree_closed = false
	game.tutorial.inspected_things.clear()
	check(game.saves.restore(0) and game.saves.snapshot()[1] == saved[1] and game.tutorial.barrier_tree_closed and game.tutorial.inspected_things.size() >= saved[3][17].size(), "Wave saves preserve scrap, barrier and inspected-object tutorial progress")
	for entry in game.saves.entries: DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	# Simulate three simultaneous head-on opponents for every affinity matchup.
	for kind in ["scout", "runner"]:
		for color in ["red", "green", "blue"]:
			fresh()
			game.tutorial.skip_to_ready()
			game.rocks.clear()
			game.wave = 1
			var cell: Vector2i = game.current_core + Vector2i(8, 0)
			game._add_building(cell, "solar", 0)
			var tower: Dictionary = game.buildings[cell]
			for offset in [-16, 0, 16]:
				game.enemies.append(game.create_enemy(kind, game.cell_center(cell) + Vector2(128, offset), color))
			for step in 3000:
				if game.enemies.is_empty() or not game.buildings.has(cell): break
				game._update_turret(cell, tower, 0.02)
				game._update_enemies(0.02)
			print("BALANCE: ", kind, " ", color, " survivors=", game.enemies.size(), " damage=", tower.max_hp - tower.hp)
			check((tower.hp == tower.max_hp) if kind == "runner" else (game.enemies.is_empty() and tower.hp >= tower.max_hp * 0.6), "Enemies avoid turret coverage on their way to the core: " + color + " " + kind)
	game.free()
	print("SCRAP PROGRESSION CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

















