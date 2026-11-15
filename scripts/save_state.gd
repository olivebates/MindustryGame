extends RefCounted
## The disk contract contains only player resources, buildings, technology,
## and the core/next wave to defend. The old array shape is a runtime adapter
## for previews and history; its other fields are reconstructed, never stored.
const VERSION := 19
const BUILDING_FIELDS := ["kind", "dir", "input_dir", "hp", "item", "ammo", "buffer", "paid_cost", "tunnel_role", "tunnel_pair", "next_output", "color", "shield", "booster_type", "booster_count", "booster_used"]
const NUCLEAR_FIELDS := ["fuel", "heat", "overheated", "shots", "shield", "recharge", "spent", "stock", "output", "wreckage", "target"]
static func building(source: Dictionary) -> Dictionary:
	var result := {}
	for field in BUILDING_FIELDS:
		if source.has(field):
			var value = source[field]
			result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	var nuclear: Dictionary = source.get("nuclear", {})
	var durable := {}
	for field in NUCLEAR_FIELDS:
		if source.get("kind", "") == "reactor" and field in ["heat", "overheated"]: continue
		if field == "target" and source.get("kind", "") != "magnetic_funnel": continue
		if nuclear.has(field):
			var value = nuclear[field]
			durable[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	if nuclear.has("underlay"): durable.underlay = building(nuclear.underlay)
	result.nuclear = durable
	return result
static func capture(game: Node2D) -> Dictionary:
	var buildings: Array = []
	var cells: Array = game.buildings.keys()
	cells.sort()
	for cell in cells:
		var source: Dictionary = game.buildings[cell]
		if source.kind == "teleporter" and source.tunnel_pair == game.INVALID: continue
		var saved := building(source)
		saved.cell = cell
		buildings.append(saved)
	var active: bool = game.wave_active() or game.wave_in_progress or not game.pending_waves.is_empty()
	return {"version":VERSION, "resources":game.inventory.duplicate(true), "buildings":buildings, "tech":game.researched.duplicate(true), "progress":{"core":game.current_core, "wave":maxi(1, game.wave + (0 if active else 1))}}
static func from_legacy(game: Node2D, data: Array) -> Dictionary:
	if data.size() != 10 or data[1].size() < 11: return {}
	var buildings: Array = []
	for row in data[2]:
		if not row is Array or row.size() < 3: return {}
		var source := {}
		for index in mini(game.saves.BUILD_FIELDS.size(), row.size() - 1): source[game.saves.BUILD_FIELDS[index]] = row[index + 1]
		var saved := building(source)
		saved.cell = row[0]
		buildings.append(saved)
	var active: bool = data[1].size() >= 28 and (not data[1][22].is_empty() or int(data[1][24]) > 0 or data[1][26] or not data[1][27].is_empty())
	return {"version":VERSION, "resources":data[1][0].duplicate(true), "buildings":buildings, "tech":data[1][1].duplicate(true), "progress":{"core":data[1][9], "wave":maxi(1, int(data[1][3]) + (0 if active else 1))}}
static func expand(game: Node2D, saved: Dictionary) -> Array:
	if saved.get("version") != VERSION or not saved.get("resources") is Dictionary or not saved.get("tech") is Dictionary or not saved.get("buildings") is Array or not saved.get("progress") is Dictionary: return []
	var progress: Dictionary = saved.progress
	if not progress.get("core") is Vector2i or not progress.get("wave") is int or progress.wave < 1: return []
	var defaults: Node2D = game.get_script().new()
	var tutorial := preload("res://scripts/tutorial.gd").new()
	defaults.add_child(tutorial)
	var resources: Dictionary = defaults.inventory.duplicate(true)
	for item in resources:
		var amount = saved.resources.get(item, 0)
		if not amount is int or amount < 0:
			defaults.free()
			return []
		resources[item] = amount
	var research := {}
	for id in saved.tech:
		if game.TECH.has(id) and saved.tech[id]: research[id] = true
	var rows: Array = []
	var core_cells: Array[Vector2i] = []
	var known := {}
	var counts := {}
	var drill: Vector2i = game.INVALID
	var towers := 0
	var current_health := 200.0
	var seen := {}
	for original in saved.buildings:
		var record = original
		if record is Dictionary and game.Content.REMOVED_BUILDINGS.has(record.get("kind", "")):
			if record.kind == "phase_barrier" and record.get("nuclear", {}).has("underlay"):
				record = record.nuclear.underlay.duplicate(true)
				record.cell = original.cell
			else: continue
		if not record is Dictionary or not record.get("cell") is Vector2i or not game.in_bounds(record.cell) or not (record.get("kind", "") == "core" or game.BUILDINGS.has(record.get("kind", ""))):
			defaults.free()
			return []
		var kind: String = record.kind
		var size: int = game.footprint_size(kind)
		for y in size:
			for x in size:
				var cell: Vector2i = record.cell + Vector2i(x, y)
				if not game.in_bounds(cell) or seen.has(cell):
					defaults.free()
					return []
				seen[cell] = true
		var hp: float = 200.0 if kind == "core" else float(game.BUILDINGS[kind].hp)
		if kind == "solar" and research.has("solar_health"): hp += 10
		var config := {"kind":kind, "dir":0, "input_dir":0, "hp":hp, "max_hp":hp, "item":"", "travel":0.0, "progress":0.0, "cooldown":0.0, "ammo":0, "aim":0.0, "flash":0.0, "buffer":{"copper":0,"iron":0,"verdite":0,"pink":0}, "paid_cost":{}, "tunnel_role":"", "tunnel_pair":game.INVALID, "pulse":0.0, "next_output":0, "route_dir":-1, "color":"red", "shield":false, "pending":false, "booster_type":"", "booster_count":0, "booster_used":0.0, "booster_fire_remaining":0.0, "nuclear":{}}
		config.merge(building(record), true)
		config.buffer.erase("alloy")
		config.paid_cost.erase("alloy")
		if config.item == "alloy": config.item = ""
		for item in game.BUILDINGS.get(kind, {}).get("inputs", {}):
			var capacity: int = game.BUILDINGS[kind].inputs[item]
			var overflow: int = maxi(0, config.buffer.get(item, 0) - capacity)
			if overflow > 0:
				config.buffer[item] = capacity
				if resources.has(item): resources[item] += overflow
		if config.nuclear.has("underlay"):
			var underlay: Dictionary = config.duplicate(true)
			underlay.merge(config.nuclear.underlay, true)
			underlay.kind = "belt"
			underlay.max_hp = game.BUILDINGS.belt.hp
			underlay.pending = false
			underlay.nuclear = config.nuclear.underlay.get("nuclear", {})
			config.nuclear.underlay = underlay
		config.hp = clampf(float(config.hp), 0, hp)
		config.dir = posmod(int(config.dir), 4)
		config.input_dir = posmod(int(config.input_dir), 4)
		if kind == "core":
			core_cells.append(record.cell)
			if record.cell == progress.core: current_health = config.hp
		else: counts[kind] = counts.get(kind, 0) + 1
		if kind == "drill": drill = record.cell
		if game.is_turret(kind): towers += 1
		for item in config.paid_cost: known[item] = true
		for item in config.buffer:
			if config.buffer[item] > 0: known[item] = true
		if config.item != "": known[config.item] = true
		var row: Array = [record.cell]
		for field in game.saves.BUILD_FIELDS: row.append(config[field])
		rows.append(row)
	if not core_cells.has(progress.core):
		defaults.free()
		return []
	var order := -2147483648
	var core_orders := {}
	for gate in game.spawners:
		var cell := Vector2i((gate.position / game.TILE).floor())
		core_orders[cell] = gate.Order
		if cell == progress.core: order = gate.Order
	core_cells.sort_custom(func(a, b): return core_orders.get(a, -2147483648) < core_orders.get(b, -2147483648))
	var completed: int = progress.wave - 1
	var active_order := 2147483647
	var future_orders: Array[int] = []
	for gate in game.spawners:
		if gate.Order > order and not future_orders.has(gate.Order): future_orders.append(gate.Order)
	future_orders.sort()
	var skipped_orders := {}
	var local_completed := completed
	for next_order in future_orders:
		var duration := 0
		var captures_core := false
		for gate in game.spawners:
			if gate.Order == next_order:
				duration = maxi(duration, gate.waves_before_conversion)
				captures_core = captures_core or gate.turns_into_core
		if not captures_core and local_completed >= duration:
			skipped_orders[next_order] = true
			local_completed -= duration
		else:
			active_order = next_order
			break
	var gates: Array = []
	for gate in game.spawners:
		var converted: bool = gate.Order <= order or skipped_orders.has(gate.Order)
		gates.append([gate.waves_before_conversion if converted else (mini(local_completed, gate.waves_before_conversion - 1) if gate.Order == active_order else 0), converted, "red"])
	for item in resources:
		if resources[item] > 0: known[item] = true
	for id in research:
		for item in game.TECH[id].cost: known[item] = true
	known.erase("scrap")
	var advanced: bool = completed > 0 or core_cells.size() > 1
	var ready: bool = advanced or towers > 0 or not research.is_empty() or not game.tutorial_enabled
	tutorial.stage = tutorial.Stage.READY if ready else (tutorial.Stage.BELTS if drill != game.INVALID else (tutorial.Stage.EXTRACTOR if resources.copper >= 5 else (tutorial.Stage.FUNDS if resources.copper > 0 else tutorial.Stage.MINE)))
	tutorial.skipped = ready
	tutorial.onboarding_completed = ready
	tutorial.waves_started = advanced
	tutorial.first_wave_completed = advanced
	tutorial.extractors_ever_built = counts.get("drill", 0)
	tutorial.turrets_ever_built = towers
	tutorial.designated_extractor = drill
	tutorial.tech_available = advanced or not research.is_empty()
	tutorial.barrier_tree_closed = research.has("barriers")
	tutorial.paused_once = advanced
	tutorial.pause_exit_completed = ready
	tutorial.ui_revealed = {"max_core_count":core_cells.size(), "inventory":not known.is_empty(), "palette":rows.size() > core_cells.size(), "waves":ready, "pause":advanced, "tech":tutorial.tech_available, "split":research.has("barriers")}
	var values: Array = []
	for field in game.saves.FIELDS:
		var value = defaults.get(field)
		values.append(value.duplicate(true) if value is Dictionary or value is Array else value)
	values[0] = resources
	values[1] = research
	values[2] = known
	values[3] = completed
	values[4] = (240.0 if core_cells.size() > 1 else defaults.initial_wave_delay) if completed == 0 else defaults.inter_wave_delay
	values[9] = progress.core
	values[10] = core_cells
	values[11] = counts
	values[13] = current_health
	var tutorial_values: Array = []
	for field in game.saves.TUTORIAL_FIELDS: tutorial_values.append(tutorial.get(field))
	var random := RandomNumberGenerator.new()
	random.seed = 42017
	var random_state := random.state
	random.seed = progress.wave
	var result := [VERSION, values, rows, tutorial_values, gates, [], game.cell_center(progress.core), Vector2.ONE, random_state, random.state]
	defaults.free()
	return result
