extends RefCounted
## Rasterize SVGs at their requested density, preserving hard palette edges.
const PIXELS_PER_TILE := 64
const PIXELS_PER_WORLD_UNIT := 2
static var textures: Dictionary = {}
static var rings: Dictionary = {}
static var circle_pixels: Dictionary = {}
static func texture(source: Texture2D, dimensions: Vector2i) -> Texture2D:
	var path := source.resource_path
	if source.has_meta("source_path"):
		if source.get_size() == Vector2(dimensions): return source
		path = source.get_meta("source_path")
	var key := "%s:%s" % [path, dimensions]
	if textures.has(key): return textures[key]
	var picture := source.get_image()
	if picture == null: return source
	var code := ""
	if path.ends_with(".svg"):
		code = FileAccess.get_file_as_string(path)
		var vector_image := Image.new()
		if vector_image.load_svg_from_string(code) == OK:
			var factor := float(dimensions.x) / vector_image.get_width()
			if not is_equal_approx(factor, 1.0): vector_image.load_svg_from_string(code, factor)
			picture = vector_image
	picture.convert(Image.FORMAT_RGBA8)
	picture.clear_mipmaps()
	picture.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_NEAREST)
	var palette: Array[Color] = []
	if path.ends_with(".svg"):
		var definitions := RegEx.create_from_string("(?s)<defs>.*?</defs>")
		code = definitions.sub(code, "", true)
		for match in RegEx.create_from_string("#[0-9a-fA-F]{6}").search_all(code):
			var color := Color(match.get_string())
			if not palette.has(color): palette.append(color)
	var mapped: Dictionary = {}
	for y in dimensions.y:
		for x in dimensions.x:
			var color := picture.get_pixel(x, y)
			if color.a < 0.5:
				picture.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			color.a = 1.0
			var rgba := color.to_rgba32()
			if not mapped.has(rgba):
				var nearest := color
				var distance := INF
				for candidate in palette:
					var difference := Vector3(color.r - candidate.r, color.g - candidate.g, color.b - candidate.b).length_squared()
					if difference < distance:
						distance = difference
						nearest = candidate
				mapped[rgba] = nearest
			picture.set_pixel(x, y, mapped[rgba])
	var baked := ImageTexture.create_from_image(picture)
	baked.set_meta("source_path", path)
	textures[key] = baked
	return baked
static func mining_ring(progress: float, color: Color, resolution: int = PIXELS_PER_TILE) -> Texture2D:
	var step := clampi(floori(progress * 96), 0, 96)
	var key := "%s:%d:%d" % [color.to_rgba32(), step, resolution]
	if rings.has(key): return rings[key]
	if not circle_pixels.has(resolution):
		var points: Array[Vector3] = []
		for y in resolution:
			for x in resolution:
				var point := Vector2(x + 0.5, y + 0.5) * 32.0 / resolution - Vector2(16, 16)
				if point.length_squared() < 12 * 12 or point.length_squared() > 14 * 14: continue
				points.append(Vector3(x, y, fposmod(point.angle() + PI / 2, TAU) / TAU))
		circle_pixels[resolution] = points
	var picture := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	for point in circle_pixels[resolution]:
		if point.z <= float(step) / 96.0: picture.set_pixel(int(point.x), int(point.y), color)
	var baked := ImageTexture.create_from_image(picture)
	rings[key] = baked
	return baked
