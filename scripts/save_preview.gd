extends Node2D
var core := Vector2i.ZERO
var tiles: Dictionary = {}
var buildings: Dictionary = {}
var textures: Dictionary = {}
var terrain: Dictionary = {}
var conveyor_upgraded := false
var iron_barriers := false
var forest_cells: Dictionary = {}
var forest_texture: Texture2D
var ground_texture: Texture2D
func configure(game: Node2D, snapshot: Array = []) -> void:
	iron_barriers = game.researched.has("iron_barriers") if snapshot.is_empty() else snapshot[1][1].has("iron_barriers")
	core = game.current_core if snapshot.is_empty() else snapshot[1][9]
	conveyor_upgraded = game.researched.has("conveyor_speed") if snapshot.is_empty() else snapshot[1][1].has("conveyor_speed")
	buildings = game.buildings.duplicate(true) if snapshot.is_empty() else {}
	if not snapshot.is_empty():
		for row in snapshot[2]:
			var building: Dictionary = {}
			for i in game.saves.BUILD_FIELDS.size(): building[game.saves.BUILD_FIELDS[i]] = row[i + 1]
			buildings[row[0]] = building
	textures = game.sprite_rasters(64).duplicate()
	forest_cells = game.rocks
	forest_texture = preload("res://scripts/forest_terrain.gd").texture(64)
	ground_texture = preload("res://scripts/ground_terrain.gd").texture(64)
	for id in ["ground", "rock", "copper", "iron", "verdite"]: terrain[id] = preload("res://scripts/pixel_art.gd").texture(load("res://assets/terrain/%s.svg" % id), Vector2i(64, 64))
	for y in range(core.y - 20, core.y + 21):
		for x in range(core.x - 20, core.x + 21):
			var cell := Vector2i(x, y)
			if not game.in_bounds(cell) or not snapshot_visible(game, cell, snapshot): continue
			tiles[cell] = "rock" if game.rocks.has(cell) else game.ores.get(cell, "ground")
func snapshot_visible(game: Node2D, cell: Vector2i, snapshot: Array) -> bool:
	if snapshot.is_empty(): return game.is_cell_visible(cell)
	for base in snapshot[1][10]:
		if cell.distance_squared_to(base) <= 400: return true
	if snapshot[3][0] < 5: return false
	var active_order := 2147483647
	for i in game.spawners.size():
		if not snapshot[4][i][1]: active_order = mini(active_order, game.spawners[i].Order)
	var point: Vector2 = game.cell_center(cell)
	for i in game.spawners.size():
		if snapshot[4][i][1] or game.spawners[i].Order != active_order: continue
		var nearest := Geometry2D.get_closest_point_to_segment(point, game.cell_center(core), game.spawners[i].position)
		if point.distance_to(nearest) <= game.TILE * 10: return true
	return false

func capture_bounds(game: Node2D) -> Rect2:
	var center: Vector2 = game.cell_center(core)
	var bounds := Rect2(center - Vector2.ONE * 22, Vector2.ONE * 44)
	for cell in buildings:
		var building: Dictionary = buildings[cell]
		var size: int = 1 if building.kind == "core" else game.BUILDINGS[building.kind].size
		var area := Rect2(Vector2(cell * game.TILE), Vector2.ONE * game.TILE * size)
		if area.get_center().distance_to(center) <= game.core_build_radius * game.TILE:
			bounds = bounds.merge(area)
	bounds = bounds.grow(game.TILE * 2)
	var side := maxf(bounds.size.x, bounds.size.y)
	return Rect2(bounds.get_center() - Vector2.ONE * side / 2, Vector2.ONE * side)
