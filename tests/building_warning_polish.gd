extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var status = preload("res://scripts/building_status.gd")
	var info = preload("res://scripts/structure_info.gd")
	var cell := Vector2i(20, 25)
	game._add_building(cell, "refinery", 0)
	var machine: Dictionary = game.buildings[cell]
	check(not status.has_materials(machine), "Empty producer has no No output warning")
	machine.buffer.copper = 1
	check(status.has_materials(machine), "Buffered inputs enable output warning")
	machine.buffer.copper = 0
	machine.item = "pink"
	check(status.has_materials(machine), "Finished output enables output warning")
	var text: String = info.stats(game, "refinery", machine)
	check(not text.contains("Recipe:") and not text.contains("Refining:") and text.contains("Health:") and text.contains("Stored:"), "Refinery tooltip contains only health and held materials")
	check(info.description(game, "refinery") == "Requires copper and iron to produce pink stuff.", "Refinery description matches request")
	text = info.stats(game, "turret")
	check(text.find("Booster:") > text.find("Ammo:") and text.contains("items/pink.svg"), "Booster has an icon below ammo")
	check(not text.contains("boosted shot") and not text.contains("2x attack"), "Booster explanation removed")
	game.tutorial.ui_revealed.pink_produced = true
	check(game.tutorial.shortcut_lines().has("WASD - move camera"), "Pink production reveals camera shortcut")
	game.inventory.scrap = 1
	game.inventory.pink = 1
	game.hud._sync_tutorial_ui()
	check(game.hud.resource_views.scrap.row.position.y > game.hud.resource_views.pink.row.position.y, "Scrap is below pink inventory")
	print("BUILDING WARNING POLISH CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
