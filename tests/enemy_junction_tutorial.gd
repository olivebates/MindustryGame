extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.buildings.clear()
	game.occupied.clear()
	game.rocks.clear()
	game.current_core = Vector2i(10, 10)
	game._add_building(game.current_core, "core", 0)
	game._add_building(Vector2i(9, 10), "wall", 0)
	game._add_building(Vector2i(8, 9), "belt", 0)
	var position: Vector2 = game.cell_center(Vector2i(8, 10))
	var route: Dictionary = game.enemy_navigation.route(game, position)
	check(route.target == game.current_core and route.waypoint != game.cell_center(Vector2i(9, 10)), "Enemies route around barriers to reachable buildings and ignore belt objectives")
	var enemy: Dictionary = game.create_enemy("scout", position, "red")
	enemy.windup = 0.0
	enemy.cooldown = 0.0
	enemy.pos += Vector2(12, 0)
	game.enemies.append(enemy)
	game._update_enemies(0.1)
	check(game.buildings[game.current_core].hp == game.buildings[game.current_core].max_hp and game.buildings[Vector2i(9, 10)].hp < game.buildings[Vector2i(9, 10)].max_hp, "Enemies prioritize a non-barrier building in range over a closer barrier")
	for y in game.HEIGHT:
		if y != 10: game._add_building(Vector2i(9, y), "wall", 0)
	route = game.enemy_navigation.route(game, position)
	check(game.buildings[route.target].kind == "wall", "An impassable barrier line becomes a movement objective")
	game.buildings.clear()
	game.occupied.clear()
	var center := Vector2i(20, 20)
	game._add_building(center, "belt", 0)
	game._add_building(center + Vector2i(-1, 0), "belt", 0)
	game._add_building(center + Vector2i(0, -1), "belt", 1)
	check(game.belt_port_mask(center) == 13, "Two inputs plus output form the corresponding T junction")
	game._add_building(center + Vector2i(0, 1), "belt", 3)
	check(game.belt_port_mask(center) == 15, "Three inputs plus output form a cross junction")
	check(game.textures.has("belt_junction_15") and game.textures.has("belt_junction_15_dark"), "Junction SVGs support both belt upgrade states")
	var tutorial = game.tutorial
	tutorial.stage = tutorial.Stage.READY
	tutorial.onboarding_completed = true
	tutorial.first_damage_taken = true
	check(not tutorial.pause_available() and tutorial.central_message() != "Press space to pause and build.", "Damage during wave one does not introduce pause")
	tutorial.on_wave_completed(1)
	check(tutorial.pause_available() and tutorial.central_message() == "Press space to pause and build.", "Defeating wave one introduces pause")
	game.paused = true
	tutorial.paused_once = true
	tutorial.barrier_tree_closed = true
	tutorial.info_hover_time = 2.0
	check(tutorial.central_message() != "Press space to unpause", "Finishing Alt alone does not introduce unpause")
	tutorial.on_menu_clicked("Infrastructure")
	check(tutorial.central_message() != "Press space to unpause", "One glowing category remains before unpause")
	tutorial.on_menu_clicked("Defence")
	check(tutorial.central_message() == "Press space to unpause", "Both visited categories and completed Alt introduce unpause")
	game.wave = 4
	var heavy: Dictionary = game.create_enemy("heavy", position, "red")
	check(heavy.max_hp == 11 and game.Content.ENEMY_TYPES.heavy.damage == 15 and game.Content.ENEMY_TYPES.heavy.reload == 1.0, "Wave-four heavy has reduced rounded health and fifteen damage per second")
	game._add_building(game.current_core, "core", 0)
	game.wave = 1
	game._complete_wave()
	game.lost = true
	game.hud.save_browser.show_browser(true)
	game.hud.save_browser.confirm_restore(0)
	check(not game.lost and game.paused and game.hud.modal.is_queued_for_deletion(), "Death rewind loads immediately without confirmation and remains paused")
	print("ENEMY JUNCTION TUTORIAL CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)


