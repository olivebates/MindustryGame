extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var types: Dictionary = game.Content.ENEMY_TYPES
	check(types.scout.speed == 128 and types.heavy.speed == 96 and types.bulwark.speed == 64 and types.siege.speed == 32, "Movement is four/three/two/one tiles per second")
	check(game.enemy_health("heavy", 1) == 20 and types.heavy.damage == 4, "Heavy has twenty HP and four damage")
	check(game.enemy_health("bulwark", 1) == 50 and types.bulwark.damage == 20, "Bulwark has fifty HP and twenty damage")
	check(types.siege.credits == 240 and game.enemy_health("siege", 1) == 140 and types.siege.damage == 60 and types.siege.reload == 7, "Siege has requested price, health and attack stats")
	var enemy: Dictionary = game.create_enemy("siege", game.cell_center(game.current_core) - Vector2(64, 0), "red")
	enemy.windup = 0.0
	game.enemies.assign([enemy])
	var hp: float = game.buildings[game.current_core].hp
	for step in 69: game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == hp and enemy.get("charge", 0.0) > 0.98, "Siege charges for seven seconds before firing")
	game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == hp - 60 and enemy.charge == 0, "Siege hits for sixty and resets its windup")
	for step in 70: game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == hp - 120, "Siege repeats its seven-second attack cycle")
	print("SIEGE REBALANCE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
