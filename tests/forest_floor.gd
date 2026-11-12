extends "res://tests/iron_supply_zoom.gd"
const Floor = preload("res://scripts/ground_terrain.gd")
func run() -> void:
	fresh()
	var authored: TileSet = load("res://resources/ground_tiles.tres")
	check(authored.get_source(0).get_tiles_count() == 32, "Editor exposes all thirty-two floor variants")
	var image := Floor.texture(64).get_image()
	var unique := {}
	var edges_match := true
	var dirt := Color("42332c")
	for index in 32:
		var origin := Vector2i(index % 8,index / 8) * 64
		unique[hash(image.get_region(Rect2i(origin,Vector2i(64,64))).get_data())] = true
		for pixel in 64:
			for offset in [Vector2i(pixel,0),Vector2i(pixel,63),Vector2i(0,pixel),Vector2i(63,pixel)]:
				if image.get_pixelv(origin + offset) != dirt: edges_match = false
	check(unique.size() == 32, "Every floor variant has distinct visible artwork")
	check(edges_match, "Every floor variant shares exactly the same opaque dirt boundary")
	var distribution := {}
	for y in range(-12,12):
		for x in range(-12,12): distribution[Floor.atlas_coords(Vector2i(x,y))] = true
	check(distribution.size() == 32, "Deterministic placement uses every variation, including at negative coordinates")
	var layer := TileMapLayer.new()
	game.add_child(layer)
	layer.tile_set = authored
	var cells: Array[Vector2i] = [Vector2i(-3,7),Vector2i(4,2),Vector2i(0,0)]
	for cell in cells: layer.set_cell(cell,0,Vector2i.ZERO)
	for resolution in [16,32,64]:
		Floor.configure(layer,resolution)
		check(layer.get_used_cells().size() == cells.size() and cells.all(func(cell): return layer.get_cell_atlas_coords(cell) == Floor.atlas_coords(cell)) and layer.scale == Vector2.ONE * 32.0 / resolution, "Zoom preserves every painted cell and its variation at %d pixels" % resolution)
	var ground: TileMapLayer = game.get_node("Level/Ground")
	var before := ground.get_used_cells()
	game.configure_tile_rasters(16)
	game.configure_tile_rasters(64)
	check(ground.get_used_cells().size() == before.size() and before.all(func(cell): return ground.get_cell_atlas_coords(cell) == Floor.atlas_coords(cell)), "Game zoom uses the floor atlas without changing authored layout")
	var preview = preload("res://scripts/save_preview.gd").new()
	preview.configure(game)
	check(preview.ground_texture == Floor.texture(64), "Saved-wave previews use the same floor atlas as the world")
	preview.free()
	print("FOREST FLOOR CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
