extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func fresh(starter: bool = false) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.fog_disabled = true
	if not starter:
		game.tutorial.stage = game.tutorial.Stage.READY
		game.tutorial.onboarding_completed = true
		game.tutorial.pause_exit_completed = true
		game.tutorial.first_wave_completed = true
		game.inventory.copper = 1000
		game.inventory.iron = 1000
		game.inventory.scrap = 1000
func run() -> void:
	fresh()
	check(game.TECH.auto_scrap.cost == {"copper": 10} and game.TECH.auto_scrap.icon == "scrap_item", "Auto Pickup has its new cost and scrap icon")
	check(game.TECH.build_hotkeys.cost == {"copper": 10}, "Build Menu Hotkeys has its new cost")
	check(game.TECH.splitter.parent == "copper_storage" and game.TECH.weapons.parent == "copper_storage", "Copper Storage leads to Splitter and Copper ballistics")
	for tech in ["barriers", "conveyor_speed", "turret_range", "copper_storage"]: game.research(tech, true)
	game.tutorial.tech_available = true
	game.hud.refresh()
	game.hud.toggle_category("Infrastructure")
	game.hud.show_tech_tree()
	var centered := true
	for id in game.hud.tech_buttons:
		var children: Array[String] = []
		for child in game.hud.tech_buttons:
			if game.TECH[child].parent == id: children.append(child)
		if children.is_empty(): continue
		var mean := 0.0
		for child in children: mean += game.TECH[child].pos.x + 108
		centered = centered and is_equal_approx(mean / children.size(), game.TECH[id].pos.x + 108)
	check(centered, "Every visible sibling group is centered under its parent")
	check(game.hud.modal.z_index > game.hud.card_views.drill.amounts.copper.z_index, "Research modal covers building-menu price layers")
	var view = game.hud.tech_scroll
	view.zoom_at(0.01, view.size / 2)
	check(is_equal_approx(view.zoom, 0.35), "Tech tree can zoom out to its minimum scale")
	view.zoom_at(100, view.size / 2)
	await process_frame
	view.scroll_horizontal = 999999
	view.scroll_vertical = 999999
	view.layout_graph()
	check(view.scroll_horizontal <= maxi(0, ceili(view.bounds.size.x * view.zoom - view.size.x + 16)) and view.scroll_vertical <= maxi(0, ceili(view.bounds.size.y * view.zoom - view.size.y + 16)), "Tech panning stays within the visible frontier bounds")
	game.hud.close_modal()
	await process_frame
	var origin: Vector2i = game.current_core
	game._add_building(origin + Vector2i(0, 4), "copper_store", 0)
	game._add_building(origin + Vector2i(3, 4), "copper_store", 0)
	var next: Vector2i = origin + Vector2i(32, 0)
	game._add_building(next, "core", 0)
	game.cores.append(next)
	game.current_core = next
	check(game.building_cost("copper_store", -1, next).scrap == 12 and game.building_cost("copper_store", -1, origin).scrap == 12, "Scrap inflation counts structures globally across core zones")
	check(game.footprint_size("copper_store") == 2 and game.anchor_at(origin + Vector2i(1, 5)) == origin + Vector2i(0, 4), "Copper silos occupy all four tiles of a two-by-two footprint")
	game.blueprint.assign([{"kind": "copper_store", "offset": Vector2i.ZERO}, {"kind": "copper_store", "offset": Vector2i(3, 0)}])
	check(game.blueprint_cost(next + Vector2i(0, 3)).scrap == 25, "Blueprint scrap costs apply sequential global inflation")
	game.blueprint.clear()
	check(game.enemy_health("bulwark", 7) == 108 and game.Content.ENEMY_TYPES.bulwark.credits == 40, "Bulwark costs forty credits and scales to twenty scout health")
	check(is_equal_approx(game.Content.ENEMY_TYPES.bulwark.damage / game.Content.ENEMY_TYPES.bulwark.reload, game.Content.ENEMY_TYPES.scout.damage / game.Content.ENEMY_TYPES.scout.reload * 2) and game.Content.ENEMY_TYPES.bulwark.reload == 2, "Bulwark deals twice scout DPS at a two-second interval")
	check(game.Content.enemy_scrap("bulwark") == 12 and game.Content.enemy_scrap("heavy") == 4 and game.BUILDINGS.wall.hp == 2750, "Enemy salvage and five-times barrier health match the rebalance")
	var tiers = preload("res://scripts/scrap_tiers.gd")
	check(tiers.split(1281) == [1000, 200, 50, 20, 5, 5, 1], "Scrap rewards decompose from largest to smallest denomination")
	game.scraps.clear()
	var point: Vector2 = game.cell_center(next)
	game.spawn_scrap(1281, point)
	check(game.scraps.size() == 7 and game.scraps[0].value == 1000 and game.textures.has("scrap_1000_item"), "Colored tier assets and physical drop values are available")
	var distinct_speeds: Dictionary = {}
	for pile in game.scraps: distinct_speeds[roundi(pile.velocity.length())] = true
	check(distinct_speeds.size() > 1, "Scrap bursts have randomized initial speeds")
	for frame in 100: game.collect_scrap(0.02, point + Vector2(640, 0), false)
	var settled := true
	for pile in game.scraps: settled = settled and pile.velocity == Vector2.ZERO and pile.pos.distance_to(point) <= 64
	check(settled, "Scrap burst velocity decays to zero within two tiles")
	game.scraps.clear()
	game.inventory.scrap = 499
	game.spawn_scrap(20, point)
	game.collect_scrap(0.01, point)
	var remainder := 0
	for pile in game.scraps: remainder += pile.amount
	check(game.inventory.scrap == 500 and remainder == 19, "Partial tier pickup conserves currency when capacity is reached")
	game.audio.muted = false
	game.audio.cooldowns.clear()
	game.audio.play("collect")
	var voice: int = game.audio.ui_index
	game.audio.play("collect")
	game.audio._process(0.19)
	game.audio.play("collect")
	check(game.audio.ui_index == voice, "Collection sound cannot repeat within 0.2 seconds")
	game.audio._process(0.02)
	game.audio.play("collect")
	check(game.audio.ui_index != voice, "Collection sound becomes available after its cooldown")
	fresh()
	game.inventory.iron = 0
	game.selected = ""
	var ore: Vector2i = game.current_core + Vector2i(0, 3)
	game.ores[ore] = "iron"
	game.update_manual_mining(4.9, ore, true)
	check(game.inventory.iron == 0, "Hand mining iron waits five seconds")
	game.update_manual_mining(0.11, ore, true)
	check(game.inventory.iron == 1, "Hand mining iron produces one ore per five seconds")
	var far: Vector2i = game.current_core + Vector2i(0, -21)
	game.ores[far] = "copper"
	game.update_manual_mining(1, far, true)
	check(game.hud.feedback_labels[-1].text == "Too far away...", "Mining outside a core range gives distance feedback")
	game._add_building(ore, "drill", 0)
	game._add_building(ore + Vector2i.RIGHT, "belt", 0)
	game.simulate(9.9)
	check(game.buildings[ore].item == "", "Extractors wait the full ten-second extraction interval")
	game.simulate(0.11)
	check(game.buildings[ore].item == "iron", "Extractors produce one material after ten seconds")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hover_cell = game.current_core
	game.hud._refresh_tooltip(game.get_canvas_transform() * game.cell_center(game.current_core))
	check(game.hud.hovered_core == game.current_core and game.hud.tooltip.visible, "Alt hovering a core selects its build-radius overlay")
	alt.pressed = false
	Input.parse_input_event(alt.duplicate())
	Input.flush_buffered_events()
	fresh(true)
	var drill := Vector2i(20, 22)
	game.ores[drill] = "copper"
	game.add_resource("copper", 5)
	game.place_building(drill, "drill", 0)
	game.add_resource("copper", 2)
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	check(game.tutorial.has_extractor_connection() and not game.unlocked("solar") and game.tutorial.central_message() == "Mine some more ore.", "Connected starter conveyors request more ore before Solar is affordable")
	check(not game.tutorial.menu_should_glow(), "Building buttons do not glow while waiting for tower resources")
	game.add_resource("copper", 9)
	check(not game.unlocked("solar"), "Solar remains locked below its full cost")
	game.add_resource("copper", 1)
	check(game.unlocked("solar") and game.tutorial.menu_should_glow() and game.tutorial.building_should_glow("solar"), "Reaching the tower cost unlocks Solar and restarts both glows")
	game.place_building(game.current_core + Vector2i(8, 0), "solar", 0)
	game.tutorial.pause_exit_completed = true
	for tech in ["barriers", "conveyor_speed", "copper_storage", "weapons"]: game.research(tech, true)
	game.inventory.copper = 500
	game.inventory.iron = 500
	game.ores[drill] = "iron"
	var tower: Vector2i = game.current_core + Vector2i(8, 3)
	check(game.place_building(tower, "turret", 0), "Copper ballistics makes the next tower placeable with its red color")
	check(game.tutorial.central_message() == "Some turrets require ammo.\nHold Alt over a turret to see its ammo type" and not game.tutorial.ammo_guide_path.is_empty(), "The first ammunition turret introduces ammo and a conveyor ghost path")
	check(game.tutorial.ammo_guide_path[0].distance_to(drill) == 1 and game.anchor_at(game.tutorial.ammo_guide_path[-1]) == tower, "Ammo guide connects the nearest extractor to the tower")
	game.hover_cell = tower
	alt.pressed = true
	Input.parse_input_event(alt.duplicate())
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.get_canvas_transform() * game.cell_center(tower))
	check(game.tutorial.ammo_tutorial_stage == 2 and game.hud.tooltip_body.get_parsed_text().contains("Ammo:"), "Inspecting a placed ammunition turret completes the ammo text")
	alt.pressed = false
	Input.parse_input_event(alt.duplicate())
	Input.flush_buffered_events()
	var path: Array = game.tutorial.ammo_guide_path.duplicate()
	for index in path.size() - 1:
		var cell: Vector2i = path[index]
		var direction: int = game.direction_for(path[index + 1] - cell)
		if game.buildings.has(cell): game.buildings[cell].dir = direction
		else: game.place_building(cell, "belt", direction)
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_tutorial_stage == 3 and game.tutorial.ammo_guide_path.is_empty(), "Connecting the supply path finishes its guide")
	fresh()
	game.inventory.copper = 0
	var first: Dictionary = game.create_enemy("heavy", game.cell_center(game.current_core + Vector2i(5, -1)), "red")
	var second: Dictionary = game.create_enemy("heavy", game.cell_center(game.current_core + Vector2i(5, 1)), "red")
	var shared: Vector2 = game.cell_center(game.current_core + Vector2i(4, 0))
	for actor in [first, second]:
		actor.windup = 0.0
		actor.cooldown = 100.0
		actor.intended_pos = shared
		actor.navigation_timer = 1.0
		actor.navigation = {"target": game.current_core, "waypoint": shared, "destination": shared, "cost": 1.0}
		game.enemies.append(actor)
	first.navigation_timer = 0.0
	second.navigation_timer = 0.0
	game._update_enemies(0.05)
	check(first.intended_pos.distance_to(second.intended_pos) >= 36, "Conflicting intended firing positions force a fresh non-overlapping reservation")
	check(not game.enemy_goal_available(second.intended_pos, first), "A reserved position is unavailable to other enemies")
	first.pos = second.intended_pos
	first.navigation_timer = 1.0
	game.enemies.reverse() # Process the actor occupying the reservation before its owner can move it.
	game._update_enemies(0.01)
	check(first.navigation_timer > 0.25, "Passing through another enemy's destination does not force constant rerouting")
	var third: Dictionary = game.create_enemy("bulwark", first.pos, "red")
	third.windup = 0.0
	third.cooldown = 100.0
	game.enemies.append(third)
	for tick in 150: game._update_enemies(0.03)
	var separated := true
	var reserved := true
	for a in game.enemies:
		for b in game.enemies:
			if a.info_id == b.info_id: continue
			var minimum: float = (game.Content.ENEMY_TYPES[a.kind].size + game.Content.ENEMY_TYPES[b.kind].size) / 2.0
			separated = separated and a.pos.distance_to(b.pos) >= minimum - 0.5
			if a.has("intended_pos") and b.has("intended_pos"): reserved = reserved and a.intended_pos.distance_to(b.intended_pos) >= minimum
	check(game.enemies.size() == 3, "Passing enemies remain active while heading toward separate destinations")
	check(reserved, "Moving enemies maintain distinct intended positions")
	print("RESEARCH SCRAP SPACING CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)


