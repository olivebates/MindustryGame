extends RefCounted
## Fourth-core logistics, support and weapons. All timers are simulation time.
const FUEL := "verdite" # Save-compatible plutonium resource ID.
const GLOW := Color("bbf36b")
const DESCRIPTIONS := {
	"reactor":"Speeds up nearby production using plutonium fuel.",
	"isotope_lance":"Fires a beam that pierces enemies in a straight line.",
	"decay_mortar":"Bombards distant enemies with radioactive shells.",
	"emergency_injector":"Shields and boosts badly damaged turrets.",
	"breach_beacon":"Burns enemies with a laser that scales with their health.",
	"chrono_capacitor":"Slows unslowed enemies after a short delay.",
	"containment_engine":"Pulls enemies together before a powerful blast."
}
static func stats(game: Node2D, kind: String, b: Dictionary) -> String:
	var data: Dictionary = game.BUILDINGS[kind]
	var maximum: float = data.hp
	var health := number(maximum) if b.is_empty() else "%s / %s" % [number(b.hp), number(b.max_hp)]
	var lines: Array[String] = ["Health: " + health, "Size: %d x %d" % [data.size, data.size]]
	if data.has("square"): lines.append("Range: %d x %d tiles" % [data.square, data.square])
	if data.has("range"):
		var reach := number(data.range / game.TILE)
		if data.has("minimum_range"): reach = number(data.minimum_range / game.TILE) + "-" + reach
		lines.append("Range: " + reach + " tiles (radius)")
	var s: Dictionary = b.get("nuclear", {})
	match kind:
		"reactor": lines.append_array(["Boost: +50% production (no stacking)", "Fuel: 1 plutonium / 3s"])
		"isotope_lance": lines.append_array(["Damage: 35 / 3s", "Fuel: 10 shots / plutonium", "Cooling: 5/s"])
		"decay_mortar": lines.append_array(["Damage: 15 / 6s", "Radiation: 5/s for 6s; 2-tile radius", "Fuel: 1 plutonium / shot"])
		"emergency_injector": lines.append_array(["Shield: +50", "Boost: 2x fire rate for 6s", "Trigger: below 50% health", "Cooldown: 30s", "Fuel: 5 plutonium / use"])
		"breach_beacon": lines.append_array(["Damage: 1% max health / second", "Fuel: 1 plutonium / 15s"])
		"chrono_capacitor": lines.append_array(["Slow: 40% for 5s", "Charge: 1s", "Trigger: an unslowed enemy", "Fuel: 2 plutonium / pulse"])
		"containment_engine": lines.append_array(["Damage: 120; 3-tile blast", "Charge: 3s + 2s pull", "Cooldown: 15s", "Fuel: 3 plutonium"])
	if kind == "isotope_lance":
		lines.append("Heat: " + ("100 max" if b.is_empty() else "%s / 100" % number(s.get("heat", 0.0))))
	if not b.is_empty():
		var stored := PackedStringArray()
		for item in data.inputs:
			var asset: String = "plutonium" if item == FUEL else item
			stored.append("[img=12x12]res://assets/items/%s.svg[/img] %d/%d" % [asset, b.buffer.get(item, 0), data.inputs[item]])
		lines.append("Stored: " + "  ".join(stored))
	return "\n".join(lines)
static func number(value: float) -> String:
	return preload("res://scripts/display_numbers.gd").format(value)
static func state(b: Dictionary) -> Dictionary:
	if not b.has("nuclear") or not b.nuclear is Dictionary: b.nuclear = {}
	return b.nuclear
static func in_square(game: Node2D, cell: Vector2i, point: Vector2) -> bool:
	var width: float = game.BUILDINGS.get(game.buildings[cell].kind, {}).get("square", 1) * game.TILE
	return Rect2(game.building_center(cell) - Vector2.ONE * width / 2, Vector2.ONE * width).has_point(point)
static func active(b: Dictionary) -> bool:
	return not b.get("pending", false) and b.hp > 0
static func spend(b: Dictionary, item: String, amount: int = 1) -> bool:
	if b.buffer.get(item, 0) < amount: return false
	b.buffer[item] -= amount
	return true
static func fuel(b: Dictionary, dt: float, duration: float, needed: bool) -> bool:
	var s := state(b)
	if not needed: return false
	if s.get("fuel", 0.0) <= 0.000001:
		if not spend(b, FUEL): return false
		s.fuel = duration
	s.fuel = maxf(0, s.fuel - dt)
	return true
static func production_speed(b: Dictionary) -> float:
	return float(state(b).get("production_speed", 1.0))
static func heavy(game: Node2D, enemy: Dictionary) -> bool:
	return game.Content.ENEMY_TYPES[enemy.kind].size >= 36
