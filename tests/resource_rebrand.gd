extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var text = preload("res://scripts/display_text.gd")
	check(text.format("Copper ore and iron ores produce Pink Material.") == "chicken nuggets resources and fish scales resources produce Pink Stuff.", "Visible resource names are rebranded")
	check(text.format("[img=14x14]res://assets/items/iron.svg[/img] Iron") == "[img=14x14]res://assets/items/iron.svg[/img] fish scales", "Rich text asset IDs remain unchanged")
	check(text.format("Core secured. Mine some more ore.") == "Core secured. Mine some more resources.", "Whole-word replacements leave core and more intact")
	check(game.BUILDINGS.copper_store.cost == {"copper": 40} and game.BUILDINGS.iron_store.cost == {"iron": 40}, "Silos cost forty of their own resource")
	game._add_building(Vector2i(20, 25), "iron_store", 0)
	check(game.material_capacity("iron") == 80 and not game.can_receive(Vector2i(20, 25), "pink"), "Fish-scale silo works without fuel and rejects boosters")
	game.buildings[Vector2i(20, 25)].buffer.pink = 2
	game.advance_logistics(90)
	check(game.buildings[Vector2i(20, 25)].buffer.pink == 2 and game.material_capacity("iron") == 80, "Legacy silo fuel is not burned or needed")
	var core2 := Vector2i(70, 25)
	game.cores.append(core2)
	game._add_building(Vector2i(18, 25), "copper_store", 0)
	check(game.building_cost("copper_store", -1, core2).copper == 44, "Silo inflation counts buildings globally across cores")
	var visual = preload("res://scripts/tower_outlines.gd").new()
	visual.game = game
	game.selected = ""
	game.hover_cell = Vector2i(14, 22)
	game.ores[game.hover_cell] = "iron"
	check(visual.detect_supply_materials().has("iron"), "Hovering ground deposits highlights matching consumers")
	visual.free()
	var names := {}
	for kind in game.Content.ENEMY_TYPES:
		var name: String = game.Content.ENEMY_TYPES[kind].name
		names[name] = true
	check(names.size() == 7 and names.has("Rabbit") and names.has("Elephant") and names.has("Tapir"), "All seven enemies have unique herbivore identities")
	var stat: String = preload("res://scripts/structure_info.gd").boosted_value("4s", "2s")
	check(stat.contains("[s][base_stat]") and not stat.contains("#f3ded566"), "Glyph-only fade leaves native strike fully opaque")
	game.hud.show_info("Copper silo", "Iron ore and Pink Material", Vector2.ZERO)
	check(game.hud.tooltip_title.text == "chicken nuggets silo" and game.hud.tooltip_body.get_parsed_text().contains("fish scales resources and Pink Stuff"), "Tooltips use new display names")
	print("RESOURCE REBRAND CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
