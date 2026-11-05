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
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.ores.clear()
	game.buildings.clear()
	game.occupied.clear()
	game.enemies.clear()
	game.current_core = Vector2i(25, 25)
	game.cores.assign([game.current_core])
	game._add_building(game.current_core, "core", 0)
	game.fog_disabled = true
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.onboarding_completed = true
	game.tutorial.pause_exit_completed = true
	game.tutorial.first_wave_completed = true
	game.tutorial.waves_started = true
	game.inventory.copper = 1000
	game.inventory.iron = 1000
	game.inventory.scrap = 1000
	game.base_copper_capacity = 1000
func run() -> void:
	fresh()
	check(game.BUILDINGS.solar.damage == 2 and game.BUILDINGS.turret.name == "Iron Slugger" and game.BUILDINGS.turret.damage == 50 and game.BUILDINGS.turret.reload == 4.0 and game.BUILDINGS.turret.ammo == "iron" and game.footprint_size("turret") == 2, "Solar and Iron Slugger have the new combat stats and footprint")
	check(game.TECH.weapons.cost == {"iron": 5, "scrap": 70} and game.TECH.splitter.cost == {"copper": 35} and game.BUILDINGS.splitter.cost == {"copper": 5}, "Slugger and splitter research/building prices match")
	check(game.conveyor_items_per_second() == 0.25 and game.Content.ENEMY_TYPES.heavy.speed == 14.5, "Belts run at one item per four seconds and heavies move at half speed")
	check(game.enemy_health("scout", 1) == 9 and game.enemy_health("heavy", 1) == 27 and game.enemy_health("bulwark", 1) == 216, "Enemy health is tripled after rounding")
	var info = load("res://scripts/structure_info.gd")
	check(info.description(game, "core") == "Defend at all costs." and not info.stats(game, "core").contains("capacity") and not info.stats(game, "core").contains("radius"), "Core tooltip has the requested description and no radius/capacity stats")
	check(info.stats(game, "drill").contains("Extraction: 0.1") and info.stats(game, "belt").contains("0.25 items"), "Info reflects slower production and transport")
	var deposit := Vector2i(20, 25)
	game.ores[deposit] = "iron"
	game._add_building(deposit, "drill", 0)
	game.simulate(9.9)
	check(game.buildings[deposit].item == "", "Extractor waits ten seconds")
	game.simulate(0.1)
	check(game.buildings[deposit].item == "iron", "Extractor produces at ten seconds")
	game.research("splitter", true)
	var junction := Vector2i(22, 25)
	game._add_building(junction, "belt", 0)
	game.buildings[junction].paid_cost = {"copper": 1}
	check(game.place_building(junction, "splitter", 0) and game.buildings[junction].kind == "splitter", "Splitter placement dismantles an existing belt")
	game._add_building(junction + Vector2i.RIGHT, "belt", 0)
	game._add_building(junction + Vector2i.DOWN, "belt", 1)
	game.buildings[junction + Vector2i.RIGHT].item = "copper"
	var splitter: Dictionary = game.buildings[junction]
	splitter.item = "iron"
	splitter.route_dir = 0
	splitter.next_output = 0
	game.update_splitter_route(junction, splitter)
	check(splitter.route_dir == 1, "Multi-output structures skip filled output belts")
	splitter.travel = 0.0
	game._update_items(3.9)
	check(splitter.item == "iron", "Transport does not hand off early")
	game._update_items(0.1)
	check(game.buildings[junction + Vector2i.DOWN].item == "iron", "Transport hands off after four seconds")
	fresh()
	game.wave = 4
	game.inventory.copper = game.material_capacity("copper")
	game.research("barriers", true)
	game.tutorial.tech_available = true
	game.tutorial.tech_opened = true
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow"), "Full copper at wave four highlights research even if it was opened before")
	game.hud.show_tech_tree()
	check(game.hud.tech_buttons.turret_range.button.get_meta("tutorial_glow"), "Storage hint first highlights Solar range")
	game.research("turret_range", true)
	game.inventory.copper = 1
	game.hud._rebuild_tech_nodes()
	check(game.tutorial.storage_hint_tech() == "copper_storage" and not game.hud.tech_buttons.copper_storage.button.get_meta("tutorial_glow"), "Storage hint stays latched but waits for affordable Copper Storage")
	game.research("copper_storage", true)
	game.hud.refresh()
	check(not game.hud.tech_button.get_meta("tutorial_glow"), "Buying Copper Storage ends its hint")
	var view = game.hud.tech_scroll
	view.left_pending = true
	view.left_origin = Vector2.ZERO
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(30, 30)
	motion.relative = Vector2(30, 30)
	view._input(motion)
	check(view.panning and view.pan_button == MOUSE_BUTTON_LEFT, "Left drag pans the tech tree")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	view._input(release)
	check(not view.panning and not view.left_pending, "Releasing left drag stops panning without purchasing a tech")
	game.hud.close_modal()
	await process_frame
	fresh()
	var gate = game.spawners[0]
	var core := Vector2i(60, 25)
	gate.position = game.cell_center(core)
	gate.converted = true
	gate.turns_into_core = true
	gate.core_resource_price_increase.copper = 100
	gate.core_resource_price_increase.iron = 50
	gate.core_resource_price_increase.scrap = 200
	game._add_building(core, "core", 0)
	game.cores.append(core)
	game.current_core = core
	check(game.core_should_glow(core), "New core glows before construction")
	check(game.building_cost("solar", 0, core + Vector2i.RIGHT).copper == 20 and game.building_cost("copper_store", 0, core + Vector2i.RIGHT).scrap == 30, "Core-specific resource percentages multiply base costs")
	check(game.building_cost("solar", 0, Vector2i(26, 25)).copper == 10, "Original core keeps its original base prices")
	game._add_building(core + Vector2i.RIGHT, "belt", 0)
	check(not game.core_should_glow(core), "Building in the core range ends its world/minimap glow")
	game.inventory.copper = 0
	check(game.building_cost("drill", 0, core + Vector2i.DOWN).iron == 8, "Iron substitution uses the core's iron price modifier")
	fresh()
	game.research("weapons", true)
	var ore := Vector2i(19, 25)
	var tower := Vector2i(30, 25)
	game.ores[ore] = "iron"
	game.ores[Vector2i(15, 25)] = "iron"
	check(game.place_building(tower, "turret", 0), "Iron Slugger is placeable after research")
	check(game.tutorial.ammo_guide_extractor == ore and not game.tutorial.ammo_guide_path.is_empty(), "Ammo guide shows the closest iron deposit and a ghost extractor")
	game._add_building(ore, "drill", 0)
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_guide_extractor == game.INVALID, "Building the required extractor removes its ghost")
	var path: Array = game.tutorial.ammo_guide_path.duplicate()
	for index in path.size() - 1:
		var cell: Vector2i = path[index]
		game._add_building(cell, "belt", game.direction_for(path[index + 1] - cell))
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_tutorial_stage == 3 and game.tutorial.ammo_guide_path.is_empty() and not game.tutorial.central_message().contains("ammo"), "Connecting an iron extractor to any Slugger footprint tile completes the lesson")
	var first: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(32, 23)), "red")
	var second: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(32, 27)), "red")
	var shared: Vector2 = game.cell_center(Vector2i(31, 25))
	for enemy in [first, second]:
		enemy.windup = 0.0
		enemy.cooldown = 100.0
		enemy.navigation_timer = 1.0
		enemy.intended_pos = shared
		enemy.navigation = {"target": tower, "waypoint": shared, "destination": shared, "cost": 1.0}
		game.enemies.append(enemy)
	game._update_enemies(0.01)
	check(first.intended_pos.distance_to(second.intended_pos) >= 36, "Overlapping intended destinations trigger a distinct new reservation")
	check(not game.textures.solar.get_image().has_mipmaps() and not game.textures.copper_store.get_image().has_mipmaps(), "Pixel sprites use a single crisp raster level")
	print("IRON SUPPLY ZOOM CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)