static func advance(game: Node2D, dt: float) -> void:
	var radiation: Array = []
	for b in game.buildings.values():
		var s := state(b)
		s.production_speed = 1.0
		s.injected = maxf(0, s.get("injected", 0.0) - dt)
		if s.injected <= 0: s.emergency_shield = 0.0
	for enemy in game.enemies:
		enemy.nuclear_slow_time = maxf(0, enemy.get("nuclear_slow_time", 0.0) - dt)
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if not active(b) or not game.Content.NUCLEAR_KINDS.has(b.kind): continue
		var s := state(b)
		b.cooldown = maxf(0, b.cooldown - dt) if not game.is_turret(b.kind) else b.cooldown
		match b.kind:
			"reactor": reactor(game, cell, b, dt)
			"emergency_injector":
				if b.cooldown > 0: continue
				for target in game.buildings:
					var tower: Dictionary = game.buildings[target]
					if not active(tower) or not game.is_turret(tower.kind) or tower.hp >= tower.max_hp / 2 or state(tower).injected > 0: continue
					if in_square(game, cell, game.building_center(target)) and spend(b, FUEL, 5):
						state(tower).injected = 6.0
						state(tower).emergency_shield = 50.0
						b.cooldown = 30.0
						b.pulse = 1.0
						break
			"chrono_capacitor":
				chrono(game, cell, b, dt)
			"decay_mortar":
				var zones: Array = s.get("zones", [])
				for index in range(zones.size() - 1, -1, -1):
					zones[index].life -= dt
					if zones[index].life <= 0: zones.remove_at(index)
				s.zones = zones
				radiation.append_array(zones)
	# Radiation never stacks, even across different mortars.
	for enemy in game.enemies:
		var irradiated := false
		for zone in radiation:
			if enemy.pos.distance_to(zone.pos) <= game.TILE * 2:
				irradiated = true
				break
		if irradiated: enemy.hp -= dt * 5
static func reactor(game: Node2D, cell: Vector2i, b: Dictionary, dt: float) -> void:
	var s := state(b)
	s.erase("heat")
	s.erase("overheated")
	s.fuel = minf(3.0, s.get("fuel", 0.0))
	var targets: Array[Dictionary] = []
	for target in game.buildings:
		var other: Dictionary = game.buildings[target]
		if not active(other) or not in_square(game, cell, game.building_center(target)): continue
		var working: bool = (other.kind == "drill" and other.item == "") or (other.kind == "refinery" and other.item == "" and other.buffer.get("copper", 0) > 0 and other.buffer.get("iron", 0) > 0)
		if working: targets.append(other)
	if not fuel(b, dt, 3.0, not targets.is_empty()): return
	for other in targets: state(other).production_speed = 1.5
static func chrono(game: Node2D, cell: Vector2i, b: Dictionary, dt: float) -> void:
	var s := state(b)
	var eligible: Array[Dictionary] = []
	for enemy in game.enemies:
		if enemy.hp > 0 and enemy.get("nuclear_slow_time", 0.0) <= 0 and in_square(game, cell, enemy.pos): eligible.append(enemy)
	if b.buffer.get(FUEL, 0) < 2:
		s.pending_enemy = 0
		s.delay = 0.0
		return
	if s.get("pending_enemy", 0) != 0:
		var still_eligible := false
		for enemy in eligible:
			if enemy.info_id == s.pending_enemy: still_eligible = true
		if not still_eligible:
			s.pending_enemy = 0
			s.delay = 0.0
			return
		s.delay = maxf(0, s.delay - dt)
		if s.delay <= 0.000001 and spend(b, FUEL, 2):
			for enemy in eligible: enemy.nuclear_slow_time = 5.0
			s.pending_enemy = 0
			b.pulse = 1.0
	elif not eligible.is_empty():
		eligible.sort_custom(func(a, other): return a.pos.distance_squared_to(game.building_center(cell)) < other.pos.distance_squared_to(game.building_center(cell)))
		s.pending_enemy = eligible[0].info_id
		s.delay = 1.0
