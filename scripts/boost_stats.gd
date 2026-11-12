extends Control
var rows: Array[Dictionary] = []
func configure(hud: CanvasLayer, interval: float, damage: float, multiplier: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rows.is_empty():
		for index in 2:
			var y := index * 22.0
			hud.icon(self, hud.game.ui_textures.get("speed3", hud.game.ui_textures.solar), Vector2(0, y + 2), Vector2(14, 14))
			var title: Label = hud.label(self, "Shot interval:" if index == 0 else "DPS:", Vector2(18, y), Vector2(130, 20), 13)
			var base: Label = hud.label(self, "", Vector2(150, y), Vector2(60, 20), 13)
			base.modulate.a = 0.4
			var line := ColorRect.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.color = Color("f3ded5")
			line.position = Vector2(150, y + 9)
			line.size.y = 3
			add_child(line)
			var improved: Label = hud.label(self, "", Vector2(190, y), Vector2(120, 20), 13, Color("83d780"))
			rows.append({"base": base, "line": line, "improved": improved})
	var numbers = preload("res://scripts/display_numbers.gd")
	var old: Array[String] = [numbers.format(interval) + "s", numbers.format(damage / interval)]
	var upgraded: Array[String] = [numbers.format(interval / multiplier) + "s", numbers.format(damage / interval * multiplier)]
	for index in 2:
		rows[index].base.text = old[index]
		var width: float = rows[index].base.get_theme_font("font").get_string_size(old[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		rows[index].line.size.x = width
		rows[index].improved.position.x = 150 + width + 10
		rows[index].improved.text = upgraded[index]
	size = Vector2(314, 44)
	show()
