extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	check(game.material is ShaderMaterial, "World shader is enabled")
	check(game.material.get_shader_parameter("world_pixel_size") == game.WORLD_PIXEL_SIZE, "CPU and shader share the world grid")
	var texture: Texture2D = game.textures.belt
	for zoom in [0.5, 1.0, 2.0]:
		game.set_camera_zoom(zoom)
		check(game.textures.belt == texture, "Zoom preserves source artwork")
	for size in [Vector2i(1440, 900), Vector2i(1377, 821)]:
		root.size = size
		for zoom in [0.5, 1.0, 1.37, 2.0]:
			game.camera.zoom = Vector2.ONE * zoom
			for position in [Vector2(811.23, 703.71), Vector2(-13.7, -9.3)]:
				game.camera.position = position
				game._snap_camera_to_pixel_grid()
				var snapped: Vector2 = game.snap_sprite_position(position)
				check(snapped.is_equal_approx(snapped.snapped(Vector2(2, 2))), "Sprite origin lies on world grid")
				check((game.camera.position + game.camera.offset).is_equal_approx(snapped), "Camera and sprite origins use the same grid")
				check(game.camera.position == position, "Simulation position retains precision")
				var offset: Vector2 = game.camera.offset
				game._snap_camera_to_pixel_grid()
				check(game.camera.offset.is_equal_approx(offset), "Snapping does not drift")
	print("SPRITE PIXEL GRID: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
