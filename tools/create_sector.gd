extends SceneTree
## One-time authored scene bootstrap. It deliberately refuses to overwrite painted work.
func _initialize() -> void:
	call_deferred("create_sector")
func tile_set(names: Array[String], ore_data: bool = false) -> TileSet:
	var result := TileSet.new()
	result.tile_size = Vector2i(32, 32)
	if ore_data:
		result.add_custom_data_layer()
		result.set_custom_data_layer_name(0, "resource")
		result.set_custom_data_layer_type(0, TYPE_STRING)
	for index in names.size():
		var source := TileSetAtlasSource.new()
		source.resource_name = names[index].capitalize()
		source.texture = load("res://assets/terrain/%s.svg" % names[index])
		source.texture_region_size = Vector2i(32, 32)
		result.add_source(source, index)
		source.create_tile(Vector2i.ZERO)
		if ore_data: source.get_tile_data(Vector2i.ZERO, 0).set_custom_data("resource", names[index])
	return result
func layer(parent: Node2D, title: String, tiles: TileSet, z: int) -> TileMapLayer:
	var result := TileMapLayer.new()
	result.name = title
	result.tile_set = tiles
	result.z_index = z
	parent.add_child(result)
	result.owner = parent
	return result
func paint_rectangle(target: TileMapLayer, area: Rect2i, source: int) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): target.set_cell(Vector2i(x, y), source, Vector2i.ZERO)
func create_sector() -> void:
	if FileAccess.file_exists("res://scenes/sector.tscn"):
		push_error("sector.tscn already exists. Paint it in the editor; bootstrap will not overwrite it.")
		quit(1)
		return
	var ground_tiles := tile_set(["ground"])
	var rocks_tiles := tile_set(["rock"])
	var ore_tiles := tile_set(["copper", "iron", "verdite"], true)
	ResourceSaver.save(ground_tiles, "res://resources/ground_tiles.tres")
	ResourceSaver.save(rocks_tiles, "res://resources/rock_tiles.tres")
	ResourceSaver.save(ore_tiles, "res://resources/ore_tiles.tres")
	var sector := Node2D.new()
	sector.name = "Sector"
	var ground := layer(sector, "Ground", ground_tiles, -30)
	var ores := layer(sector, "OreDeposits", ore_tiles, -20)
	var rocks := layer(sector, "RockWalls", rocks_tiles, -10)
	paint_rectangle(ground, Rect2i(0, 0, 112, 80), 0)
	# Fixed, hand-authored starter deposits. No random values or runtime generation.
	for cell in [Vector2i(18,21), Vector2i(19,21), Vector2i(20,21), Vector2i(18,22), Vector2i(19,22), Vector2i(20,22), Vector2i(18,23), Vector2i(19,23), Vector2i(20,23)]: ores.set_cell(cell, 0, Vector2i.ZERO)
	for cell in [Vector2i(22,26), Vector2i(23,26), Vector2i(24,26), Vector2i(22,27), Vector2i(23,27), Vector2i(24,27), Vector2i(23,28), Vector2i(24,28)]: ores.set_cell(cell, 1, Vector2i.ZERO)
	paint_rectangle(ores, Rect2i(29, 14, 3, 2), 2)
	paint_rectangle(ores, Rect2i(39, 26, 4, 3), 0)
	paint_rectangle(ores, Rect2i(52, 27, 4, 3), 0)
	paint_rectangle(ores, Rect2i(61, 29, 3, 3), 1)
	paint_rectangle(ores, Rect2i(55, 14, 3, 2), 2)
	paint_rectangle(ores, Rect2i(88, 40, 4, 3), 0)
	paint_rectangle(ores, Rect2i(98, 46, 3, 3), 1)
	paint_rectangle(ores, Rect2i(91, 52, 3, 2), 2)
	paint_rectangle(ores, Rect2i(64, 62, 4, 3), 0)
	paint_rectangle(ores, Rect2i(72, 69, 3, 2), 1)
	paint_rectangle(ores, Rect2i(61, 71, 3, 2), 2)
	for area in [Rect2i(8,8,8,3), Rect2i(11,11,3,8), Rect2i(33,7,10,3), Rect2i(40,10,3,6), Rect2i(6,32,8,4), Rect2i(31,35,12,3), Rect2i(44,30,3,5), Rect2i(51,7,11,3), Rect2i(72,20,5,9), Rect2i(80,52,7,4), Rect2i(100,32,6,5), Rect2i(47,59,9,4), Rect2i(83,66,5,7), Rect2i(26,57,9,3)]: paint_rectangle(rocks, area, 0)
	var marker := Marker2D.new()
	marker.name = "CoreSpawn"
	marker.position = Vector2(752, 720)
	sector.add_child(marker)
	marker.owner = sector
	var scene := PackedScene.new()
	scene.pack(sector)
	var result := ResourceSaver.save(scene, "res://scenes/sector.tscn")
	sector.free()
	print("AUTHORED SECTOR SAVED: ", result)
	quit(result)
