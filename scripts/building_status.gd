extends Node2D
var game: Node2D
var clock := 0.0
var statuses: Array[Dictionary] = []
const FONT = preload("res://PixelifySans.ttf")
static func missing_inputs(game: Node2D, building: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var required: Array[String] = []
	var data: Dictionary = game.BUILDINGS.get(building.kind, {})
	if data.has("inputs"):
		for item in data.inputs:
			if item != "coolant" or building.kind == "containment_engine": required.append(item)
	if building.kind in ["refinery"]: required.assign(["copper", "iron"])
	elif building.kind in ["healer", "copper_store", "iron_store"]: required.assign(["pink"])
	elif game.is_turret(building.kind) and not data.get("ammo_free", false):
		if building.ammo < 1: missing.append(data.ammo)
	for resource in required:
		var needed: int = data.get("charge_cost", 1) if resource == "verdite" else 1
		if building.buffer.get(resource, 0) < needed: missing.append(resource)
	return missing
static func receiver_accepts(game: Node2D, cell: Vector2i, item: String, source: Vector2i) -> bool:
	var receiver: Dictionary = game.building_at(cell)
	if receiver.is_empty() or receiver.get("pending", false) or game.anchor_at(cell) == source: return false
	var data: Dictionary = game.BUILDINGS.get(receiver.kind, {})
	if data.has("inputs"): return item in data.inputs
	if receiver.kind == "belt": return game.anchor_at(game.output_target(cell, receiver)) != source
	if receiver.kind in ["core", "splitter", "teleporter"]: return true
	if receiver.kind in ["refinery"]: return item in ["copper", "iron"]
	if receiver.kind in ["healer", "copper_store", "iron_store"]: return item == "pink"
	if game.is_turret(receiver.kind):
		return game.Content.BOOSTERS.has(item) or data.get("ammo", "") == item
	return false
static func has_output(game: Node2D, cell: Vector2i, building: Dictionary) -> bool:
	if building.kind == "refinery":
		for port in preload("res://scripts/pink_production.gd").ports(game, cell):
			var belt: Dictionary = game.building_at(port)
			if not belt.is_empty() and belt.kind == "belt" and receiver_accepts(game, port, "pink", cell): return true
		return false
	if building.kind == "drill":
		var item: String = game.ores.get(cell, "copper")
		for direction in game.DIRS:
			if receiver_accepts(game, cell + direction, item, cell): return true
		return false
	return true
static func has_materials(building: Dictionary) -> bool:
	if building.get("item", "") != "": return true
	for amount in building.get("buffer", {}).values():
		if amount > 0: return true
	return false
func _process(dt: float) -> void:
	clock -= dt
	if clock > 0: return
	clock = 0.1
	refresh()
func refresh() -> void:
	statuses.clear()
	for cell in game.buildings:
		var building: Dictionary = game.buildings[cell]
		if building.get("pending", false) or not game.is_cell_visible(cell): continue
		var missing := missing_inputs(game, building)
		var no_output: bool = building.kind in ["refinery"] and has_materials(building) and not has_output(game, cell, building)
		if not missing.is_empty() or no_output: statuses.append({"cell": cell, "missing": missing, "no_output": no_output})
	queue_redraw()
func text_centered(text: String, center: Vector2, font_size: int = 11) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var point := center + Vector2(-width / 2, font_size * 0.35)
	draw_string_outline(FONT, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(FONT, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f3ded5"))
func _draw() -> void:
	for status in statuses:
		if not game.buildings.has(status.cell): continue
		var center: Vector2 = game.building_center(status.cell)
		if not status.missing.is_empty():
			text_centered("Requires", center + Vector2(0, -10))
			var width: float = status.missing.size() * 16 - 2
			for i in status.missing.size():
				var texture: Texture2D = game.ui_textures[status.missing[i] + "_item"]
				var rect := Rect2(center + Vector2(-width / 2 + i * 16, -2), Vector2(14, 14))
				for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
					draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, Color.BLACK)
				draw_texture_rect(texture, rect, false)
		if status.no_output:
			var y := 24.0 if not status.missing.is_empty() else -6.0
			text_centered("No", center + Vector2(0, y))
			text_centered("output", center + Vector2(0, y + 12))
