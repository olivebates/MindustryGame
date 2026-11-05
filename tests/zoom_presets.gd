extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.camera.zoom == Vector2(2, 2) and game.raster_tile_size == 64, "The default zoom is the highest 200-percent preset")
	check(game.sprite_raster_sets.keys().size() == 3 and game.ui_textures.belt.get_size() == Vector2(32, 32), "All three world rasters are cached while UI uses thirty-two-pixel icons")
	game.set_camera_zoom(0.5)
	var smallest: Texture2D = game.textures.belt
	var ui_icon: Texture2D = game.hud.resource_views.copper.icon.texture
	var ore_layer: TileMapLayer = game.get_node("Level/OreDeposits")
	var resource: String = ore_layer.tile_set.get_source(0).get_tile_data(Vector2i.ZERO, 0).get_custom_data("resource")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._unhandled_input(wheel)
	check(game.camera.zoom.x == 0.5, "Scrolling down cannot zoom out past the default")
	wheel.pressed = false
	game._unhandled_input(wheel)
	check(game.camera.zoom.x == 0.5, "The wheel-release event leaves the minimum zoom unchanged")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for expected in [1.0, 2.0, 2.0]:
		wheel.pressed = true
		game._unhandled_input(wheel)
		check(game.camera.zoom.x == expected, "Wheel-up advances one preset and stops at 200 percent")
		wheel.pressed = false
		game._unhandled_input(wheel)
		check(game.camera.zoom.x == expected, "Wheel-up release cannot skip the middle preset")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for expected in [1.0, 0.5, 0.5]:
		wheel.pressed = true
		game._unhandled_input(wheel)
		check(game.camera.zoom.x == expected, "Wheel-down advances one preset and stops at 50 percent")
		wheel.pressed = false
		game._unhandled_input(wheel)
		check(game.camera.zoom.x == expected, "Wheel-down release cannot skip the middle preset")
	for zoom in [2.0, 0.5, 1.0, 2.0, 1.0, 0.5]:
		game.set_camera_zoom(zoom)
		var resolution: int = roundi(zoom * game.TILE)
		check(game.textures.belt.get_size() == Vector2.ONE * resolution and game.textures.turret.get_size() == Vector2.ONE * resolution * 2, "World sprites select the raster matching their zoom and footprint")
		check(ore_layer.tile_set.tile_size == Vector2i.ONE * resolution and ore_layer.scale * Vector2(ore_layer.tile_set.tile_size) == Vector2(32, 32), "Terrain changes density while retaining its world tile size")
		check(ore_layer.tile_set.get_source(0).get_tile_data(Vector2i.ZERO, 0).get_custom_data("resource") == resource, "Growing and shrinking atlas cells preserves ore metadata")
		check(game.ConveyorMotion.arrow_texture(0, 0, 0.13, resolution).get_size() == Vector2.ONE * resolution and game.PixelArt.mining_ring(0.5, Color.WHITE, resolution).get_size() == Vector2.ONE * resolution, "Conveyor markings and mining rings use the same zoom raster")
	check(game.textures.belt == smallest, "Returning to a zoom reuses its existing sprite texture")
	check(game.ui_textures.belt.get_size() == Vector2(32, 32) and game.hud.resource_views.copper.icon.texture == ui_icon, "Zooming never downgrades or replaces UI textures")
	game.set_camera_zoom(-100)
	check(game.camera.zoom.x == 0.5, "Out-of-range zoom requests clamp to the minimum preset")
	game.set_camera_zoom(100)
	check(game.camera.zoom.x == 2.0, "Out-of-range zoom requests clamp to the maximum preset")
	game.set_camera_zoom(1.15)
	check(game.camera.zoom.x == 1.0, "Legacy intermediate zooms snap to the nearest supported preset")
	game.set_camera_zoom(2.0)
	game.saves.capture()
	game.set_camera_zoom(0.5)
	check(game.saves.restore(0) and game.camera.zoom.x == 2.0 and game.textures.belt.get_size() == Vector2(64, 64), "Loading restores both the saved zoom preset and its raster set")
	game.hud.refresh()
	check(game.hud.ui_point(Vector2(300, 200)).is_finite(), "HUD coordinate conversion remains valid after restoring a zoom")
	print("ZOOM PRESET CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)




