extends "res://tests/iron_supply_zoom.gd"
const Fog = preload("res://scripts/fog.gd")
const Forest = preload("res://scripts/forest_terrain.gd")
func run() -> void:
	fresh()
	Forest.initialize()
	for resolution in [16,32,64]:
		var fog_image: Image = game.fog.fog_texture(resolution).get_image()
		var forest_image: Image = Forest.texture(resolution).get_image()
		var matching := true
		var uniform := true
		for mask in Forest.masks:
			var index: int = Forest.indices[mask]
			var fog_origin: Vector2i = Vector2i(index % 16,index / 16) * resolution
			var forest_index: int = Forest.tile_index(mask,0)
			var forest_origin: Vector2i = Vector2i(forest_index % 16,forest_index / 16) * resolution
			for y in resolution:
				for x in resolution:
					var offset := Vector2i(x,y)
					var fog_color := fog_image.get_pixelv(fog_origin + offset)
					var forest_color := forest_image.get_pixelv(forest_origin + offset)
					# The forest outline adds extra alpha passes at the contour.
					# Allow their one-pixel raster fringe around the shared curve.
					if fog_color.a != forest_color.a:
						var near_edge := false
						for neighbor in Fog.OFFSETS:
							var sample: Vector2i = offset + neighbor
							if not Rect2i(0,0,resolution,resolution).has_point(sample): continue
							if fog_color.a == 0 and fog_image.get_pixelv(fog_origin + sample).a > 0: near_edge = true
							if forest_color.a == 0 and forest_image.get_pixelv(forest_origin + sample).a > 0: near_edge = true
						if not near_edge: matching = false
					if fog_color.a > 0 and fog_color != Fog.FOG_COLOR and fog_color != Fog.OUTLINE_COLOR: uniform = false
		check(matching, "All forty-seven fog contours match the forest within one outline pixel at %d pixels" % resolution)
		check(uniform, "Fog uses only opaque dark green and its subtle darker outline at %d pixels" % resolution)
	var outlined: Image = game.fog.fog_texture(64).get_image()
	var isolated_ink := 0
	var interior_ink := 0
	for mask in [0,255]:
		var index: int = Forest.indices[mask]
		var origin := Vector2i(index % 16,index / 16) * 64
		for y in 64:
			for x in 64:
				if outlined.get_pixelv(origin + Vector2i(x,y)) == Fog.OUTLINE_COLOR:
					if mask == 0: isolated_ink += 1
					else: interior_ink += 1
	check(isolated_ink > 50 and interior_ink == 0, "Darker fog outline follows exposed curves without marking interior seams")
	var area := Rect2i(-4,-4,8,8)
	var revealed := {Vector2i.ZERO: true}
	var boundary := Fog.boundary_cells(revealed,area)
	check(boundary.size() == 8 and not boundary.has(Vector2i.ZERO), "Only the eight hidden neighbors of revealed land receive curved boundary tiles")
	check(Fog.boundary_mask(revealed,Vector2i(1,1)) == 127, "Diagonal visibility produces a rounded inner fog corner")
	var neighbors := {}
	for offset in Fog.OFFSETS: neighbors[offset] = true
	check(Fog.boundary_mask(neighbors,Vector2i.ZERO) == 0, "An isolated fog cell receives rounded outer corners")
	check(Fog.boundary_cells({},area).is_empty() and Fog.boundary_mask({},Vector2i(-10000,-10000)) == 255, "Unrevealed space stays fully covered indefinitely, including negative coordinates")
	game.fog_disabled = false
	game.tutorial.skip_to_ready()
	game._reveal_map()
	game.camera.position = game.cell_center(game.current_core) + Vector2(15,12) * game.TILE
	game.camera.force_update_scroll()
	game.fog.queue_redraw()
	game.hud.refresh()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/fog_contours.png")
	print("FOG CONTOUR CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
