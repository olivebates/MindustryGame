extends RefCounted
## The older tank keeps moving; a newer overlapping tank may make one fixed sidestep.
const BUCKET := 64.0
var positions: Dictionary = {}
var reservations: Dictionary = {}
func bucket(point: Vector2) -> Vector2i:
	return Vector2i((point / BUCKET).floor())
func begin(game: Node2D) -> void:
	positions.clear()
	reservations.clear()
	for enemy in game.enemies:
		if enemy.hp <= 0: continue
		if enemy.has("separation_goal") and not enemy.has("separation_leader"): finish(enemy)
		var key := bucket(enemy.pos)
		if not positions.has(key): positions[key] = []
		positions[key].append(enemy)
		if enemy.has("separation_goal"): reserve(enemy)
func reserve(enemy: Dictionary) -> void:
	var key := bucket(enemy.separation_goal)
	if not reservations.has(key): reservations[key] = []
	reservations[key].append(enemy)
func clear_at(game: Node2D, point: Vector2, actor: Dictionary, check_reservations: bool = true) -> bool:
	var center := bucket(point)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			for other in positions.get(Vector2i(x, y), []):
				if other.info_id == actor.info_id or other.hp <= 0: continue
				var radius: float = (game.Content.ENEMY_TYPES[actor.kind].size + game.Content.ENEMY_TYPES[other.kind].size) / 2.0
				if point.distance_squared_to(other.pos) < radius * radius: return false
			if not check_reservations: continue
			for other in reservations.get(Vector2i(x, y), []):
				if other.info_id == actor.info_id or not other.has("separation_goal"): continue
				var radius: float = (game.Content.ENEMY_TYPES[actor.kind].size + game.Content.ENEMY_TYPES[other.kind].size) / 2.0
				if point.distance_squared_to(other.separation_goal) < radius * radius: return false
	return true
func walkable(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)
func can_step(grid: AStarGrid2D, origin: Vector2i, step: Vector2i) -> bool:
	if not walkable(grid, origin + step): return false
	return step.x == 0 or step.y == 0 or (walkable(grid, origin + Vector2i(step.x, 0)) and walkable(grid, origin + Vector2i(0, step.y)))
func finish(actor: Dictionary) -> void:
	actor.erase("separation_goal")
	actor.erase("separation_path")
	actor.erase("separation_leader")
	actor.separation_cooldown = 1.0
	actor.navigation_resume = true
func overlapping_leader(game: Node2D, actor: Dictionary) -> Dictionary:
	var center := bucket(actor.pos)
	var leader: Dictionary = {}
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			for other in positions.get(Vector2i(x, y), []):
				if other.hp <= 0 or other.info_id >= actor.info_id: continue
				var radius: float = (game.Content.ENEMY_TYPES[actor.kind].size + game.Content.ENEMY_TYPES[other.kind].size) / 2.0
				if actor.pos.distance_squared_to(other.pos) >= radius * radius: continue
				if leader.is_empty() or other.info_id < leader.info_id: leader = other
	return leader
func waypoint(game: Node2D, actor: Dictionary) -> Variant:
	var grid: AStarGrid2D = game.enemy_navigation.runner_grid
	if actor.has("separation_goal"):
		var goal: Vector2 = actor.separation_goal
		if actor.pos.distance_to(goal) < 4 or not walkable(grid, Vector2i((goal / game.TILE).floor())):
			finish(actor)
			return null
		var path: Array = actor.separation_path
		while path.size() > 1 and actor.pos.distance_to(game.cell_center(path[0])) < 5: path.pop_front()
		if path.is_empty() or not walkable(grid, path[0]):
			finish(actor)
			return null
		return game.cell_center(path[0])
	if actor.get("separation_cooldown", 0.0) > 0: return null
	var leader := overlapping_leader(game, actor)
	if leader.is_empty(): return null
	# Yield only once to a particular tank; returning to the route must not restart the same dodge.
	var handled: Dictionary = actor.get("separation_handled_leaders", {})
	if handled.has(leader.info_id): return null
	var origin := Vector2i((actor.pos / game.TILE).floor())
	for direction in game.DIRS:
		if not walkable(grid, origin + direction): return null
	var heading: Vector2 = leader.get("velocity", Vector2.ZERO)
	if heading.length_squared() < 1:
		var route: Dictionary = leader.get("navigation", {})
		heading = route.get("waypoint", game.cell_center(game.current_core)) - leader.pos
	var side := Vector2i.DOWN if absf(heading.x) >= absf(heading.y) else Vector2i.RIGHT
	if int(actor.info_id) % 2 == 0: side = -side
	var spacing: float = (game.Content.ENEMY_TYPES[actor.kind].size + game.Content.ENEMY_TYPES[leader.kind].size) / 2.0
	var distance := maxi(1, ceili(spacing / game.TILE))
	for direction in [side, -side]:
		var path: Array[Vector2i] = []
		for step in range(1, distance + 1):
			var cell: Vector2i = origin + direction * step
			if not walkable(grid, cell): break
			path.append(cell)
		if path.size() != distance or not clear_at(game, game.cell_center(path[-1]), actor): continue
		actor.separation_goal = game.cell_center(path[-1])
		actor.separation_path = path
		actor.separation_leader = leader.info_id
		handled[leader.info_id] = true
		actor.separation_handled_leaders = handled
		reserve(actor)
		return game.cell_center(path[0])
	return null
