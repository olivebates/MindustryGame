extends "res://tools/build_forest_atlas.gd"
## Reuse the forest's exact contours, with one solid color and no foliage.
func build() -> void:
	Forest.initialize()
	pieces.clear()
	pieces.append('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="96" viewBox="0 0 1024 192">')
	for index in Forest.masks.size():
		pieces.append('<g transform="translate(%d %d)">' % [(index % 16) * 64,(index / 16) * 64])
		var regions := support(Forest.masks[index])
		for region in regions: polygon(region,"#142d23")
		var outline_start := pieces.size()
		boundary_outline(regions)
		var colors := RegEx.create_from_string("#[0-9a-fA-F]{6}")
		for part in range(outline_start,pieces.size()): pieces[part] = colors.sub(pieces[part],"#10251b",true)
		pieces.append('</g>')
	pieces.append('</svg>')
	FileAccess.open("res://assets/terrain/fog_atlas.svg",FileAccess.WRITE).store_string("\n".join(pieces))
	print("FOG ATLAS: 47 matching forest contours")
	quit()