static func tower(game: Node2D, cell: Vector2i, b: Dictionary, dt: float) -> void:
	var s := state(b)
	var data: Dictionary = game.BUILDINGS[b.kind]
	b.cooldown = maxf(0, b.cooldown - dt * (2 if s.get("injected", 0.0) > 0 else 1))
	if b.kind == "isotope_lance":
		s.heat = maxf(0, s.get("heat", 0.0) - dt * 5)
		if s.get("overheated", false) and s.heat < 40: s.overheated = false
		if s.get("overheated", false): return
	if b.kind == "containment_engine" and s.get("charge", 0.0) > 0:
		s.charge -= dt
		if s.charge <= 2:
			for enemy in game.enemies:
				pull(game, enemy, s.target, game.TILE * 3, dt * 80)
		if s.charge <= 0:
			blast(game, s.target, game.TILE * 3, 120)
			b.cooldown = 15.0
		return
	if b.cooldown > 0: return
	var target: Dictionary = {}
	var nearest: float = data.range
	for enemy in game.enemies:
		var distance: float = enemy.pos.distance_to(game.building_center(cell))
		if enemy.hp > 0 and distance <= nearest and distance >= data.get("minimum_range", 0):
			target = enemy
			nearest = distance
	if target.is_empty(): return
	var origin: Vector2 = game.building_center(cell)
	b.aim = (target.pos - origin).angle()
	if b.kind == "breach_beacon":
		if not fuel(b, dt, 15.0, true): return
		target.hp -= target.max_hp * 0.01 * dt * (2.0 if s.get("injected", 0.0) > 0 else 1.0)
		game.shots.append({"from":origin,"to":target.pos,"life":0.08,"color":Color("f8c980")})
		b.flash = 1.0
		return
	match b.kind:
		"isotope_lance":
			if s.get("shots", 0) <= 0:
				if not spend(b, FUEL): return
				s.shots = 10
			s.shots -= 1
			var end: Vector2 = origin + Vector2.from_angle(b.aim) * data.range
			for enemy in game.enemies:
				if enemy.pos.distance_to(Geometry2D.get_closest_point_to_segment(enemy.pos, origin, end)) < 16: enemy.hp -= 35
			s.heat += 25
			if s.heat >= 100: s.overheated = true
			game.shots.append({"from":origin,"to":end,"life":0.18,"color":GLOW})
		"decay_mortar":
			if not spend(b, FUEL): return
			blast(game, target.pos, game.TILE * 2, 15)
			var refreshed := false
			for zone in s.get("zones", []):
				if zone.pos.distance_to(target.pos) < game.TILE:
					zone.life = 6.0
					refreshed = true
			if not s.has("zones"): s.zones = []
			if not refreshed: s.zones.append({"pos":target.pos,"life":6.0})
			game.shots.append({"from":origin,"to":target.pos,"life":0.3,"color":GLOW})
		"containment_engine":
			if b.buffer.get(FUEL, 0) < 3: return
			spend(b, FUEL, 3)
			s.charge = 5.0
			s.target = target.pos
			return
	b.cooldown = data.reload
	b.flash = 1.0
	game.play_sound("cannon", origin)
static func blast(game: Node2D, point: Vector2, radius: float, damage: float) -> void:
	for enemy in game.enemies:
		if enemy.pos.distance_to(point) <= radius: enemy.hp -= damage
	game._sparks(point, GLOW, 16)
static func pull(game: Node2D, enemy: Dictionary, point: Vector2, radius: float, distance: float) -> void:
	if enemy.pos.distance_to(point) > radius: return
	var next: Vector2 = enemy.pos.move_toward(point, distance * (0.5 if heavy(game, enemy) else 1.0))
	var cell := Vector2i((next / game.TILE).floor())
	var previous := Vector2i((enemy.pos / game.TILE).floor())
	if game.enemy_navigation.signature == -1: game.enemy_navigation.refresh_grid(game)
	if game.in_bounds(cell) and not game.rocks.has(cell) and not game.occupied.has(cell) and game.enemy_separation.can_step(game.enemy_navigation.runner_grid, previous, cell - previous): enemy.pos = next
static func damage(game: Node2D, cell: Vector2i, amount: float) -> float:
	var s := state(game.buildings[cell])
	var shield: float = s.get("emergency_shield", 0.0)
	var absorbed := minf(amount, shield)
	s.emergency_shield = shield - absorbed
	return amount - absorbed
static func draw(game: Node2D) -> void:
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if not active(b) or not game.Content.NUCLEAR_KINDS.has(b.kind): continue
		var s := state(b)
		var center: Vector2 = game.building_center(cell)
		if b.kind == "decay_mortar":
			for zone in s.get("zones", []): game.draw_circle(zone.pos, game.TILE * 2, Color(GLOW, 0.13))
		if b.kind == "containment_engine" and s.get("charge", 0.0) > 0:
			game.draw_arc(s.target, game.TILE * 3, 0, TAU, 64, GLOW, game.line_width())
			game.draw_line(center, s.target, Color(GLOW, 0.4), game.line_width())
		if b.kind == "chrono_capacitor" and s.get("pending_enemy", 0) != 0:
			game.draw_arc(center, 12, -PI / 2, -PI / 2 + TAU * (1.0 - s.get("delay", 1.0)), 32, Color("91dbe2"), game.line_width())
		if b.kind == "isotope_lance":
			var width: float = game.TILE * game.footprint_size(b.kind)
			game.draw_rect(Rect2(center + Vector2(-width/2, width/2-4), Vector2(width, 3)), Color("18251b"))
			game.draw_rect(Rect2(center + Vector2(-width/2, width/2-4), Vector2(width * s.get("heat",0.0)/100, 3)), Color("f5a55c"))
