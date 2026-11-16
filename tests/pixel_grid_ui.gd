extends "res://tests/iron_supply_zoom.gd"
func binary_alpha(picture: Image) -> bool:
	for y in picture.get_height():
		for x in picture.get_width():
			if picture.get_pixel(x, y).a not in [0.0, 1.0]: return false
	return true
func run() -> void:
	fresh()
	game.set_camera_zoom(2.0)
	var pixels = load("res://scripts/pixel_art.gd")
	var raw: Texture2D = load("res://assets/terrain/copper.svg")
	var ore: Texture2D = pixels.texture(raw, Vector2i(64, 64))
	check(ore.get_size() == Vector2(64, 64) and binary_alpha(ore.get_image()) and not ore.get_image().has_mipmaps(), "Ore uses exactly 64 opaque-or-empty pixels per tile side")
	var palette: Dictionary = {}
	for match in RegEx.create_from_string("#[0-9a-fA-F]{6}").search_all(FileAccess.get_file_as_string(raw.resource_path)):
		palette[Color(match.get_string()).to_rgba32()] = true
	var solid_palette := true
	for y in 64:
		for x in 64:
			var color: Color = ore.get_image().get_pixel(x, y)
			if color.a > 0: solid_palette = solid_palette and palette.has(color.to_rgba32())
	check(solid_palette, "Ore outlines contain source colors without blended edge shades")
	check(pixels.texture(raw, Vector2i(64, 64)) == ore, "Sprite baking is cached instead of repeated while playing")
	var enlarged: Image = pixels.texture(raw, Vector2i(32, 32)).get_image()
	enlarged.resize(64, 64, Image.INTERPOLATE_NEAREST)
	check(enlarged.get_data() != ore.get_image().get_data(), "64-pixel SVGs are rasterized directly rather than enlarged from 32-pixel images")
	var ground: TileMapLayer = game.get_node("Level/Ground")
	check(ground.tile_set.tile_size == Vector2i(64, 64) and ground.scale == Vector2(0.5, 0.5), "Tilemaps retain their world footprint while using double-density textures")
	check(game.textures.belt.get_size() == Vector2(64, 64) and game.textures.turret.get_size() == Vector2(128, 128) and game.textures.copper_store.get_size() == Vector2(128, 128), "One- and two-tile sprites use matching 64- and 128-pixel grids")
	check(binary_alpha(game.textures.solar.get_image()) and binary_alpha(game.textures.turret.get_image()), "Building sprite edges have no partial coverage")
	var motion = load("res://scripts/conveyor_motion.gd")
	var first: Texture2D = motion.arrow_texture(0, 0, 0.001)
	check(first == motion.arrow_texture(0, 0, 0.01) and first != motion.arrow_texture(0, 0, 0.063), "Arrows remain stable until moving a complete shader pixel")
	check(first == motion.arrow_texture(0, 0, 0.001 + motion.ARROW_SPACING / motion.SPEED), "Pixel arrow animation loops without a seam")
	var crisp := true
	for direction in 4:
		for incoming in 4:
			crisp = crisp and binary_alpha(motion.arrow_texture(direction, incoming, 0.123).get_image())
	check(crisp, "Straight and corner arrows are rasterized into hard-edged tile pixels")
	var ring: Texture2D = pixels.mining_ring(0.5, Color("e7a468"))
	check(ring.get_size() == Vector2(64, 64) and binary_alpha(ring.get_image()) and ring.get_image().get_pixel(32, 32).a == 0, "The mining ring shares the opaque tile pixel grid")
	check(ring == pixels.mining_ring(0.503, Color("e7a468")), "Mining progress does not redraw fractional arc geometry")
	for zoom in game.ZOOM_LEVELS:
		game.set_camera_zoom(zoom)
		check(is_equal_approx(game.camera.zoom.x, zoom), "Zoom selects an exact preset: " + str(zoom))
	game.set_camera_zoom(0.5)
	game.set_camera_zoom(2.0)
	game._snap_camera_to_pixel_grid()
	check(game.material is ShaderMaterial and game.material.get_shader_parameter("world_pixel_size") == 2.0, "The shader retains a fixed world-space grid at every zoom")
	check(game.hud.next_button.caption.material == null and game.hud.next_button.material == game.material and game.hud.tutorial_prompt.material == null and game.hud.tutorial_prompt.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Text controls bypass the sprite shader and sample fonts at full resolution")
	check(game.tutorial.drag_label.material == null and not game.tutorial.drag_label.use_parent_material, "World tutorial labels render separately from pixelated ghost sprites")
	game.hud.refresh()
	check(game.hud.root.scale == Vector2(1.5, 1.5) and game.hud.next_button.get_global_rect().size.y == 108, "GUI controls are fifty percent larger")
	check(game.hud.palette.get_global_rect().size.x == root.get_visible_rect().size.x, "The scaled bottom GUI still spans the screen")
	var prompt: Label = game.hud.tutorial_prompt
	check(prompt.get_theme_font_size("font_size") * game.hud.root.scale.y == 36 and prompt.position.y * 1.5 > 112, "Tutorial text uses the smaller size while retaining its upper-center position")
	check(game.textures.solar_base != game.textures.solar and game.textures.solar_gun.get_size() == Vector2(64, 64), "Solar panel and cannon have separate native-resolution art")
	check(game.textures.drill.get_size() == Vector2(64, 64) and binary_alpha(game.textures.drill.get_image()), "Extractor artwork retains hard pixel edges at its native resolution")
	var screen := Vector2(1000, 700)
	check((game.hud.root.get_global_transform() * game.hud.ui_point(screen)).distance_to(screen) < 0.01, "Mouse positions round-trip through the enlarged GUI")
	game.hud.show_info("Probe", "Example", screen)
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(game.hud.tooltip.get_global_rect()), "Scaled info popups stay inside the screen")
	game.selected = "belt"
	game.hover_cell = game.current_core + Vector2i(6, 0)
	game.hud.ghost_cost.update_preview(Vector2(1000, 700))
	var bottom: Vector2 = Vector2(game.hover_cell * game.TILE) + Vector2(16, 32)
	var expected: Vector2 = game.get_canvas_transform() * bottom
	var actual: Vector2 = game.hud.ghost_cost.get_global_position() + Vector2(game.hud.ghost_cost.size.x * 0.75, -6)
	check(actual.distance_to(expected) < 0.1, "Enlarged ghost prices remain attached to their world tile")
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	var panel: Control = game.hud.modal.get_child(0)
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(panel.get_global_rect()), "Enlarged research dialogs fit the viewport")
	print("PIXEL GRID UI CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)


