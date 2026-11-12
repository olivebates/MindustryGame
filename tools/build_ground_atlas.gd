extends SceneTree
## Generate quiet, seamless SVG floor details; all variants share a dirt rim.
var pieces: Array[String] = []
var rng := RandomNumberGenerator.new()
func _initialize() -> void: call_deferred("build")
func polygon(points: PackedVector2Array, color: String) -> void:
	var numbers := PackedStringArray()
	for point in points: numbers.append("%.2f,%.2f" % [point.x,point.y])
	pieces.append('<polygon points="%s" fill="%s"/>' % [" ".join(numbers),color])
func line(points: PackedVector2Array, color: String, width := 1.4) -> void:
	var numbers := PackedStringArray()
	for point in points: numbers.append("%.2f,%.2f" % [point.x,point.y])
	pieces.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/>' % [" ".join(numbers),color,width])
func point(margin := 10.0) -> Vector2:
	return Vector2(rng.randf_range(margin,64-margin),rng.randf_range(margin,64-margin))
func earth_grains(count: int) -> void:
	for index in count:
		var p := point(8)
		var length := rng.randf_range(2,4)
		polygon(PackedVector2Array([p,p+Vector2(length,-1),p+Vector2(length+1,1),p+Vector2(0,2)]), "#4a3a30" if index % 2 else "#3d3029")
func needles(center: Vector2, count: int) -> void:
	for index in count:
		var p := center + Vector2(rng.randf_range(-6,6),rng.randf_range(-5,5))
		var direction := Vector2.from_angle(rng.randf_range(-PI,PI))
		line(PackedVector2Array([p-direction*2,p+direction*rng.randf_range(3,6)]), "#4d3d32" if index % 2 else "#493a30",1.1)
func build() -> void:
	pieces.append('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 512 256">')
	for variant in 32:
		rng.seed = 91673 + variant * 57037
		pieces.append('<g transform="translate(%d %d)"><rect width="64" height="64" fill="#42332c"/>' % [(variant%8)*64,(variant/8)*64])
		match variant / 8:
			0:
				earth_grains(2 + variant % 4)
			1:
				earth_grains(2)
				needles(point(20),5 + variant % 3)
				if variant % 2: needles(point(20),3)
			2:
				earth_grains(4 + variant % 3)
				if variant % 2 == 0: needles(point(20),3)
			3:
				var p := point(24)
				var direction := Vector2.from_angle(rng.randf_range(-PI,PI))
				var bend := p + direction * 6 + Vector2(-2,2)
				line(PackedVector2Array([p-direction*10,p,bend,p+direction*13]),"#4a3930",1.6)
				line(PackedVector2Array([p,p+direction.rotated(0.85)*8]),"#4a3930",1.2)
				var leaf := point(16)
				polygon(PackedVector2Array([leaf+Vector2(-4,0),leaf+Vector2(0,-3),leaf+Vector2(5,-1),leaf+Vector2(1,3)]),"#4c3a30")
				earth_grains(2)
		pieces.append('</g>')
	pieces.append('</svg>')
	FileAccess.open("res://assets/terrain/ground_atlas.svg",FileAccess.WRITE).store_string("\n".join(pieces))
	print("FOREST FLOOR ATLAS: 32 variations")
	quit()
