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
func build_intro() -> void:
	game.add_resource("copper", 5)
	game.select_building("drill")
	game.place_building(Vector2i(20, 22), "drill", 0)
	game.add_resource("copper", 2)
	game.select_building("belt")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.add_resource("copper", 10)
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
func run() -> void:
	fresh()
	var tutorial = game.tutorial
	check(game.hud.tutorial_prompt.anchor_top == 0 and game.hud.tutorial_prompt.position.y == 112 and game.hud.tutorial_prompt.get_theme_color("font_color").r > 0.9 and game.hud.tutorial_prompt.get_theme_constant("shadow_outline_size") > 0, "Tutorial text is yellow, glowing and at the upper center")
	game.add_resource("copper", 5)
	game.select_building("drill")
	game.place_building(Vector2i(20, 22), "drill", 0)
	check(tutorial.designated_extractor == Vector2i(20, 22) and tutorial.designated_path.has(Vector2i(21, 22)), "First correct extractor establishes a designated connection path")
	check(tutorial.central_message() == "Right click to deselect", "Selected construction gets the deselection instruction")
	game.cancel_build_selection()
	check(tutorial.central_message() == "Mine some more ore.", "Deselected construction gets only the mining instruction")
	game.add_resource("copper", 20)
	game.select_building("belt")
	game.place_building(Vector2i(25, 23), "belt", 0)
	check(tutorial.misplaced_buildings.has(Vector2i(25, 23)) and tutorial.central_message() == "Press X to enter demolish mode", "Off-path placement marks the building red and starts demolition instruction")
	game.select_tool("abolish")
	check(tutorial.central_message() == "Press on buildings to demolish them.", "Demolition mode instructs removing undesired buildings")
	game.remove_building(Vector2i(25, 23))
	check(tutorial.central_message() == "Presss X to leave demolish mode.", "With no undesired structures left the lesson asks to leave demolish mode")
	game.select_tool("abolish")
	check(tutorial.demolish_completed and not tutorial.demolition_lesson_active(), "Exiting demolition completes its tutorial permanently")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
	check(tutorial.start_controls_available() and game.hud.wave_controls.visible and not game.hud.pause_button.visible, "Correct structures plus completed demolition reveal wave controls but not pause")
	game.remove_building(Vector2i(21, 22))
	check(tutorial.stage == tutorial.Stage.BELTS and not game.hud.wave_controls.visible, "Removing a designated belt restores the belt step and hides first-wave controls")
	game.place_building(Vector2i(21, 22), "belt", 0)
	check(tutorial.stage == tutorial.Stage.READY and tutorial.start_controls_available(), "Rebuilding the designated belt restores readiness")
	game.remove_building(Vector2i(20, 22))
	check(tutorial.stage == tutorial.Stage.EXTRACTOR, "Removing the designated extractor returns to extraction")
	game.place_building(Vector2i(20, 22), "drill", 0)
	check(tutorial.start_controls_available(), "Rebuilding the extractor preserves the other completed structures")
	game.remove_building(Vector2i(31, 22))
	check(tutorial.stage == tutorial.Stage.SOLAR, "Removing the designated Solar restores its placement step")
	game.inventory.copper = 40
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
	game.toggle_pause()
	check(not game.paused, "Pause functionality remains unavailable before the damage instruction")
	game.launch_wave()
	check(game.wave == 1 and tutorial.onboarding_completed, "Starting the first wave finalizes construction onboarding")
	game._damage_building(Vector2i(31, 22), 1)
	game.tutorial.on_wave_completed(1)
	game.hud.refresh()
	check(game.hud.pause_button.visible and tutorial.central_message() == "Press space to pause and build.", "First damage reveals pause functionality and its instruction")
	game.toggle_pause()
	check(game.paused, "Pause works after its instruction is revealed")
	game.pause_grid._process(0)
	check(game.pause_grid.visible and game.pause_grid.z_index > game.fog.z_index, "Paused world grid is visible above fog and beneath the GUI canvas")
	var bounds: Rect2 = game.pause_grid.grid_bounds()
	check(bounds.size.x > 0 and bounds.size.y > 0, "Paused grid covers the current viewport in world coordinates")
	game.toggle_pause()
	game.pause_grid._process(0)
	check(not game.pause_grid.visible, "Resuming hides the pause grid")
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.enemies.clear()
	game._complete_wave()
	game.hud.refresh()
	check(game.hud.next_button.text == "Start Early", "Between-wave start button says Start Early")
	tutorial.barrier_tree_closed = true
	tutorial.info_hover_time = 2.0
	tutorial.pause_exit_completed = true
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.wave = 4
	tutorial.speed_toggled = false
	check(tutorial.central_message() != "Press E to speed up time.", "Speed instruction does not appear before wave five")
	game.wave = 5
	check(tutorial.central_message() == "Press E to speed up time.", "Wave five prompts the speed shortcut")
	game.cycle_speed()
	check(tutorial.central_message() != "Press E to speed up time.", "Using speed clears the wave-five instruction")
	# Fresh intro must include the demolition lesson even with no mistakes.
	fresh()
	build_intro()
	check(game.tutorial.required_structures_built() and game.tutorial.start_controls_available() and not game.tutorial.demolition_lesson_active(), "A mistake-free intro reveals Start without requiring demolition")
	game.select_tool("abolish")
	check(game.tutorial.central_message() == "Presss X to leave demolish mode.", "No unnecessary demolition is required in a correct intro")
	game.cancel_build_selection()
	check(game.tutorial.start_controls_available(), "Right-click can complete the exit from demolition mode")
	# Existing conveyor routes are protected from automatic drag edits.
	game.tutorial.skip_to_ready()
	game.inventory.copper = 40
	game.rocks.clear()
	game._add_building(Vector2i(27, 25), "belt", 1)
	var original: Dictionary = game.buildings[Vector2i(27, 25)].duplicate(true)
	game.select_building("belt")
	game.build_direction = 0
	game.begin_drag(Vector2i(26, 25))
	game.extend_drag(Vector2i(26, 26))
	game.finish_drag()
	check(game.buildings[Vector2i(27, 25)].dir == original.dir and game.buildings[Vector2i(27, 25)].input_dir == original.input_dir, "Placement does not change an older neighboring belt's input or output")
	check(game.buildings[Vector2i(26, 25)].dir == 1, "Belts created in the same drag still turn to follow it")
	# Owned counts control prices across waves and demolition.
	game.research("barriers", true)
	var base: int = game.building_cost("wall").copper
	game.inventory.copper = 40
	game.place_building(Vector2i(29, 24), "wall", 0)
	game.place_building(Vector2i(29, 25), "wall", 0)
	var inflated: int = game.building_cost("wall").copper
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.enemies.clear()
	game.wave_in_progress = false
	game.launch_wave()
	check(game.building_cost("wall").copper == inflated and game.owned_building_counts().wall == 2, "Starting a wave preserves owned-count price inflation")
	game.remove_building(Vector2i(29, 24))
	check(game.building_cost("wall").copper == roundi(3 * 1.05), "Removing a building removes one unit of its price inflation")
	game.remove_building(Vector2i(29, 25))
	check(game.building_cost("wall").copper == base, "Removing all buildings of a type restores its base price")
	# First and second research layers and their live effects.
	fresh()
	game.tutorial.skip_to_ready()
	game.tutorial.tech_available = true
	check(game.TECH.barriers.cost == {"scrap": 3, "copper": 20}, "Barrier research costs three scrap and twenty copper")
	check(game.hud.visible_tech_ids() == ["barriers"], "Only Barriers is initially available in the tree")
	game.inventory.copper = 40
	game.inventory.scrap = 20
	game.research("barriers")
	check(game.hud.visible_tech_ids().has("conveyor_speed") and game.hud.visible_tech_ids().has("turret_range") and not game.hud.visible_tech_ids().has("industry"), "Second layer exposes conveyor speed and Solar range before the remaining branches")
	check(game.TECH.conveyor_speed.cost == {"scrap": 5, "copper": 25} and game.TECH.turret_range.cost == {"scrap": 7, "copper": 30}, "Second-layer research has the requested resource costs")
	check(game.conveyor_items_per_second() == 1 and game.turret_range("solar") == 96, "Conveyors and Solar start with their base speed and range")
	game.inventory.copper = 40
	game.research("conveyor_speed")
	check(game.conveyor_items_per_second() == 2 and game.researched.has("conveyor_speed"), "Conveyor research doubles throughput")
	game.inventory.copper = 40
	game.research("turret_range")
	check(game.turret_range("solar") == 160 and game.turret_range("turret") == 256, "Range research adds two tiles to Solar only")
	game._add_building(Vector2i(25, 24), "belt", 0)
	game._add_building(Vector2i(26, 24), "belt", 0)
	game.buildings[Vector2i(25, 24)].item = "copper"
	game._update_items(0.5)
	check(game.buildings[Vector2i(26, 24)].item == "copper", "Upgraded cargo crosses one belt in half a second")
	game.hud.show_tech_tree()
	game.hud.close_modal()
	await process_frame
	game.hud.refresh()
	check(game.hud.category_buttons.Infrastructure.get_meta("tutorial_glow") and game.hud.category_buttons.Defence.get_meta("tutorial_glow"), "Closing researched Barriers starts both category glows")
	game.hud.toggle_category("Infrastructure")
	check(not game.hud.category_buttons.Infrastructure.get_meta("tutorial_glow") and game.hud.category_buttons.Defence.get_meta("tutorial_glow"), "Each category glow clears independently when clicked")
	game.hud.toggle_category("Defence")
	check(not game.hud.category_buttons.Defence.get_meta("tutorial_glow"), "Both category glows finish after visiting both menus")
	check(game.textures.belt_dark != null and game.textures.belt_corner_dark != null, "Both belt shapes have darker pre-upgrade graphics")
	# Credit-first deterministic spawning and tank rewards.
	game.wave = 4
	var small: Dictionary = game.create_enemy("scout", Vector2.ZERO, "red")
	var heavy: Dictionary = game.create_enemy("heavy", Vector2.ZERO, "red")
	check(game.Content.ENEMY_TYPES.scout.credits == 1 and game.Content.enemy_scrap("scout") == 1, "Small tanks cost one enemy credit and drop one scrap")
	check(game.Content.ENEMY_TYPES.heavy.credits == 8 and game.Content.enemy_scrap("heavy") == 8 and heavy.max_hp == floor(small.max_hp * 8 * 0.33 / 10) * 10, "Heavy tanks cost and drop eight, with eight times small-tank health")
	var gate = game.active_spawners[0]
	gate.credits_per_wave = PackedInt32Array([19])
	gate.allowed_enemies = PackedStringArray(["scout", "runner", "heavy"])
	gate.waves_completed = 0
	game._prepare_colors(4)
	game._plan_wave()
	check(game.spawn_queue.size() >= 3 and game.spawn_queue[0].kind == "heavy" and game.spawn_queue[1].kind == "heavy", "Spawner buys as many highest-cost eligible enemies as possible first")
	var spent := 0
	var cheaper := true
	for i in game.spawn_queue.size():
		spent += game.Content.ENEMY_TYPES[game.spawn_queue[i].kind].credits
		if i >= 2: cheaper = cheaper and game.spawn_queue[i].kind != "heavy"
	check(spent == 19 and cheaper, "Remaining credits are spent only on cheaper enemies")
	var roster: Array = game.spawn_queue.duplicate(true)
	game._plan_wave()
	check(game.spawn_queue == roster, "Greedy-first rosters remain deterministic for a wave seed")
	# New ages freeze on opening and collection has its own short sound.
	var browser = game.hud.save_browser
	check(browser.age_text(10) == "Just now" and browser.age_text(65) == "1m ago" and browser.age_text(3665) == "1h 1m ago", "Rollback ages omit the seconds counter")
	check(game.audio.streams.has("collect") and game.audio.streams.collect.get_length() < 0.1, "Mining and scrap collection use a short generated collection sound")
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.wave = 1
	game.wave_in_progress = true
	game._complete_wave()
	var saved: Array = game.saves.snapshot().duplicate(true)
	game.tutorial.demolish_completed = false
	check(game.saves.restore(game.saves.current) and game.saves.snapshot() == saved and game.paused, "Snapshots preserve the new tutorial and research state")
	browser.show_browser()
	var opened: int = browser.opened_at
	browser.update_ages()
	check(browser.opened_at == opened, "Rollback ages use one frozen opening timestamp")
	for entry in game.saves.entries:
		DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
		if FileAccess.file_exists(game.saves.preview_path(entry.file)): DirAccess.remove_absolute(game.saves.preview_path(entry.file))
	game.free()
	print("DESIGNATED TUTORIAL CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)







