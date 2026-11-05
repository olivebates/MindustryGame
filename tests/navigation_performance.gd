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
	game.tutorial_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.buildings.clear()
	game.occupied.clear()
	game.current_core = Vector2i(30, 30)
	game.cores.assign([game.current_core])
	game._add_building(game.current_core, "core", 0)
	for index in 12: game._add_building(Vector2i(25 + index % 6, 24 + index / 6), "drill", 0)
	for index in 8: game._add_building(Vector2i(32, 22 + index), "wall", 0)
	var actor: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(45, 30)), "red")
	game.enemies.append(actor)
	var start := Time.get_ticks_usec()
	var first: Dictionary = game.enemy_navigation.route(game, actor.pos, false, 128, actor)
	var cold := Time.get_ticks_usec() - start
	var goals: int = game.enemy_navigation.firing_goals.size()
	var paths: int = game.enemy_navigation.paths.size()
	start = Time.get_ticks_usec()
	for index in 30: game.enemy_navigation.route(game, actor.pos, false, 128, actor)
	var warm := (Time.get_ticks_usec() - start) / 30.0
	check(not first.is_empty() and goals > 0 and paths > 0, "Navigation caches valid firing positions and paths")
	check(game.enemy_navigation.firing_goals.size() == goals and game.enemy_navigation.paths.size() == paths, "Repeated routing reuses geometry and AStar results")
	var crossing: Dictionary = game.create_enemy("scout", actor.pos, "blue")
	crossing.windup = 0.0
	crossing.cooldown = 100.0
	actor.windup = 0.0
	actor.cooldown = 100.0
	game.enemies.append(crossing)
	var old: Vector2 = crossing.pos
	game._update_enemies(0.05)
	check(crossing.pos.distance_to(old) > 0.01 and crossing.pos.distance_to(actor.pos) < 30, "Overlapping enemies can move through each other without being pushed apart")
	game._add_building(Vector2i(38, 30), "wall", 0)
	check(game.enemy_navigation.paths.is_empty() and game.enemy_navigation.firing_goals.is_empty(), "Construction invalidates both navigation caches")
	game.tutorial.first_wave_completed = true
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.paused_once = true
	game.tutorial.pause_exit_completed = false
	game.tutorial.tech_opened = false
	game.paused = false
	check(game.tutorial.central_message().begins_with("Press space to pause"), "Pause reminder is visible before research opens")
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	game.hud.close_modal()
	check(not game.tutorial.central_message().begins_with("Press space to pause"), "Opening research permanently dismisses the pause reminder")
	game.research("barriers", true)
	game.research("turret_range", true)
	game.research("build_hotkeys", true)
	game.hud.refresh()
	game.hud.toggle_category("Infrastructure")
	game.hud.refresh()
	var hidden := true
	for button in game.hud.category_buttons.values():
		var hint = button.get_node_or_null("Hotkey")
		if hint != null and hint.visible: hidden = false
	check(hidden, "Category number hints disappear while the build tray is open")
	check(not game.hud.visible_tech_ids().has("conveyor_speed") and game.TECH.copper_storage.parent == "turret_range" and game.TECH.auto_scrap.parent == "turret_range", "Hidden belt-speed branch is reparented below Solar range")
	game.enemies.clear()
	for index in 30:
		var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(43 + index % 5, 25 + index / 5)), "red")
		enemy.windup = 0.0
		enemy.cooldown = 100.0
		game.enemies.append(enemy)
	var total := 0
	var worst := 0
	for tick in 90:
		start = Time.get_ticks_usec()
		game.enemy_navigation.begin_frame()
		game._update_enemies(0.016)
		game.enemy_navigation.end_frame()
		var elapsed := Time.get_ticks_usec() - start
		total += elapsed
		worst = maxi(worst, elapsed)
	print("ENEMY UPDATE TIMING: 30 enemies, mean %.2f ms, worst %.2f ms" % [total / 90000.0, worst / 1000.0])
	var routed := 0
	for enemy in game.enemies:
		if not enemy.get("navigation", {}).is_empty(): routed += 1
	check(routed == game.enemies.size(), "Staggered pathfinding serves every enemy without starvation")
	print("NAVIGATION TIMING: cold %.2f ms; repeated %.2f ms" % [cold / 1000.0, warm / 1000.0])
	print("NAVIGATION PERFORMANCE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
