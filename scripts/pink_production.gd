extends RefCounted
static func ports(game: Node2D, cell: Vector2i) -> Array[Vector2i]:
	var size: int = game.footprint_size("refinery")
	var result: Array[Vector2i] = []
	for i in size: result.append(cell + Vector2i(size, i))
	for i in size: result.append(cell + Vector2i(size - 1 - i, size))
	for i in size: result.append(cell + Vector2i(-1, size - 1 - i))
	for i in size: result.append(cell + Vector2i(i, -1))
	return result
static func route(game: Node2D, cell: Vector2i, building: Dictionary) -> void:
	var outputs := ports(game, cell)
	if building.route_dir >= 0 and building.route_dir < outputs.size():
		var existing: Dictionary = game.building_at(outputs[building.route_dir])
		if not existing.is_empty() and existing.kind == "belt" and game.anchor_at(game.output_target(outputs[building.route_dir], existing)) != cell and game.can_receive(outputs[building.route_dir], building.item, cell):
			building.travel = 1.0
			return
	building.route_dir = -1
	building.travel = 0.0
	for offset in outputs.size():
		var index: int = (int(building.next_output) + offset) % outputs.size()
		var receiver: Dictionary = game.building_at(outputs[index])
		if not receiver.is_empty() and receiver.kind == "belt" and game.anchor_at(game.output_target(outputs[index], receiver)) != cell and game.can_receive(outputs[index], building.item, cell):
			building.route_dir = index
			building.travel = 1.0
			return
static func advance(game: Node2D, dt: float) -> void:
	for building in game.buildings.values():
		if building.get("pending", false): continue
		if building.kind in ["copper_store", "iron_store"]:
			preload("res://scripts/pink_support.gd").burn_silo(game, building, dt)
		if building.kind == "refinery":
			if building.buffer.copper < 1 or building.buffer.iron < 1 or building.item != "": continue
			building.progress = minf(10, building.progress + dt)
			if building.progress >= 9.99999:
				building.buffer.copper -= 1
				building.buffer.iron -= 1
				building.item = "pink"
				game.tutorial.ui_revealed.pink_produced = true
				building.travel = 0.0
				building.progress = 0.0
static func speed_multiplier(building: Dictionary) -> float:
	return 2.0 if building.get("booster_count", 0) > 0 and building.get("booster_type", "") == "pink" else 1.0
static func advance_firing(building: Dictionary, dt: float) -> void:
	var active := minf(dt, float(building.get("booster_fire_remaining", 0.0)))
	building.booster_fire_remaining = maxf(0, float(building.get("booster_fire_remaining", 0.0)) - dt)
	if speed_multiplier(building) <= 1: return
	building.booster_used = float(building.get("booster_used", 0.0)) + active
	while building.booster_used >= 29.99999 and building.booster_count > 0:
		building.booster_used = maxf(0, building.booster_used - 30)
		building.booster_count -= 1
	if building.booster_count == 0:
		building.booster_type = ""
		building.booster_used = 0.0
