extends Node2D
const Forest = preload("res://scripts/forest_terrain.gd")
const FOG_COLOR := Color("142d23")
const OUTLINE_COLOR := Color("10251b")
const OFFSETS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
var game: Node2D
var textures: Dictionary = {}
var cached_key := Vector3i(-1,-1,-1)
var draw_key := Vector3i(-1,-1,-1)
var cached_area := Rect2i()
var boundary_tiles: Dictionary = {}
var solid_runs: Array[Rect2] = []
var edge_cells: Array[Vector2i] = []
var edge_indices: Array[int] = []
var last_disabled := false
var last_resolution := 0
var boundary_rebuilds := 0
var boundary_updates := 0
var draw_cache_builds := 0
func fog_texture(resolution: int) -> Texture2D:
	if not textures.has(resolution):
		textures[resolution] = preload("res://scripts/pixel_art.gd").texture(load("res://assets/terrain/fog_atlas.svg"),Vector2i(16,3) * resolution)
	return textures[resolution]
static func boundary_mask(revealed: Dictionary, cell: Vector2i) -> int:
	var mask := 0
	for index in 8:
		if not revealed.has(cell + OFFSETS[index]): mask |= 1 << index
	return Forest.normalize(mask)
static func boundary_cells(revealed: Dictionary, area: Rect2i = Rect2i()) -> Dictionary:
	var result := {}
	for cell in revealed:
		for offset in OFFSETS:
			var neighbor: Vector2i = cell + offset
			if (area.size == Vector2i.ZERO or area.has_point(neighbor)) and not revealed.has(neighbor): result[neighbor] = true
	return result
func visible_view() -> Rect2:
	return game.get_canvas_transform().affine_inverse() * get_viewport_rect().grow(game.TILE * 2)
func view_area() -> Rect2i:
	var view := visible_view()
	var low := Vector2i((view.position / game.TILE).floor())
	var high := Vector2i((view.end / game.TILE).ceil())
	return Rect2i(low,high-low)
func _process(_dt: float) -> void:
	if game == null: return
	if game.fog_disabled != last_disabled:
		last_disabled = game.fog_disabled
		queue_redraw()
	if game.fog_disabled: return
	# Existing draw commands move with the camera. Redraw only after leaving
	# the padded coverage, changing zoom density, or actually revealing cells.
	if game.render_visibility_key() != draw_key or game.raster_tile_size != last_resolution or not cached_area.encloses(view_area()): queue_redraw()
func update_boundaries() -> void:
	var key: Vector3i = game.render_visibility_key()
	if key == cached_key: return
	Forest.initialize()
	var revealed: Dictionary = game.render_visible_cells()
	if key.x == cached_key.x and key.y == cached_key.y and key.z >= cached_key.z:
		# Capture reveals arrive in distance order; only their eight neighbors
		# can change shape, so do not rescan the whole revealed world.
		for index in range(cached_key.z,key.z):
			var next: Vector3 = game.capture_effect.reveal_order[index]
			var cell := Vector2i(next.x,next.y)
			boundary_tiles.erase(cell)
			for offset in OFFSETS:
				var neighbor: Vector2i = cell + offset
				if not revealed.has(neighbor): boundary_tiles[neighbor] = Forest.indices[boundary_mask(revealed,neighbor)]
		boundary_updates += 1
	else:
		boundary_tiles = boundary_cells(revealed)
		for cell in boundary_tiles: boundary_tiles[cell] = Forest.indices[boundary_mask(revealed,cell)]
		boundary_rebuilds += 1
	cached_key = key
func prepare_draw_cache() -> void:
	update_boundaries()
	var area := view_area()
	var changed := draw_key != cached_key
	if not cached_area.encloses(area):
		cached_area = area.grow(8)
		changed = true
	if not changed: return
	var revealed: Dictionary = game.render_visible_cells()
	solid_runs.clear()
	edge_cells.clear()
	edge_indices.clear()
	for y in range(cached_area.position.y,cached_area.end.y):
		var start := cached_area.position.x
		var in_run := false
		for x in range(cached_area.position.x,cached_area.end.x):
			var cell := Vector2i(x,y)
			if not revealed.has(cell) and not boundary_tiles.has(cell):
				if not in_run:
					start = x
					in_run = true
			elif in_run:
				solid_runs.append(Rect2(Vector2(start,y) * game.TILE,Vector2(x-start,1) * game.TILE))
				in_run = false
		if in_run: solid_runs.append(Rect2(Vector2(start,y) * game.TILE,Vector2(cached_area.end.x-start,1) * game.TILE))
	for cell in boundary_tiles:
		if cached_area.has_point(cell):
			edge_cells.append(cell)
			edge_indices.append(boundary_tiles[cell])
	draw_key = cached_key
	draw_cache_builds += 1
func _draw() -> void:
	if game == null or game.fog_disabled: return
	prepare_draw_cache()
	var resolution: int = game.raster_tile_size
	last_resolution = resolution
	var texture := fog_texture(resolution)
	var solid_index: int = Forest.indices[255]
	var solid_region := Rect2(Vector2(Vector2i(solid_index % 16,solid_index / 16) * resolution),Vector2.ONE * resolution)
	for rect in solid_runs: draw_texture_rect_region(texture,rect,solid_region)
	for entry in edge_cells.size():
		var index := edge_indices[entry]
		var coords := Vector2i(index % 16,index / 16)
		draw_texture_rect_region(texture,Rect2(Vector2(edge_cells[entry] * game.TILE),Vector2.ONE * game.TILE),Rect2(Vector2(coords * resolution),Vector2.ONE * resolution))