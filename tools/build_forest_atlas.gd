extends SceneTree
## Flat SVG geometry keeps the atlas compatible with Godot's SVG rasterizer.
const Forest = preload("res://scripts/forest_terrain.gd")
const TILE_RECT := [Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)]
const PATCH := [[-25,3],[-22,-4],[-16,-5],[-12,-13],[-7,-8],[0,-15],[5,-10],[12,-12],[16,-6],[23,-5],[26,2],[19,5],[15,10],[8,8],[3,13],[-4,9],[-12,11],[-17,6]]
var pieces: Array[String] = []
func _initialize() -> void: call_deferred("build")
func shape(raw: Array, origin := Vector2.ZERO, scale := Vector2.ONE) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in raw: result.append(Vector2(point[0], point[1]) * scale + origin)
	return result
func polygon(points: PackedVector2Array, color: String) -> void:
	var numbers := PackedStringArray()
	for point in points: numbers.append("%.2f,%.2f" % [point.x, point.y])
	pieces.append('<polygon points="%s" fill="%s"/>' % [" ".join(numbers), color])
func clipped(points: PackedVector2Array, regions: Array[PackedVector2Array], color: String) -> void:
	for region in regions:
		for part in Geometry2D.intersect_polygons(points, region): polygon(part, color)
func add_union(regions: Array[PackedVector2Array], addition: PackedVector2Array) -> void:
	var merged := addition
	var index := 0
	while index < regions.size():
		var result := Geometry2D.merge_polygons(merged, regions[index])
		if result.size() == 1:
			merged = result[0]
			regions.remove_at(index)
			index = 0
		else: index += 1
	regions.append(merged)
func corner_curve(start: Vector2, control: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(1,17):
		var t := step / 16.0
		points.append(start * (1-t) * (1-t) + control * 2 * t * (1-t) + end * t * t)
	return points
func support(mask: int) -> Array[PackedVector2Array]:
	# A continuous terrain contour, with tangent curves at both outward and
	# inward corners. No individual crown shapes protrude from the boundary.
	var result: Array[PackedVector2Array] = []
	var corners := [[1,8,128], [2,1,16], [4,2,32], [8,4,64]]
	for turn in 4:
		var corner: Array = corners[turn]
		var a: bool = mask & corner[0] != 0
		var b: bool = mask & corner[1] != 0
		var points: PackedVector2Array
		if a and b and mask & corner[2]:
			points = shape([[0,0],[32,0],[32,32],[0,32]])
		elif a and b:
			points = shape([[18,0],[32,0],[32,32],[0,32],[0,18]])
			points.append_array(corner_curve(Vector2(0,18),Vector2(18,18),Vector2(18,0)))
		elif a:
			points = shape([[18,0],[32,0],[32,32],[18,32]])
		elif b:
			points = shape([[0,18],[32,18],[32,32],[0,32]])
		else:
			points = shape([[32,18],[32,32],[18,32]])
			points.append_array(corner_curve(Vector2(18,32),Vector2(18,18),Vector2(32,18)))
		for index in points.size():
			points[index] = ((points[index] - Vector2(32,32)).rotated(turn * PI / 2) + Vector2(32,32)).snapped(Vector2(0.0001,0.0001))
		add_union(result,points)
	return result
func tile_seam(a: Vector2, b: Vector2) -> bool:
	for axis in 2:
		if is_equal_approx(a[axis],b[axis]) and (is_zero_approx(a[axis]) or is_equal_approx(a[axis],64)): return true
	return false
func boundary_outline(regions: Array[PackedVector2Array]) -> void:
	# Bake a two-pixel inward outline at 64px density. Shared tile sides
	# are excluded, and clipping keeps stroke caps out of neighboring atlas slots.
	for region in regions:
		var corners := {}
		for index in region.size():
			var a := region[index]
			var b := region[(index+1) % region.size()]
			if tile_seam(a,b): continue
			var normal := (b-a).orthogonal().normalized() * 2
			clipped(PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),[region],"#173d35")
			corners[a] = true
			corners[b] = true
		for center in corners:
			var disc := PackedVector2Array()
			for step in 12: disc.append(center + Vector2.from_angle(step * TAU / 12) * 2)
			clipped(disc,[region],"#173d35")
func build() -> void:
	Forest.initialize()
	pieces.append('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="384" viewBox="0 0 1024 768">')
	for mask_index in Forest.masks.size():
		var mask: int = Forest.masks[mask_index]
		for variant in Forest.variant_count(mask):
			var regions := support(mask)
			var index: int = Forest.tile_index(mask, variant)
			pieces.append('<g transform="translate(%d %d)">' % [(index % 16) * 64, (index / 16) * 64])
			for region in regions: polygon(region, "#27603f")
			# Broad shared boughs wrap across tile joins. Their subdued contrast
			# lets the entire forest read as one continuous mass at gameplay zoom.
			for y in range(-1,2):
				for x in range(-1,2):
					var offset := Vector2(x,y) * 64
					clipped(shape(PATCH, Vector2(0,20) + offset, Vector2(0.66,1.35)), regions, "#307045")
					clipped(shape(PATCH, Vector2(43,62) + offset, Vector2(0.61,0.95)), regions, "#296946")
			# One connected light patch spans several implied crowns; seven
			# interior layouts preserve identical seam pixels without repetition.
			var placements := [Vector2(31,25), Vector2(34,35), Vector2(29,44), Vector2(32,28), Vector2(29,34), Vector2(35,25), Vector2(31,41)]
			var scales := [Vector2(0.94,0.95),Vector2(0.90,1.20),Vector2(0.92,0.88),Vector2(1.03,1.18),Vector2(0.73,1.48),Vector2(0.85,0.81),Vector2(1.0,1.05)]
			var colors := ["#387a47", "#377653", "#3e7b47", "#38744b", "#38784e", "#35744b", "#377848"]
			clipped(shape(PATCH, placements[variant], scales[variant]), regions, colors[variant])
			boundary_outline(regions)
			pieces.append('</g>')
	pieces.append('</svg>')
	var output := FileAccess.open("res://assets/terrain/forest_atlas.svg", FileAccess.WRITE)
	output.store_string("\n".join(pieces))
	print("CONNECTED CANOPY ATLAS: 47 shapes, 191 tiles (7 interior variants), ", pieces.size(), " SVG polygons/groups")
	quit()
