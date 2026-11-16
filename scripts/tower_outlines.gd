extends Node2D
var game: Node2D
var hint_clock := 0.0
var supply_materials: Array[String] = []
const PINK := Color("f48bc7")
func _ready() -> void:
	material = game.material
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
	var origin: Vector2 = game.snap_sprite_position(point)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var distance := absi(x) + absi(y)
			if distance > 2: continue
			var color := PINK if filled else Color("251521")
			if distance == 2: color = PINK.lightened(pulse * 0.4) if filled else Color("a76b92")
			if filled and distance == 0: color = Color("fff0fa")
			draw_rect(Rect2(origin + Vector2(x, y) * width, Vector2.ONE * width), color)
func pixel_outline(area: Rect2, color: Color, width: float) -> void:
	# Filled strips occupy exactly one shader cell; centered strokes would
	# straddle two cells and produce uneven thickness.
	draw_rect(Rect2(area.position, Vector2(area.size.x, width)), color)
	draw_rect(Rect2(area.position + Vector2(0, area.size.y - width), Vector2(area.size.x, width)), color)
	draw_rect(Rect2(area.position + Vector2(0, width), Vector2(width, area.size.y - 2 * width)), color)
	draw_rect(Rect2(area.position + Vector2(area.size.x - width, width), Vector2(width, area.size.y - 2 * width)), color)
func _draw() -> void:
	var width: float = game.WORLD_PIXEL_SIZE
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.get("pending", false): continue
		if not game.is_cell_visible(cell): continue
		var center: Vector2 = game.building_center(cell)
		var half_size: float = game.TILE * game.footprint_size(b.kind) / 2.0
		var area := Rect2(Vector2(cell * game.TILE), Vector2.ONE * game.TILE * game.footprint_size(b.kind)).grow(width)
		if game.is_turret(b.kind): pixel_outline(area, game.TEAM_COLORS[b.color], width)
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
			pixel_outline(area.grow(width), color, width)
