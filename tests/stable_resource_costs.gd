extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	for kind in ["solar", "drill"]:
		for count in [0, 10]:
			game.inventory.copper = 1000
			game.inventory.iron = 0
			var price: Dictionary = game.building_cost(kind, count)
			game.inventory.copper = 0
			game.inventory.iron = 1000
			check(game.building_cost(kind, count) == price and price.keys() == ["copper"], "Copper price remains stable with plentiful iron and no copper")
	game.inventory.copper = 8
	game.inventory.iron = 30
	check(game.building_cost("solar", 0) == {"copper": 10}, "Solar quote matches the reported low-copper scenario")
	check(not game.place_building(Vector2i(26, 25), "solar", 0) and game.inventory.iron == 30 and game.inventory.copper == 8, "Insufficient copper blocks placement without spending iron")
	game.inventory.copper = 10
	check(game.place_building(Vector2i(26, 25), "solar", 0) and game.inventory.copper == 0 and game.inventory.iron == 30, "Affordable Solar placement spends only copper")
	check(game.building_cost("turret", 0) == {"copper": 35, "iron": 12}, "Buildings designed to use both resources retain their mixed price")
	print("STABLE RESOURCE COST CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
