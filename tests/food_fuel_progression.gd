extends "res://tests/iron_supply_zoom.gd"
func fresh() -> void:
	super.fresh()
	game.base_copper_capacity = 100
	for resource in game.inventory: game.inventory[resource] = 0
func run() -> void:
	fresh()
	check(game.base_copper_capacity == 100, "Chicken nugget base capacity is one hundred")
	var visual = preload("res://scripts/tower_outlines.gd").new()
	visual.game = game
	game.inventory.copper = 20
	check(visual.needs_material(game.buildings[game.current_core], "copper"), "Core highlights every collectable material even when partly stocked")
	visual.free()
	var solar := Vector2i(20, 25)
	game._add_building(solar, "solar", 0)
	check(game.buildings[solar].max_hp == 30 and game.turret_reload("solar") == 2, "Solar starts at thirty health and a two second interval")
	game.research("barriers", true)
	check(game.hud.visible_tech_ids().has("solar_speed") and game.hud.visible_tech_ids().has("solar_health"), "Both new Solar upgrades appear after researching barriers")
	game.tutorial.tech_available = true
	game.inventory.copper = 9
	game.hud.show_tech_tree()
	game.hud.refresh()
	check(not game.hud.tech_button.get_meta("tutorial_glow", false) and not game.hud.tech_buttons.solar_speed.button.get_meta("tutorial_glow", false), "Speed research stays unlit below its ten-nugget price")
	game.inventory.copper = 10
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow", false) and game.hud.tech_buttons.solar_speed.button.get_meta("tutorial_glow", false), "Affordable attack speed lights the tree button and research card")
	game.hud.close_modal()
	await process_frame
	await process_frame
	check(game.tutorial.storage_hint_tech() == "solar_speed", "First research hint is attack speed")
	game.research("solar_speed", true)
	check(game.turret_reload("solar") == 1 and game.tutorial.storage_hint_tech() == "turret_range", "Attack speed doubles and the next hint is range")
	game.inventory.copper = 15
	game.hud.show_tech_tree()
	game.hud.refresh()
	check(game.hud.tech_button.get_meta("tutorial_glow", false) and game.hud.tech_buttons.turret_range.button.get_meta("tutorial_glow", false), "Range research becomes the next affordable glow")
	game.hud.close_modal()
	await process_frame
	await process_frame
	game.research("solar_health", true)
	check(game.buildings[solar].max_hp == 40 and game.buildings[solar].hp == 40, "Health upgrade adds ten to existing Solar towers")
	check(game.TECH.solar_speed.cost == {"copper": 10} and game.TECH.turret_range.cost == {"copper": 15} and game.TECH.solar_health.cost == {"copper": 30}, "Early upgrade prices match")
	check(game.TECH.copper_storage.parent == "weapons" and game.TECH.copper_storage.core == 3 and game.TECH.copper_storage.cost == {"pink": 5, "copper": 75}, "Nugget storage follows Slugger at core three")
	check(game.BUILDINGS.copper_store.cost == {"pink": 6, "copper": 100}, "Nugget silo construction price matches")
	var silo := Vector2i(18, 28)
	game._add_building(silo, "copper_store", 0)
	check(game.material_capacity("copper") == 100 and game.can_receive(silo, "pink"), "Unfuelled nugget silo is inactive but accepts Pink Stuff")
	game.buildings[silo].buffer.pink = 2
	check(game.material_capacity("copper") == 150, "Fuelled nugget silo adds fifty capacity")
	game.advance_logistics(30)
	check(game.buildings[silo].buffer.pink == 1, "Silo burns one fuel per thirty seconds")
	game.inventory.copper = 150
	game.advance_logistics(30)
	check(game.buildings[silo].buffer.pink == 0 and game.material_capacity("copper") == 100 and game.inventory.copper == 100, "Fuel exhaustion removes extra capacity and clamps stock")
	game._add_building(Vector2i(22, 28), "iron_store", 0)
	game.buildings[Vector2i(22, 28)].buffer.pink = 10
	check(game.material_capacity("iron") == 80 and not game.can_receive(Vector2i(22, 28), "pink"), "Fish-scale silo also uses ten-item fuel buffer")
	var refinery := Vector2i(28, 28)
	game._add_building(refinery, "refinery", 0)
	game.buildings[refinery].buffer.copper = 1
	game.buildings[refinery].buffer.iron = 1
	game.advance_logistics(9.95)
	check(game.buildings[refinery].item == "", "Refinery waits ten seconds")
	game.advance_logistics(0.05)
	check(game.buildings[refinery].item == "pink", "Refinery produces Pink Stuff at ten seconds")
	fresh()
	var healer := Vector2i(20, 25)
	game._add_building(healer, "healer", 0)
	game._add_building(Vector2i(21, 26), "wall", 0)
	game._add_building(Vector2i(22, 25), "wall", 0)
	var corner: Dictionary = game.buildings[Vector2i(21, 26)]
	var outside: Dictionary = game.buildings[Vector2i(22, 25)]
	corner.hp = 1
	outside.hp = 1
	var beacon: Dictionary = game.buildings[healer]
	beacon.buffer.pink = 2
	game._update_healer(healer, beacon, 1)
	check(corner.hp == 2 and outside.hp == 1, "Healer restores one HP in its square including corners, excluding tiles two away")
	corner.hp = corner.max_hp
	game._update_healer(healer, beacon, 100)
	check(beacon.buffer.pink == 2 and beacon.progress == 1, "Healer does not burn fuel without damaged targets")
	corner.hp = 1
	game._update_healer(healer, beacon, 19)
	check(beacon.buffer.pink == 1 and beacon.progress < 0.001, "Twenty seconds of active healing burns one fuel")
	check(game.TECH.healer.parent == "weapons" and game.TECH.healer.cost == {"pink": 5, "iron": 40} and game.BUILDINGS.healer.cost == {"iron": 30, "pink": 6}, "Healer research and construction prices match")
	game.research("weapons", true)
	check(game.hud.visible_tech_ids().has("healer"), "Healing beacon appears as a Slugger child in the tech tree")
	fresh()
	game.tutorial.skip_to_ready()
	game.tutorial.waves_started = true
	game.ores[Vector2i(23, 25)] = "copper"
	game._add_building(Vector2i(23, 25), "drill", 0)
	game._add_building(Vector2i(24, 25), "belt", 0)
	game.inventory.copper = 99
	game.wave_timer = 100
	game.hud.refresh()
	check(game.hud.next_button.text == "Skip", "Button says Skip when capacity is the next event")
	game.paused = true
	game.request_next_wave()
	game.advance_wave_warp(2)
	check(game.inventory.copper == 100 and game.wave == 0 and not game.wave_warp_active and game.wave_timer > 80, "Skip unpauses and stops at first capacity event before launching a wave")
	check(game.hud.feedback_labels.any(func(label): return label.text == "Max capacity..."), "Capacity event displays red floating GUI feedback")
	game.hud.refresh()
	check(game.hud.next_button.text == "Start Early", "Button switches to wave start when stock is already full")
	game.request_next_wave()
	game.advance_wave_warp(2)
	check(game.wave == 1 and game.spawn_remaining > 0, "Next skip starts the wave when no earlier capacity event exists")
	var natural: Image = game.ui_textures.scout_red.get_image()
	var green: Image = game.ui_textures.scout_green.get_image()
	var same := 0
	var different := 0
	for y in natural.get_height():
		for x in natural.get_width():
			if natural.get_pixel(x, y).a <= 0: continue
			if natural.get_pixel(x, y).is_equal_approx(green.get_pixel(x, y)): same += 1
			else: different += 1
	check(different > 0 and same > different * 0.5, "Enemy wave colors fill selected body parts while retaining natural animal colors")
	var icon_a: TextureRect = game.hud.icon(game.hud.root, game.ui_textures.scout_red, Vector2.ZERO, Vector2(32, 32))
	var icon_b: TextureRect = game.hud.icon(game.hud.root, game.ui_textures.siege_blue, Vector2.ZERO, Vector2(32, 32))
	check(icon_a.texture != icon_b.texture, "Forecast icons keep distinct species and selective color textures")
	var previous: Array = game.saves.snapshot().duplicate(true)
	previous[0] = 15
	previous[1][21] = 40
	var solar_row := [Vector2i(15, 15)]
	game._add_building(Vector2i(15, 15), "solar", 0)
	for field in game.saves.BUILD_FIELDS: solar_row.append(game.buildings[Vector2i(15, 15)].get(field))
	solar_row[4] = 20.0
	solar_row[5] = 40.0
	previous[2].append(solar_row)
	var path: String = game.saves.directory.path_join("old_balance.ews")
	game.saves.write_snapshot(path, previous)
	var migrated: Array = game.saves.read_snapshot(path)
	check(not migrated.is_empty() and migrated[1][21] == 100 and migrated[2].back()[4] == 15 and migrated[2].back()[5] == 30, "Old saves gain new capacity and Solar health while preserving damage fraction")
	print("FOOD FUEL PROGRESSION CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
