extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var origin := Vector2i(20, 20)
	var first: Dictionary = game.create_enemy("heavy", game.cell_center(origin), "red")
	var second: Dictionary = game.create_enemy("heavy", first.pos, "red")
	for actor in [first, second]:
		actor.windup = 0
		actor.cooldown = 999
		actor.navigation = {"target": game.current_core, "waypoint": game.cell_center(origin + Vector2i.RIGHT), "destination": game.cell_center(Vector2i(22, 22)), "cost": 4.0}
	game.enemies.assign([first, second])
	game.enemy_navigation.invalidate(game)
	game.enemy_separation.begin(game)
	check(game.enemy_separation.waypoint(game, first) == null and not first.has("separation_goal"), "Older overlapping tank keeps moving toward its goal")
	check(game.enemy_separation.waypoint(game, second) != null, "Only the other tank steps aside in open terrain")
	var goal: Vector2 = second.separation_goal
	check(goal.x == game.cell_center(origin).x and goal.y != first.pos.y, "Sidestep is perpendicular to the leading tank's movement")
	first.pos = goal
	game.enemy_separation.begin(game)
	game.enemy_separation.waypoint(game, second)
	check(second.separation_goal == goal, "Moving enemies do not cause the sidestep to flip back and forth")
	game.enemy_separation.finish(second)
	second.separation_cooldown = 0
	first.pos = second.pos
	game.enemy_separation.begin(game)
	check(game.enemy_separation.waypoint(game, second) == null, "The same pair does not restart its sidestep when their paths cross again")
	fresh()
	first = game.create_enemy("scout", game.cell_center(origin), "red")
	second = game.create_enemy("scout", first.pos, "red")
	game.enemies.assign([first, second])
	game.rocks[origin + Vector2i.LEFT] = true
	game.enemy_navigation.invalidate(game)
	game.enemy_separation.begin(game)
	check(game.enemy_separation.waypoint(game, first) == null and game.enemy_separation.waypoint(game, second) == null, "A blocked cardinal neighbor allows tanks to overlap without dodging")
	for wave in [1, 5, 20]: check(game.enemy_health("siege", wave) == 2000, "Siege health is fixed at two thousand at every wave")
	var siege: Dictionary = game.Content.ENEMY_TYPES.siege
	check(siege.size > game.Content.ENEMY_TYPES.bulwark.size and siege.speed < game.Content.ENEMY_TYPES.bulwark.speed, "Siege is larger and slower than Bulwark")
	check(siege.credits == 400 and siege.damage == 100 and siege.reload == 5 and siege.reach == 3 * game.TILE and game.Content.enemy_scrap("siege") == 70, "Siege deployment cost, damage, interval, range and drops match")
	check(game.Content.ENEMY_TYPES.bulwark.reach == 2 * game.TILE, "Bulwark has two tiles of range")
	game.inventory.scrap = 1000000
	check(game.add_resource("scrap", 1000000) == 1000000 and game.inventory.scrap == 2000000, "Scrap storage has no gameplay cap")
	game.debug_resource_capacity = true
	check(game.add_resource("scrap", 70) == 70, "Debug resource cap does not limit scrap")
	var before_pickup: int = game.inventory.scrap
	game.spawn_scrap(70, game.cell_center(game.current_core), false)
	game.collect_scrap(0.1, game.cell_center(game.current_core))
	check(game.inventory.scrap == before_pickup + 70, "Ground scrap remains collectible above former storage limits")
	game.hud.refresh()
	check(game.hud.resource_views.scrap.capacity.text == "" and not game.hud.resource_views.scrap.fill.get_parent().visible, "Scrap HUD omits capacity and fill gauge")
	var gate = game.active_spawners[0]
	gate.waves_completed = gate.waves_before_conversion - 1
	game.pending_waves[1] = [game.spawners.find(gate)]
	game.hud.refresh()
	check(game.hud.wave_label.text == "00:00" and game.hud.next_wave_label.text == "Next Wave: Last", "Final round keeps the timer at zero and retains the Last label")
	fresh()
	var wall := Vector2i(21, 25)
	game._add_building(wall, "wall", 0)
	game.buildings[wall].hp = 1
	var killer: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(20, 25)), "red")
	var follower: Dictionary = game.create_enemy("scout", killer.pos, "red")
	for actor in [killer, follower]:
		actor.windup = 0
		actor.cooldown = 0
		actor.navigation = {"target": wall, "waypoint": actor.pos, "destination": actor.pos, "cost": 0.0, "path": [], "revision": game.enemy_navigation.signature}
	follower.separation_goal = game.cell_center(Vector2i(20, 24))
	follower.separation_path = [Vector2i(20, 24)]
	follower.separation_leader = killer.info_id
	game.enemies.assign([follower, killer])
	game.enemy_navigation.frame_budget_usec = 0
	game._update_enemies(0.05)
	check(not game.buildings.has(wall), "First enemy destroys the second enemy's cached target")
	check(follower.navigation.is_empty() or game.buildings.has(follower.navigation.target), "Separating enemy discards a destroyed target even when routing budget is exhausted")
	check(game.building_center(Vector2i(65, 27)) == game.cell_center(Vector2i(65, 27)), "Missing building-center lookup is safe")
	print("YIELD SIEGE AND SCRAP CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)





