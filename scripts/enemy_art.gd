extends RefCounted
# Keep natural fur/skin colors; only the separate markings receive wave colors.
static func composite(base: Texture2D, marking: Texture2D, tint: Color) -> Texture2D:
	var image := base.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var overlay := marking.get_image()
	for y in overlay.get_height():
		for x in overlay.get_width():
			var color := overlay.get_pixel(x, y)
			if color.a <= 0: continue
			var original := image.get_pixel(x,y)
			if original.a <= 0: continue
			color *= tint
			image.set_pixel(x, y, original.blend(color))
	var result := ImageTexture.create_from_image(image)
	result.set_meta("source_path", "generated://enemy/%s/%s" % [base.get_meta("source_path", str(base.get_rid())), tint.to_rgba32()])
	return result
static func assemble(body: Texture2D, head: Texture2D) -> Texture2D:
	var image := body.get_image()
	var overlay := head.get_image()
	image.blend_rect(overlay,Rect2i(Vector2i.ZERO,overlay.get_size()),Vector2i.ZERO)
	var result := ImageTexture.create_from_image(image)
	result.set_meta("source_path","generated://enemy/full/%s/%s" % [body.get_meta("source_path",""),head.get_meta("source_path","")])
	return result
