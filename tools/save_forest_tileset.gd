extends SceneTree
func _initialize() -> void:
	var tiles := preload("res://scripts/forest_terrain.gd").make_tileset(32, true)
	var error := ResourceSaver.save(tiles, "res://resources/rock_tiles.tres")
	print("FOREST TILESET: ", error_string(error))
	quit(0 if error == OK else 1)
