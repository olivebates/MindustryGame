extends RefCounted
var grid := AStarGrid2D.new()
var runner_grid := AStarGrid2D.new()
var signature := -1
var routes: Dictionary = {}
func invalidate(game: Node2D) -> void:
	signature = -1
	refresh_grid(game)
	for enemy in game.enemies: enemy.navigation_timer = 0.0
func refresh_grid(game: Node2D) -> void:
	var solids: Array = []
	var turrets: Array = []
	for cell in game.buildings:
		if game.is_turret(game.buildings[cell].kind): turrets.append([cell, game.turret_range(game.buildings[cell].kind)])
		if game.buildings[cell].kind == "belt": continue
		for y in game.footprint_size(game.buildings[cell].kind):
			for x in game.footprint_size(game.buildings[cell].kind): solids.append(cell + Vector2i(x, y))
	var next_signature := hash([game.rocks.keys(), solids, turrets])
	if signature != next_signature:
		signature = next_signature
		routes.clear()
		grid.clear()
		grid.region = Rect2i(0, 0, game.WIDTH, game.HEIGHT)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		for cell in game.rocks: grid.set_point_solid(cell)
		for cell in solids: grid.set_point_solid(cell)
		runner_grid.clear()
		runner_grid.region = grid.region
		runner_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		runner_grid.update()
		for cell in game.rocks: runner_grid.set_point_solid(cell)
		for cell in solids: runner_grid.set_point_solid(cell)
		var danger_cost: float = game.WIDTH * game.HEIGHT + 1
		for turret in turrets:
			var radius := ceili(float(turret[1]) / game.TILE)
			for y in range(maxi(0, turret[0].y - radius), mini(game.HEIGHT, turret[0].y + radius + 1)):
				for x in range(maxi(0, turret[0].x - radius), mini(game.WIDTH, turret[0].x + radius + 1)):
					var cell := Vector2i(x, y)
					if game.cell_center(cell).distance_to(game.building_center(turret[0])) <= turret[1]:
						grid.set_point_weight_scale(cell, grid.get_point_weight_scale(cell) + danger_cost)
func route(game: Node2D, position: Vector2, ignore_turrets: bool = false, attack_range: float = -1.0) -> Dictionary:
	refresh_grid(game)
	if attack_range < 0: attack_range = game.TILE
	var navigation_grid: AStarGrid2D = runner_grid if ignore_turrets else grid
	var origin := Vector2i((position / game.TILE).floor())
	if not navigation_grid.is_in_boundsv(origin): return {}
	var cache_key := "%d,%d,%d,%d" % [origin.x, origin.y, int(ignore_turrets), roundi(attack_range)]
	if routes.has(cache_key): return routes[cache_key]
	var candidates: Array = []
	var walls: Array = []
	for cell in game.buildings:
		var kind: String = game.buildings[cell].kind
		if kind == "wall":
			walls.append(cell)
			continue
		if kind == "belt" or (kind == "core" and cell != game.current_core): continue
		if ignore_turrets and game.is_turret(kind): continue
		candidates.append(cell)
	candidates.sort_custom(func(a, b): return position.distance_squared_to(game.building_center(a)) < position.distance_squared_to(game.building_center(b)))
	walls.sort_custom(func(a, b): return position.distance_squared_to(game.building_center(a)) < position.distance_squared_to(game.building_center(b)))
	var nearest_is_turret: bool = not candidates.is_empty() and game.is_turret(game.buildings[candidates[0]].kind)
	candidates.append_array(walls)
	var best: Dictionary = {}
	var best_cost := INF
	var origin_solid := navigation_grid.is_point_solid(origin)
	navigation_grid.set_point_solid(origin, false)
	for target in candidates:
		if game.buildings[target].kind == "wall" and not best.is_empty() and game.buildings[best.target].kind != "wall": break
		var candidate := firing_route(game, navigation_grid, origin, position, target, attack_range)
		if candidate.is_empty(): continue
		if candidate.cost < best_cost:
			best = candidate
			best_cost = candidate.cost
		if (nearest_is_turret and target == candidates[0]) or best_cost <= 1.0: break
	navigation_grid.set_point_solid(origin, origin_solid)
	routes[cache_key] = best
	return best
func firing_route(game: Node2D, navigation_grid: AStarGrid2D, origin: Vector2i, position: Vector2, target: Vector2i, reach: float) -> Dictionary:
	if position.distance_to(game.building_center(target)) <= reach and game.enemy_has_line_of_sight(position, target):
		return {"target": target, "waypoint": position, "cost": 0.0}
	var radius := ceili(reach / game.TILE) + 1
	var goals: Array[Vector2i] = []
	for y in range(maxi(0, target.y - radius), mini(game.HEIGHT, target.y + radius + 1)):
		for x in range(maxi(0, target.x - radius), mini(game.WIDTH, target.x + radius + 1)):
			var cell := Vector2i(x, y)
			if navigation_grid.is_point_solid(cell): continue
			var point: Vector2 = game.cell_center(cell)
			if point.distance_to(game.building_center(target)) <= reach and game.enemy_has_line_of_sight(point, target): goals.append(cell)
	goals.sort_custom(func(a, b):
		var risk_a := navigation_grid.get_point_weight_scale(a)
		var risk_b := navigation_grid.get_point_weight_scale(b)
		if risk_a != risk_b: return risk_a < risk_b
		return position.distance_squared_to(game.cell_center(a)) < position.distance_squared_to(game.cell_center(b))
	)
	var best: Dictionary = {}
	var best_cost := INF
	var successful := 0
	for goal in goals:
		var path := navigation_grid.get_id_path(origin, goal)
		if path.is_empty(): continue
		var cost := 0.0
		for point in path: cost += navigation_grid.get_point_weight_scale(point)
		if cost < best_cost:
			best_cost = cost
			best = {"target": target, "waypoint": game.cell_center(path[1]) if path.size() > 1 else game.cell_center(goal), "cost": cost}
		successful += 1
		if successful >= 4: break
	return best
