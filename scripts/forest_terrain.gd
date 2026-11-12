extends RefCounted
const COLUMNS := 16
const ROWS := 12
static var masks: Array[int] = []
static var indices: Dictionary = {}
static func normalize(mask: int) -> int:
	var result := mask & 15
	for corner in [[1, 2, 16], [2, 4, 32], [4, 8, 64], [8, 1, 128]]:
		if mask & corner[0] and mask & corner[1] and mask & corner[2]: result |= corner[2]
	return result
static func initialize() -> void:
	if not masks.is_empty(): return
	for mask in 256:
		if normalize(mask) == mask:
			indices[mask] = masks.size()
			masks.append(mask)
static func mask_for(cells: Dictionary, cell: Vector2i) -> int:
	var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var mask := 0
	for index in 8:
		if cells.has(cell + offsets[index]): mask |= 1 << index
	return normalize(mask)
static func variant_count(mask: int) -> int:
	return 7 if mask == 255 else 4
static func tile_index(mask: int, variant: int) -> int:
	initialize()
	# Extra center variants occupy the three unused slots after the atlas's
	# final shape, preserving every existing editor tile coordinate.
	return indices[mask] * 4 + variant
static func variation(cell: Vector2i, count: int = 4) -> int:
	# Mix the high bits before selecting a variant: using the low two bits
	# of the coordinates directly creates a visible four-tile repeating grid.
	var seed_value := ((cell.x * 73856093) ^ (cell.y * 19349663) ^ 42017) & 0x7fffffff
	seed_value = ((seed_value ^ (seed_value >> 16)) * 0x45d9f3b) & 0x7fffffff
	seed_value = ((seed_value ^ (seed_value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return (seed_value ^ (seed_value >> 16)) % count
static func atlas_coords(cells: Dictionary, cell: Vector2i) -> Vector2i:
	initialize()
	var mask := mask_for(cells, cell)
	var index := tile_index(mask, variation(cell, variant_count(mask)))
	return Vector2i(index % COLUMNS, index / COLUMNS)
static func texture(resolution: int) -> Texture2D:
	return preload("res://scripts/pixel_art.gd").texture(load("res://assets/terrain/forest_atlas.svg"), Vector2i(COLUMNS, ROWS) * resolution)
static func make_tileset(resolution: int, editor_texture: bool = false) -> TileSet:
	initialize()
	var tiles := TileSet.new()
	tiles.resource_name = "Pine forest"
	tiles.tile_size = Vector2i.ONE * resolution
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tiles.add_terrain(0)
	tiles.set_terrain_name(0, 0, "Pine forest")
	tiles.set_terrain_color(0, 0, Color("3e6541"))
	var source := TileSetAtlasSource.new()
	source.resource_name = "Forest - 47 shapes, 7 interior variants"
	source.texture = load("res://assets/terrain/forest_atlas.svg") if editor_texture else texture(resolution)
	source.texture_region_size = Vector2i.ONE * resolution
	tiles.add_source(source, 0)
	var neighbors := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER]
	for index in masks.size() * 4 + 3:
		var coords := Vector2i(index % COLUMNS, index / COLUMNS)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.terrain_set = 0
		data.terrain = 0
		var mask: int = masks[mini(index / 4, masks.size() - 1)]
		for bit in 8: data.set_terrain_peering_bit(neighbors[bit], 0 if mask & (1 << bit) else -1)
	return tiles
static func configure(layer: TileMapLayer, resolution: int) -> void:
	initialize()
	var cells := {}
	for cell in layer.get_used_cells(): cells[cell] = true
	var coordinates := {}
	for cell in cells: coordinates[cell] = atlas_coords(cells, cell)
	var tiles := make_tileset(resolution)
	layer.clear()
	layer.tile_set = tiles
	layer.scale = Vector2.ONE * 32.0 / resolution
	for cell in cells: layer.set_cell(cell, 0, coordinates[cell])
	layer.set_meta("forest_terrain", true)
