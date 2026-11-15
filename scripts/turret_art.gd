extends RefCounted
## Recolor painted panels, coil lights and barrel bands; retain metal and shadows.
const ACCENTS := {
	"solar": ["527d93", "a4c6c6", "64c5e8"],
	"solar_base": ["527d93", "a4c6c6"],
	"solar_gun": ["64c5e8", "e6b77d"],
	"turret": ["42616c", "edd2a1", "dfad71"],
	"barrel": ["5d7972", "9aaa93"],
	"isotope_lance": ["82bc3c", "e2ffab", "b9ed52"],
	"decay_mortar": ["4d822e", "a3dd49", "e3f994"],
	"breach_beacon": ["edb766", "fff1bb"],
	"containment_engine": ["569632", "c4f577", "f1ffd0"]
}
static var cache: Dictionary = {}
static func texture(source: Texture2D, kind: String, tint: Color) -> Texture2D:
	if not ACCENTS.has(kind): return source
	var path: String = source.get_meta("source_path", source.resource_path)
	var key := "%s:%s:%s:%s" % [path, source.get_size(), kind, tint.to_rgba32()]
	if cache.has(key): return cache[key]
	var image: Image = source.get_image().duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var replacements := {}
	var tones := [tint.darkened(0.2), tint.lightened(0.4), tint]
	for i in ACCENTS[kind].size():
		replacements[Color(ACCENTS[kind][i]).to_rgba32()] = tones[i]
	for y in image.get_height():
		for x in image.get_width():
			var original := image.get_pixel(x, y)
			if original.a < 0.5: continue
			var color = replacements.get(original.to_rgba32())
			if color != null: image.set_pixel(x, y, color)
	var result := ImageTexture.create_from_image(image)
	# HUD icons already have the requested raster size.
	result.set_meta("source_path", path)
	cache[key] = result
	return result
