extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.TECH.weapons.cost == {"iron": 5, "scrap": 10}, "Slugger research costs five iron and ten scrap")
	check(game.BUILDINGS.turret.damage == 20 and game.BUILDINGS.turret.reload == 4, "Slugger deals twenty damage every four seconds")
	var cell := Vector2i(26, 25)
	game._add_building(cell, "turret", 0)
	var turret: Dictionary = game.buildings[cell]
	game.enemies.assign([game.create_enemy("siege", game.building_center(cell) + Vector2(100, 0), "red")])
	for step in 39: game._update_turret(cell, turret, 0.1)
	check(game.shots.is_empty() and turret.ammo == 8 and turret.progress > 3.8, "Loaded Slugger winds up without spending ammo or shooting early")
	game._update_turret(cell, turret, 0.1)
	check(game.shots.size() == 1 and game.shots[0].damage == 20 and turret.ammo == 7 and turret.progress == 0, "A completed windup launches a twenty-damage slug and resets")
	game.enemies.clear()
	game._update_turret(cell, turret, 0.2)
	check(turret.progress == 0, "Losing the target clears windup")
	game.enemies.assign([game.create_enemy("siege", game.building_center(cell) + Vector2(100, 0), "red")])
	turret.ammo = 0
	game._update_turret(cell, turret, 1)
	check(turret.progress == 0, "Empty Slugger does not wind up")
	turret.ammo = 7
	turret.progress = 2.5
	game.saves.capture()
	turret.progress = 0
	check(game.saves.restore(game.saves.current) and game.buildings[cell].progress == 2.5, "Windup progress survives a save and restore")
	print("SLUGGER WINDUP CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
