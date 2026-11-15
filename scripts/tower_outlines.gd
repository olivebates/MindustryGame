extends Node2D
var game: Node2D
var hint_clock := 0.0
var supply_materials: Array[String] = []
const PINK := Color("f48bc7")
func _process(dt: float) -> void:
	hint_clock -= dt
	if hint_clock <= 0:
		hint_clock = 0.15
		supply_materials = detect_supply_materials()
	queue_redraw()
func detects_pink_supply() -> bool:
	return detect_supply_materials().has("pink")
func detect_supply_materials() -> Array[String]:
	var result: Array[String] = []
	if game.ores.has(game.hover_cell): result.append(game.ores[game.hover_cell])
	var queue: Array[Vector2i] = [game.hover_cell]
	if game.selected == "belt":
		for direction in game.DIRS: queue.append(game.hover_cell + direction)
	var visited := {}
	var index := 0
	while index < queue.size() and index < 1024:
		var cell: Vector2i = queue[index]
		index += 1
		var anchor: Vector2i = game.anchor_at(cell)
		if visited.has(anchor): continue
		visited[anchor] = true
		var b: Dictionary = game.building_at(cell)
		if b.is_empty() or b.get("pending", false): continue
		var material: String = b.get("item", "")
		if material != "" and not result.has(material): result.append(material)
		if b.kind == "refinery" and not result.has("pink"): result.append("pink")
		if b.kind == "drill":
			material = game.ores.get(anchor, "copper")
			if not result.has(material): result.append(material)
		if b.kind not in ["belt", "splitter"]: continue
		for direction in game.DIRS: queue.append(cell + direction)
	return result
func needs_material(b: Dictionary, material: String) -> bool:
	if b.get("pending", false): return false
	var data: Dictionary = game.BUILDINGS.get(b.kind, {})
	if data.has("inputs"): return material in data.inputs and b.buffer.get(material, 0) < (data.get("charge_cost", 1) if material == "verdite" else 1)
	if game.is_turret(b.kind):
		if game.Content.BOOSTERS.has(material):
			return b.get("booster_count", 0) == 0
		return not data.get("ammo_free", false) and data.get("ammo", "") == material and b.ammo == 0
	var required: Array = []
	match b.kind:
		"refinery": required = ["copper", "iron"]
		"healer", "copper_store", "iron_store": required = ["pink"]
		"core": return game.inventory.has(material) and game.inventory[material] < game.material_capacity(material)
	return material in required and b.get("buffer", {}).get(material, 0) == 0
func missing_ammo(b: Dictionary) -> String:
	if b.get("pending", false) or not game.is_turret(b.kind): return ""
	var data: Dictionary = game.BUILDINGS[b.kind]
	if data.get("ammo_free", false) or b.get("ammo", 0) > 0: return ""
	return data.get("ammo", "")
func socket(point: Vector2, filled: bool, pulse: float, width: float) -> void:
	var radius := 4.0
	var diamond := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)])
	draw_colored_polygon(diamond, PINK if filled else Color("251521"))
	var border := diamond.duplicate()
	border.append(diamond[0])
	draw_polyline(border, PINK if filled else Color("a76b92"), width * 2)
	if filled:
		draw_circle(point, 1.5, Color("fff0fa"))
		if pulse > 0:
			draw_arc(point, 6 + (1 - pulse) * 5, 0, TAU, 24, Color(PINK, pulse * 0.8), width * 2)
func _draw() -> void:
	var width := 1.0 / get_screen_transform().x.length()
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.get("pending", false): continue
		if not game.is_cell_visible(cell): continue
		var center: Vector2 = game.building_center(cell)
		var half_size: float = game.TILE * game.footprint_size(b.kind) / 2.0
		var area := Rect2(Vector2(cell * game.TILE) - Vector2.ONE * width / 2, Vector2.ONE * (game.TILE * game.footprint_size(b.kind) + width))
		if game.is_turret(b.kind): draw_rect(area, game.TEAM_COLORS[b.color], false, width)
		var boosted: bool = game.is_turret(b.kind) and b.get("booster_count", 0) > 0
		var firing: float = clampf(float(b.get("booster_fire_remaining", 0)) / 0.12, 0, 1)
		var pulse := maxf(firing, 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.004)) if boosted else 0.0
		if game.is_turret(b.kind): socket(center + Vector2(-half_size + 7, -half_size + 7), boosted, pulse, width)
		var needed: Array[String] = []
		var ammo := missing_ammo(b)
		if ammo != "": needed.append(ammo)
		for material in supply_materials:
			if needs_material(b, material) and not needed.has(material): needed.append(material)
		if not needed.is_empty():
			var material: String = needed[int(Time.get_ticks_msec() / 900) % needed.size()]
			var color: Color = game.RESOURCE_COLORS.get(material, Color("d1b6a0"))
			color.a = 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.007)
			draw_rect(area.grow(2), color, false, width * 2)
