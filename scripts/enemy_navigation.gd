extends RefCounted
const TURRET_PRIORITY_TILES := 15
var grid := AStarGrid2D.new()
var runner_grid := AStarGrid2D.new()
var signature := -1
var routes: Dictionary = {}
var firing_goals: Dictionary = {}
var paths: Dictionary = {}
var frame_budget_usec := -1
var turret_cells: Array[Vector2i] = []
func begin_frame() -> void:
	frame_budget_usec = 2000
func end_frame() -> void:
	frame_budget_usec = -1
func can_route() -> bool:
	return frame_budget_usec != 0
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
		turret_cells.clear()
		for turret in turrets: turret_cells.append(turret[0])
		routes.clear()
		firing_goals.clear()
		paths.clear()
		grid.clear()
		grid.region = Rect2i(0, 0, game.WIDTH, game.HEIGHT)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for cell in game.rocks: grid.set_point_solid(cell)
		for cell in solids: grid.set_point_solid(cell)
		runner_grid.clear()
		runner_grid.region = grid.region
		runner_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
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
func route(game: Node2D, position: Vector2, ignore_turrets: bool = false, attack_range: float = -1.0, actor: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := find_route(game, position, ignore_turrets, attack_range, actor)
	if not result.is_empty(): result.revision = signature
	if frame_budget_usec >= 0: frame_budget_usec = maxi(0, frame_budget_usec - (Time.get_ticks_usec() - started))
	return result
func find_route(game: Node2D, position: Vector2, ignore_turrets: bool = false, attack_range: float = -1.0, actor: Dictionary = {}) -> Dictionary:
	if signature == -1: refresh_grid(game)
	if attack_range < 0: attack_range = game.TILE
	var navigation_grid: AStarGrid2D = runner_grid if ignore_turrets else grid
	var origin := Vector2i((position / game.TILE).floor())
	if not navigation_grid.is_in_boundsv(origin): return {}
	var cache_key := "%d,%d,%d,%d" % [origin.x, origin.y, int(ignore_turrets), roundi(attack_range)]
	var priority := priority_turret(game, position, ignore_turrets)
	if routes.has(cache_key):
		var cached: Dictionary = routes[cache_key]
		if not cached.is_empty() and game.enemy_goal_available(cached.destination, actor) and (priority == game.INVALID or (game.is_turret(game.buildings.get(cached.target, {}).get("kind", "")) and position.distance_squared_to(game.building_center(cached.target)) <= game.TILE * game.TILE * TURRET_PRIORITY_TILES * TURRET_PRIORITY_TILES)):
			if cached.cost > 0.0 or (position.distance_to(game.building_center(cached.target)) <= attack_range and game.enemy_has_line_of_sight(position, cached.target)):
				return cached
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
	candidates.sort_custom(func(a, b):
		var near_a: bool = not ignore_turrets and game.is_turret(game.buildings[a].kind) and position.distance_squared_to(game.building_center(a)) <= pow(game.TILE * TURRET_PRIORITY_TILES, 2)
		var near_b: bool = not ignore_turrets and game.is_turret(game.buildings[b].kind) and position.distance_squared_to(game.building_center(b)) <= pow(game.TILE * TURRET_PRIORITY_TILES, 2)
		if near_a != near_b: return near_a
		return position.distance_squared_to(game.building_center(a)) < position.distance_squared_to(game.building_center(b))
	)
	walls.sort_custom(func(a, b): return position.distance_squared_to(game.building_center(a)) < position.distance_squared_to(game.building_center(b)))
	var nearest_is_turret: bool = not candidates.is_empty() and game.is_turret(game.buildings[candidates[0]].kind)
	candidates.append_array(walls)
	var best: Dictionary = {}
	var best_cost := INF
	var origin_solid := navigation_grid.is_point_solid(origin)
	navigation_grid.set_point_solid(origin, false)
	for target in candidates:
		if game.buildings[target].kind == "wall" and not best.is_empty() and game.buildings[best.target].kind != "wall": break
		var candidate := firing_route(game, navigation_grid, origin, position, target, attack_range, actor)
		if candidate.is_empty(): continue
		if candidate.cost < best_cost:
			best = candidate
			best_cost = candidate.cost
		if (not ignore_turrets and game.is_turret(game.buildings[target].kind) and position.distance_squared_to(game.building_center(target)) <= pow(game.TILE * TURRET_PRIORITY_TILES, 2)) or (nearest_is_turret and target == candidates[0]) or best_cost <= 1.0: break
	navigation_grid.set_point_solid(origin, origin_solid)
	if routes.size() >= 4096: routes.clear()
	routes[cache_key] = best
	return best
func firing_route(game: Node2D, navigation_grid: AStarGrid2D, origin: Vector2i, position: Vector2, target: Vector2i, reach: float, actor: Dictionary = {}) -> Dictionary:
	if position.distance_to(game.building_center(target)) <= reach and game.enemy_has_line_of_sight(position, target) and game.enemy_goal_available(position, actor):
		return {"target": target, "waypoint": position, "destination": position, "cost": 0.0, "path": []}
	var key := "%s:%d:%d" % [target, roundi(reach), int(navigation_grid == runner_grid)]
	if not firing_goals.has(key):
		var radius := ceili(reach / game.TILE) + 1
		var cells: Array[Vector2i] = []
		var center: Vector2 = game.building_center(target)
		for y in range(maxi(0, target.y - radius), mini(game.HEIGHT, target.y + radius + 1)):
			for x in range(maxi(0, target.x - radius), mini(game.WIDTH, target.x + radius + 1)):
				var cell := Vector2i(x, y)
				if navigation_grid.is_point_solid(cell): continue
				var point: Vector2 = game.cell_center(cell)
				if point.distance_squared_to(center) <= reach * reach and game.enemy_has_line_of_sight(point, target): cells.append(cell)
		firing_goals[key] = cells
	var goals: Array = firing_goals[key].duplicate()
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
		if not game.enemy_goal_available(game.cell_center(goal), actor): continue
		var path_key := "%s:%s:%d" % [origin, goal, int(navigation_grid == runner_grid)]
		if not paths.has(path_key):
			if paths.size() >= 4096: paths.clear()
			paths[path_key] = navigation_grid.get_id_path(origin, goal)
		var path: Array[Vector2i] = paths[path_key]
		if path.is_empty(): continue
		var cost := 0.0
		for point in path: cost += navigation_grid.get_point_weight_scale(point)
		if cost < best_cost:
			best_cost = cost
			best = {"target": target, "waypoint": game.cell_center(path[1]) if path.size() > 1 else game.cell_center(goal), "destination": game.cell_center(goal), "cost": cost, "path": path.duplicate(), "path_index": 1 if path.size() > 1 else 0}
		successful += 1
		if successful >= 4: break
	return best


func resume_destination(game: Node2D, actor: Dictionary, previous: Dictionary) -> Dictionary:
	if previous.is_empty() or not game.buildings.has(previous.target) or not game.enemy_goal_available(previous.destination, actor): return {}
	var point: Vector2 = previous.destination
	if not game.enemy_has_line_of_sight(point, previous.target): return {}
	var navigation_grid: AStarGrid2D = runner_grid if actor.kind == "runner" else grid
	var origin := Vector2i((actor.pos / game.TILE).floor())
	var goal := Vector2i((point / game.TILE).floor())
	if not navigation_grid.is_in_boundsv(origin) or not navigation_grid.is_in_boundsv(goal) or navigation_grid.is_point_solid(goal): return {}
	var started := Time.get_ticks_usec()
	var solid := navigation_grid.is_point_solid(origin)
	navigation_grid.set_point_solid(origin, false)
	var path := navigation_grid.get_id_path(origin, goal)
	navigation_grid.set_point_solid(origin, solid)
	if frame_budget_usec >= 0: frame_budget_usec = maxi(0, frame_budget_usec - (Time.get_ticks_usec() - started))
	if path.is_empty(): return {}
	var index := 1 if path.size() > 1 else 0
	return {"target": previous.target, "destination": point, "waypoint": point if index == path.size() - 1 else game.cell_center(path[index]), "cost": previous.cost, "path": path, "path_index": index, "revision": signature}
func priority_turret(game: Node2D, position: Vector2, ignore_turrets: bool = false) -> Vector2i:
	if ignore_turrets: return game.INVALID
	var nearest := float(game.TILE * TURRET_PRIORITY_TILES) * float(game.TILE * TURRET_PRIORITY_TILES)
	var result: Vector2i = game.INVALID
	for cell in turret_cells:
		if not game.buildings.has(cell): continue
		var distance := position.distance_squared_to(game.building_center(cell))
		if distance <= nearest:
			nearest = distance
			result = cell
	return result

