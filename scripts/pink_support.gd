extends RefCounted
static func in_healing_square(game: Node2D, healer: Vector2i, target: Vector2i) -> bool:
	var area := Rect2i(healer - Vector2i.ONE, Vector2i(3, 3))
	var footprint := Rect2i(target, Vector2i.ONE * game.footprint_size(game.buildings[target].kind))
	return area.intersects(footprint)
static func heal(game: Node2D, cell: Vector2i, building: Dictionary, dt: float) -> void:
	if building.buffer.get("pink", 0) <= 0: return
	var targets: Array[Dictionary] = []
	for other in game.buildings:
		var target: Dictionary = game.buildings[other]
		if target.get("pending", false) or target.hp >= target.max_hp: continue
		if in_healing_square(game, cell, other): targets.append(target)
	if targets.is_empty(): return
	var active_time := minf(dt, building.buffer.pink * 20.0 - building.progress)
	var missing_health := 0.0
	for target in targets: missing_health = maxf(missing_health, target.max_hp - target.hp)
	active_time = minf(active_time, missing_health)
	for target in targets: target.hp = minf(target.max_hp, target.hp + active_time)
	building.progress += active_time
	while building.progress >= 19.99999 and building.buffer.pink > 0:
		building.progress = maxf(0, building.progress - 20)
		building.buffer.pink -= 1
	building.pulse = 0.65
	if game.buildings.has(game.current_core): game.core_health = game.buildings[game.current_core].hp
static func burn_silo(game: Node2D, building: Dictionary, dt: float) -> void:
	if building.buffer.get("pink", 0) <= 0: return
	var resource: String = game.BUILDINGS[building.kind].stores
	var previous_capacity: int = game.material_capacity(resource)
	building.progress += dt
	while building.progress >= 29.99999 and building.buffer.pink > 0:
		building.progress = maxf(0, building.progress - 30)
		building.buffer.pink -= 1
	if building.buffer.pink == 0:
		building.progress = 0.0
		game.inventory[resource] = mini(game.inventory[resource], game.material_capacity(resource))
		if game.inventory[resource] >= game.material_capacity(resource) and previous_capacity > game.material_capacity(resource): game.notify_capacity_reached(resource)
