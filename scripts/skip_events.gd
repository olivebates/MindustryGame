extends RefCounted
static func path_to_core(game: Node2D, source: Vector2i) -> int:
	var queue: Array = [[source, 0]]
	var visited := {}
	var index := 0
	while index < queue.size():
		var entry: Array = queue[index]
		index += 1
		var cell: Vector2i = game.anchor_at(entry[0])
		if cell == game.INVALID or visited.has(cell): continue
		visited[cell] = true
		var b: Dictionary = game.buildings[cell]
		if b.get("pending", false): continue
		if b.kind == "core": return int(entry[1])
		if b.kind in ["drill", "refinery"] or b.kind == "splitter":
			var ports: Array = []
			if b.kind == "refinery": ports = preload("res://scripts/pink_production.gd").ports(game, cell)
			else:
				for direction in game.DIRS: ports.append(cell + direction)
			for port in ports:
				var other: Dictionary = game.building_at(port)
				if other.is_empty(): continue
				if other.kind == "core" or (other.kind == "belt" and game.anchor_at(game.output_target(port, other)) != cell): queue.append([port, entry[1] + 1])
		elif b.kind == "belt": queue.append([game.output_target(cell, b), entry[1] + 1])
	return -1
static func next_is_capacity(game: Node2D) -> bool:
	var rates := {}
	var delays := {}
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.kind not in ["drill", "refinery"] or b.get("pending", false): continue
		var distance := path_to_core(game, cell)
		if distance < 0: continue
		var resource: String = game.ores.get(cell, "copper") if b.kind == "drill" else "pink"
		if b.kind == "refinery" and b.item == "" and (b.buffer.copper < 1 or b.buffer.iron < 1): continue
		var cycle := 5.0 / (1.3 if game.researched.has("mining") else 1.0) if b.kind == "drill" else 10.0
		rates[resource] = float(rates.get(resource, 0.0)) + 1.0 / cycle
		var production_delay := maxf(0, cycle - b.progress) if b.item == "" else 0.0
		delays[resource] = minf(float(delays.get(resource, INF)), production_delay + distance * 2.0)
	for resource in rates:
		var needed: int = game.material_capacity(resource) - game.inventory[resource]
		if needed > 0 and float(delays[resource]) + (needed - 1) / rates[resource] < game.wave_timer: return true
	# A final item already travelling on a belt can fill storage before production.
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.kind != "belt" or b.item == "" or b.get("pending", false): continue
		if game.inventory.get(b.item, 0) != game.material_capacity(b.item) - 1: continue
		var distance := path_to_core(game, cell)
		if distance >= 0 and distance * 2.0 < game.wave_timer: return true
	return false
