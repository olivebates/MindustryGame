extends RefCounted
## Deterministic artwork variations for the hand-painted ground cells.
const COLUMNS := 8
const ROWS := 4
const VARIANTS := COLUMNS * ROWS
static var tilesets: Dictionary = {}
static func atlas_coords(cell: Vector2i) -> Vector2i:
	var index := preload("res://scripts/forest_terrain.gd").variation(cell, VARIANTS)
	return Vector2i(index % COLUMNS, index / COLUMNS)
static func texture(resolution: int) -> Texture2D:
	return preload("res://scripts/pixel_art.gd").texture(load("res://assets/terrain/ground_atlas.svg"), Vector2i(COLUMNS, ROWS) * resolution)
static func make_tileset(resolution: int, editor_texture: bool = false) -> TileSet:
	if not editor_texture and tilesets.has(resolution): return tilesets[resolution]
	var tiles := TileSet.new()
	tiles.resource_name = "Forest floor"
	tiles.tile_size = Vector2i.ONE * resolution
	var source := TileSetAtlasSource.new()
	source.resource_name = "Forest floor - 32 variations"
	source.texture = load("res://assets/terrain/ground_atlas.svg") if editor_texture else texture(resolution)
	source.texture_region_size = Vector2i.ONE * resolution
	tiles.add_source(source, 0)
	for index in VARIANTS: source.create_tile(Vector2i(index % COLUMNS, index / COLUMNS))
	if not editor_texture: tilesets[resolution] = tiles
	return tiles
static func configure(layer: TileMapLayer, resolution: int) -> void:
	var cells := layer.get_used_cells()
	layer.clear()
	layer.tile_set = make_tileset(resolution)
	layer.scale = Vector2.ONE * 32.0 / resolution
	for cell in cells: layer.set_cell(cell, 0, atlas_coords(cell))
	layer.set_meta("ground_terrain", true)
