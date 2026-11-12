extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.Content.ENEMY_TYPES.heavy.scrap == 2 and game.Content.ENEMY_TYPES.bulwark.scrap == 4 and game.Content.ENEMY_TYPES.siege.scrap == 8 and game.enemy_health("siege", 1) == 210 and game.Content.ENEMY_TYPES.siege.damage == 40, "Enemy scrap and Siege balance updated")
	check(game.TECH.refining.parent == "weapons" and game.TECH.refining.cost == {"iron": 35, "scrap": 200}, "Refinery follows Slugger with requested research price")
	check(game.TECH.iron_storage.parent == "refining" and game.TECH.iron_storage.cost == {"pink": 6, "scrap": 75} and game.BUILDINGS.iron_store.cost == {"iron": 40}, "Iron silo tech and construction prices")
	var refinery := Vector2i(20, 25)
	var belt := Vector2i(22, 25)
	game._add_building(refinery, "refinery", 0)
	game._add_building(belt, "belt", 0)
	var machine: Dictionary = game.buildings[refinery]
	game._add_building(Vector2i(19, 25), "belt", 0)
	game._add_building(Vector2i(20, 24), "belt", 1)
	game.buildings[Vector2i(19, 25)].item = "copper"
	game.buildings[Vector2i(20, 24)].item = "iron"
	game._update_items(2.1)
	game._update_items(0.01)
	check(machine.buffer.copper == 1 and machine.buffer.iron == 1, "Conveyors supply both refinery inputs")
	machine.buffer.copper = 5
	machine.buffer.iron = 5
	check(not game.can_receive(refinery, "copper") and not game.can_receive(refinery, "iron"), "Refinery inputs capped at five each")
	game.advance_logistics(2.95)
	check(machine.progress > 2.9 and game.buildings[belt].item == "", "Refining takes three seconds")
	game.advance_logistics(0.05)
	check(machine.buffer.copper == 4 and machine.buffer.iron == 4 and game.buildings[belt].item == "pink", "Refinery consumes one of each and spits pink onto an outgoing belt")
	game.buildings[belt].item = "iron"
	game._add_building(Vector2i(22, 26), "belt", 0)
	game.advance_logistics(3)
	check(game.buildings[Vector2i(22, 26)].item == "pink", "Refinery skips blocked output and uses another edge port")
	machine.progress = 1.25
	game.saves.capture()
	check(game.saves.restore(game.saves.current) and game.buildings[refinery].progress == 1.25 and game.buildings[refinery].buffer.copper == 3, "Refinery buffers and partial cycle survive save/load")
	fresh()
	game._add_building(Vector2i(24, 25), "belt", 0)
	game.buildings[Vector2i(24, 25)].item = "pink"
	game._update_items(2.1)
	check(game.inventory.pink == 1 and game.discovered_resources.has("pink"), "Pink is deposited into core inventory and discovered")
	var tower := Vector2i(26, 25)
	game._add_building(tower, "turret", 0)
	var turret: Dictionary = game.buildings[tower]
	# Use the turret's lower edge, avoiding the core footprint.
	game._add_building(Vector2i(26, 27), "belt", 3)
	game.buildings[Vector2i(26, 27)].item = "pink"
	game._update_items(2.1)
	check(turret.booster_count == 1 and turret.booster_type == "pink" and turret.ammo == 8, "Booster deliveries use a separate turret slot without spending ammo")
	turret.booster_count = 10
	check(not game.can_receive(tower, "pink"), "Turret booster capacity is ten")
	turret.booster_count = 1
	turret.booster_type = "another_booster"
	check(not game.can_receive(tower, "pink"), "Different booster types cannot mix")
	turret.booster_type = "pink"
	turret.booster_count = 10
	game.enemies.assign([game.create_enemy("siege", game.building_center(tower) + Vector2(100, 0), "red")])
	for step in 19: game._update_turret(tower, turret, 0.1)
	check(game.shots.is_empty(), "Boosted Slugger still winds up before firing")
	game._update_turret(tower, turret, 0.1)
	check(game.shots.size() == 1 and turret.booster_count == 10 and turret.ammo == 7, "Pink halves the Slugger firing interval without consuming a booster per shot")
	game.saves.capture()
	turret.booster_count = 0
	check(game.saves.restore(game.saves.current) and game.buildings[tower].booster_count == 10, "Booster slots survive save/load")
	fresh()
	game._add_building(tower, "solar", 0)
	var solar: Dictionary = game.buildings[tower]
	solar.booster_type = "pink"
	solar.booster_count = 2
	game.enemies.assign([game.create_enemy("siege", game.building_center(tower) + Vector2(60, 0), "red")])
	game._update_turret(tower, solar, 0.01)
	game._update_turret(tower, solar, 0.5)
	check(game.shots.size() == 2 and solar.booster_count == 2 and solar.booster_type == "pink", "Ammo-free Solar also boosts to twice its firing rate without per-shot consumption")
	fresh()
	game._add_building(Vector2i(26, 25), "iron_store", 0)
	var silo: Dictionary = game.buildings[Vector2i(26, 25)]
	check(game.material_capacity("iron") == 80, "Passive silo adds forty storage without fuel")
	check(not game.can_receive(Vector2i(26, 25), "pink"), "Passive silo rejects fuel")
	silo.buffer.pink = 2
	game.advance_logistics(90)
	check(silo.buffer.pink == 2 and game.material_capacity("iron") == 80, "Legacy fuel has no effect on silo operation")
	print("PINK REFINING CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
