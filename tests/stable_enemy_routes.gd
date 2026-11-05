extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var actor: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(8, 25)), "red")
	actor.windup = 0
	actor.cooldown = 999
	game.enemies.append(actor)
	for y in range(23, 27): game.rocks[Vector2i(15, y)] = true
	game.enemy_navigation.invalidate(game)
	game._update_enemies(0.05)
	check(actor.navigation.has("path") and actor.navigation.path.size() > 2, "Enemy owns its complete route")
	actor.navigation.stability_token = 1234
	var destination: Vector2 = actor.navigation.destination
	var visited: Array[Vector2i] = []
	for i in 100:
		game._update_enemies(0.05)
		var cell := Vector2i((actor.pos / game.TILE).floor())
		if visited.is_empty() or visited[-1] != cell: visited.append(cell)
	check(actor.navigation.get("stability_token", 0) == 1234 and actor.navigation.destination == destination, "Periodic updates retain chosen route and firing destination")
	var bounced := false
	for i in range(3, visited.size()):
		if visited[i] == visited[i - 2] and visited[i - 1] == visited[i - 3]: bounced = true
	check(not bounced and visited.size() >= 3, "Walking route advances without alternating between the same two tiles")
	for i in 1200:
		game._update_enemies(0.05)
		var cell := Vector2i((actor.pos / game.TILE).floor())
		if visited.is_empty() or visited[-1] != cell: visited.append(cell)
	check(game.visible_enemy_objective(actor) == game.current_core, "Stable route reaches firing range around the wall")
	bounced = false
	for i in range(3, visited.size()):
		if visited[i] == visited[i - 2] and visited[i - 1] == visited[i - 3]: bounced = true
	check(not bounced, "Obstacle traversal does not bounce between two tiles")
	var original: Dictionary = actor.navigation.duplicate(true)
	var waypoint: Vector2i = original.path[mini(original.path_index + 1, original.path.size() - 1)]
	game.rocks[waypoint] = true
	game.enemy_navigation.invalidate(game)
	game._update_enemies(0.05)
	check(actor.navigation.get("stability_token", 0) != 1234 and actor.navigation.revision == game.enemy_navigation.signature, "A blocked route still triggers replanning")
	game.rocks.erase(waypoint)
	game.enemy_navigation.invalidate(game)
	game._update_enemies(0.05)
	var saved: Dictionary = actor.navigation.duplicate(true)
	actor.pos += Vector2(0, 64)
	var resumed: Dictionary = game.enemy_navigation.resume_destination(game, actor, saved)
	check(not resumed.is_empty() and resumed.destination == saved.destination and resumed.target == saved.target, "After a separation detour a tank can resume its original destination")
	print("STABLE ENEMY ROUTE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

