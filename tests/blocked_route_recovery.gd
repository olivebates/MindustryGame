extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	for x in range(21, 30):
		for y in range(21, 30):
			if x in [21, 29] or y in [21, 29]: game.rocks[Vector2i(x, y)] = true
	var additions := 0
	for x in range(22, 29):
		for y in range(22, 29):
			if Vector2i(x, y) == game.current_core or additions >= 40: continue
			game._add_building(Vector2i(x, y), "drill", 0)
			additions += 1
	game.enemy_navigation.invalidate(game)
	for i in 30:
		var actor: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(6 + i % 5, 20 + i / 5)), "red")
		actor.windup = 0
		actor.cooldown = 999
		game.enemies.append(actor)
	var worst := 0
	var total := 0
	for frame in 90:
		var started := Time.get_ticks_usec()
		game.enemy_navigation.begin_frame()
		game._update_enemies(0.016)
		game.enemy_navigation.end_frame()
		var duration := Time.get_ticks_usec() - started
		total += duration
		worst = maxi(worst, duration)
	check(game.enemy_navigation.components_ready and game.enemy_navigation.paths.is_empty(), "Unreachable targets are rejected before running AStar")
	var stopped := true
	for actor in game.enemies: stopped = stopped and actor.get("navigation", {}).is_empty()
	check(stopped, "No false route is returned through sealed rock walls")
	print("BLOCKED NAVIGATION TIMING: mean %.2f ms, worst %.2f ms" % [total / 90000.0, worst / 1000.0])
	var actor: Dictionary = game.enemies[0]
	game.enemies.assign([actor])
	for cell in game.buildings.keys():
		if game.buildings[cell].kind == "drill": game.remove_building(cell, false)
	game.rocks.erase(Vector2i(21, 25))
	game.enemy_navigation.invalidate(game)
	game._update_enemies(0.05)
	check(not actor.navigation.is_empty() and actor.navigation.target == game.current_core, "Opening a path immediately invalidates failure cache")
	for tick in 300: game._update_enemies(0.05)
	check(game.visible_enemy_objective(actor) == game.current_core, "Enemy reaches firing range through the opened route")
	fresh()
	var front := Vector2i(23, 25)
	for x in range(23, 28):
		for y in range(23, 28):
			if x in [23, 27] or y in [23, 27]: game._add_building(Vector2i(x, y), "wall", 0)
	actor = game.create_enemy("scout", game.cell_center(Vector2i(20, 25)), "red")
	actor.windup = 0
	actor.cooldown = 0
	game.enemies.append(actor)
	game._update_enemies(0.05)
	check(not actor.navigation.is_empty() and game.buildings[actor.navigation.target].kind == "wall", "An enclosed core makes enemies approach its blocking barriers")
	for tick in 400: game._update_enemies(0.05)
	check(not game.buildings.has(front) and actor.navigation.target == game.current_core, "Enemy destroys barrier and resumes moving toward the exposed core")
	check(game.visible_enemy_objective(actor) == game.current_core, "Enemy does not stall after breaking the barrier")
	print("BLOCKED ROUTE RECOVERY CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

