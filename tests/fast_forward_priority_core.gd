extends "res://tests/iron_supply_zoom.gd"
func factory() -> void:
	fresh()
	game.inventory.copper = 0
	game.base_copper_capacity = 10000
	game.ores[Vector2i(23, 25)] = "copper"
	game._add_building(Vector2i(23, 25), "drill", 0)
	game._add_building(Vector2i(24, 25), "belt", 0)
	game.wave_timer = 300
func production() -> Array:
	var drill: Dictionary = game.buildings[Vector2i(23, 25)]
	var belt: Dictionary = game.buildings[Vector2i(24, 25)]
	return [game.inventory.copper, drill.item, drill.progress, drill.travel, belt.item, belt.travel, game.elapsed]
func run() -> void:
	factory()
	game.advance_logistics(300)
	var normal: Array = production()
	check(game.inventory.copper > 20, "Reference factory produces and delivers ore during five minutes")
	factory()
	game.request_next_wave()
	game.advance_wave_warp(1)
	check(game.wave_timer == 150 and game.elapsed == 150 and game.inventory.copper > 10, "Q advances production by the same time skipped on the countdown")
	var midway: Array = production()
	game.simulate(0.1)
	check(production() == midway, "Warp does not advance conveyor and extractor production twice")
	game.paused = true
	game.advance_wave_warp(0.5)
	check(production() == midway, "Pausing freezes production fast-forward")
	game.paused = false
	game.advance_wave_warp(1)
	check(production() == normal and game.wave == 1 and not game.wave_warp_active, "Q finishes with the same factory state as the full skipped waiting period")
	check(game.enemy_health("siege", 1) == 2000 and game.enemy_health("siege", 50) == 2000, "Siege health is two thousand at every wave")
	fresh()
	var drill := Vector2i(20, 25)
	var tower := Vector2i(25, 20)
	game._add_building(drill, "drill", 0)
	game._add_building(tower, "solar", 0)
	var actor: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(19, 25)), "red")
	actor.windup = 0
	actor.cooldown = 999
	game.enemies.append(actor)
	var route: Dictionary = game.enemy_navigation.route(game, actor.pos, false, game.Content.ENEMY_TYPES.scout.reach, actor)
	check(route.target == tower, "A tower within ten tiles outranks a closer extractor")
	actor.navigation = route.duplicate(true)
	check(game.visible_enemy_objective(actor) == game.INVALID, "Enemy keeps moving toward priority tower instead of stopping to attack an extractor")
	var runner: Dictionary = game.create_enemy("runner", actor.pos, "red")
	var runner_route: Dictionary = game.enemy_navigation.route(game, runner.pos, true, game.Content.ENEMY_TYPES.runner.reach, runner)
	check(runner_route.target != tower, "Runner keeps its tower-ignoring behavior")
	game.enemies.clear()
	actor = game.create_enemy("heavy", game.cell_center(Vector2i(24, 21)), "red")
	actor.windup = 0
	actor.cooldown = 0
	game.enemies.append(actor)
	var hp: float = game.buildings[tower].hp
	game._update_enemies(0.05)
	check(game.buildings[tower].hp < hp, "An enemy in range shoots a tower before closer non-turret buildings")
	fresh()
	game.wave = 8
	var gate = game.active_spawners[0]
	gate.waves_completed = 0
	gate.waves_before_conversion = 1
	game.wave_in_progress = true
	game._complete_wave()
	check(game.cores.size() == 2 and game.wave_timer == 600 and game.paused, "New core starts with a paused ten-minute wave timer")
	check(game.saves.load_snapshot(game.saves.current)[1][4] == 600, "Core-capture save preserves ten-minute timer")
	print("FAST FORWARD PRIORITY AND CORE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