func _draw() -> void:
	for cell in tiles:
		var rect := Rect2(Vector2(cell * 32), Vector2(32, 32))
		var ground_coords := preload("res://scripts/ground_terrain.gd").atlas_coords(cell)
		draw_texture_rect_region(ground_texture,rect,Rect2(Vector2(ground_coords*64),Vector2(64,64)))
		if tiles[cell] == "rock":
			var coords := preload("res://scripts/forest_terrain.gd").atlas_coords(forest_cells, cell)
			draw_texture_rect_region(forest_texture, rect, Rect2(Vector2(coords * 64), Vector2(64, 64)))
		elif tiles[cell] != "ground": draw_texture_rect(terrain[tiles[cell]], rect, false)
	for cell in buildings:
		if not tiles.has(cell): continue
		var b: Dictionary = buildings[cell]
		var footprint: int = 1 if b.kind == "core" else preload("res://scripts/content.gd").BUILDINGS[b.kind].size
		var dimension: float = 44 if b.kind == "core" else 32 * footprint
		var center := Vector2(cell * 32) + Vector2.ONE * 16 * footprint
		var texture: Texture2D = textures.belt_dark if b.kind == "belt" and not conveyor_upgraded else textures[b.kind]
		if b.kind == "solar": texture = textures.solar_base
		if b.kind == "teleporter" and (b.tunnel_role == "exit" or (b.tunnel_role == "" and buildings.has(b.tunnel_pair) and buildings.keys().find(cell) > buildings.keys().find(b.tunnel_pair))):
			texture = textures["teleporter_output_%d" % int(b.dir)]
		if b.kind == "core" and cell != core: texture = textures.core_inactive
		if b.get("pending", false):
			preload("res://scripts/drawing_style.gd").draw_construction(self, texture, Rect2(center - Vector2.ONE * dimension / 2, Vector2.ONE * dimension))
			continue
		var angle: float = b.dir * PI / 2.0 if b.kind == "belt" else 0.0
		var flip := Vector2.ONE
		if b.kind == "belt" and b.tunnel_role != "": texture = textures["tunnel_" + b.tunnel_role]
		elif b.kind == "belt" and (int(b.dir) - int(b.input_dir) + 4) % 2 == 1:
			texture = textures.belt_corner if conveyor_upgraded else textures.belt_corner_dark
			angle = b.input_dir * PI / 2.0
			if (int(b.dir) - int(b.input_dir) + 4) % 4 == 3: flip.y = -1
		if b.kind == "belt" and b.tunnel_role == "":
			var mask: int = 1 << int(b.dir)
			var directions := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
			for side in 4:
				var neighbor: Vector2i = cell + directions[side]
				if not buildings.has(neighbor): continue
				var other: Dictionary = buildings[neighbor]
				if (other.kind == "belt" and other.tunnel_role != "entry" and neighbor + directions[other.dir] == cell) or other.kind in ["drill", "splitter"]: mask |= 1 << side
			if mask in [7, 11, 13, 14, 15]:
				texture = textures["belt_junction_%d%s" % [mask, "" if conveyor_upgraded else "_dark"]]
				angle = 0.0
				flip = Vector2.ONE
		draw_set_transform(center, angle, flip)
		draw_texture_rect(texture, Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension), false)
		draw_set_transform(Vector2.ZERO)
		if b.kind == "turret" and b.get("shield", false):
			preload("res://scripts/drawing_style.gd").draw_shield(self, Rect2(center - Vector2.ONE * (dimension / 2 + 3), Vector2.ONE * (dimension + 6)), 1.0, line_width())
		if b.kind in ["solar", "turret", "repeater", "cannon"]:
			draw_rect(Rect2(Vector2(cell * 32) - Vector2.ONE, Vector2.ONE * (dimension + 2)), {"red": Color("f16e64"), "green": Color("83d780"), "blue": Color("7aa7f0")}[b.color], false, line_width())
			draw_set_transform(center + Vector2(0, 2) if b.kind == "solar" else center, b.aim)
			if b.kind == "solar": draw_texture_rect(textures.solar_gun, Rect2(-16, -16, 32, 32), false)
			else: draw_texture_rect(textures.barrel, Rect2(-16, -16, 32, 32), false)
			draw_set_transform(Vector2.ZERO)

func line_width() -> float:
	return 1.0 / get_screen_transform().x.length()
