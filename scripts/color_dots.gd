extends Control
var colors: Array[String] = []
var active := ""
const TINTS := {"red": Color("f16e64"), "blue": Color("7aa7f0"), "green": Color("83d780")}
func _draw() -> void:
	var index := 0
	for color in ["red", "blue", "green"]:
		if not colors.has(color): continue
		var point := Vector2(8 + index * 24, 9)
		draw_circle(point, 6, TINTS[color])
		if active == color: draw_arc(point, 8, 0, TAU, 32, Color("f3ded5"), 1)
		index += 1
