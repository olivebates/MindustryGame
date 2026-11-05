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
	game.tutorial_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.buildings.clear()
	game.occupied.clear()
	game.current_core = Vector2i(20, 20)
	game.cores.assign([game.current_core])
	game._add_building(game.current_core, "core", 0)
func run() -> void:
	for rock_wall in [false, true]:
		fresh()
		var blocker := Vector2i(21, 20)
		if rock_wall: game.rocks[blocker] = true
		else: game._add_building(blocker, "wall", 0)
		var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(23, 20)), "red")
		enemy.windup = 0.0
		enemy.cooldown = 100.0
		game.enemies.append(enemy)
		check(enemy.pos.distance_to(game.building_center(game.current_core)) < game.Content.ENEMY_TYPES.heavy.reach and not game.enemy_has_line_of_sight(enemy.pos, game.current_core), "A nearby core is blocked by " + ("rock walls" if rock_wall else "barriers"))
		var start: Vector2 = enemy.pos
		game._update_enemies(0.05)
		check(enemy.pos.distance_to(start) > 0.05, "The enemy continues moving despite already being within distance range")
		for tick in 240: game._update_enemies(0.05)
		check(game.enemy_has_line_of_sight(enemy.pos, game.current_core) and game.visible_enemy_objective(enemy) == game.current_core, "Pathfinding finds a clear firing position around the obstruction")
		check(enemy.velocity.length() < 1.0 and enemy.pos.distance_to(game.building_center(game.current_core)) <= game.Content.ENEMY_TYPES.heavy.reach + 2, "The enemy slows to a stop once a valid non-barrier objective is in firing range")
	fresh()
	game.rocks[Vector2i(21, 20)] = true
	var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(23, 20)), "red")
	enemy.windup = 0.0
	enemy.cooldown = 0.0
	game.enemies.append(enemy)
	game._update_enemies(0.01)
	check(game.shots.is_empty() and game.buildings[game.current_core].hp == game.buildings[game.current_core].max_hp, "Enemies cannot shoot through wall tiles")
	game.rocks.clear()
	game.enemy_navigation.invalidate(game)
	enemy.cooldown = 0.0
	game._update_enemies(0.01)
	check(game.shots.size() == 1 and game.buildings[game.current_core].hp < game.buildings[game.current_core].max_hp, "Removing a wall immediately permits a clear shot")
	var old := Vector2i(18, 20)
	game._add_building(old, "core", 0)
	game.cores.push_front(old)
	enemy.pos = game.cell_center(old)
	enemy.cooldown = 0.0
	game.enemy_navigation.invalidate(game)
	game._update_enemies(0.01)
	check(game.buildings[old].hp == game.buildings[old].max_hp and enemy.navigation.target == game.current_core, "Enemies neither pursue nor shoot an inactive core")
	print("CLEAR FIRING PATH CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
