extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.tutorial_enabled = false
	game.inventory.erase("scrap")
	for kind in ["forge", "alloy_store", "repeater", "cannon"]:
		check(not game.BUILDINGS.has(kind), kind + " is removed")
	for id in ["conveyor_speed", "build_hotkeys", "industry", "forge", "armor", "repeater", "mining", "cannon", "damage", "turret_red", "solar_blue"]:
		check(not game.TECH.has(id), id + " is removed from research")
	check(not game.Content.RESOURCES.has("alloy") and not game.inventory.has("alloy"), "Repair alloy is removed")
	check(game.TECH.turret_color.parent == "healer" and game.TECH.turret_color.core == 4, "Turret Color follows Heal Beacon at core four")
	for id in ["reactor", "plutonium_storage"]:
		check(game.TECH[id].parent == "turret_color" and game.TECH[id].core == 4, id + " follows Turret Color")
	check(game.BUILDINGS.verdite_store.tech == "plutonium_storage", "Plutonium silo keeps its own technology")
	for id in game.TECH: game.research(id, true)
	var filters = game.hud.build_filters
	game.discovered_resources.verdite = true
	game.discovered_resources.pink = true
	game.hud.refresh()
	await process_frame
	check(filters.material_bar.size.y == 32 and filters.color_bar.size.y == 32, "Both bars are 32 pixels high")
	check(filters.material_bar.offset_top == -104 and filters.color_bar.offset_top == -136, "Bars sit directly above the toolbar")
	for target in filters.material_buttons.values():
		check(target.size == Vector2(64, 32) and target.text == "", "Material buttons are 64 pixels wide and icon only")
	check(filters.material_buttons.base.get_child_count() == 2, "Nuggets and scales share a button with both icons")
	for kind in game.BUILDINGS:
		if game.is_turret(kind): check(game.unlocked_colors(kind).size() == 3, kind + " unlocks every color")
	game.hud.category = "Defence"
	filters.select_color("blue")
	check(game.build_color == "blue", "Selected color controls turret construction")
	for color in filters.color_buttons:
		check(filters.color_buttons[color].button_pressed == (color == "blue"), "Only selected color is active: " + color)
	for kind in game.hud.cards:
		if not game.is_turret(kind): continue
		var sprites = game.hud.cards[kind].find_children("*", "TextureRect", false, false)
		check(not sprites.is_empty() and sprites[0].modulate == Color.WHITE and sprites[0].texture != game.ui_textures[kind], kind + " menu sprite uses accent coloring")
		var original: Image = preload("res://scripts/pixel_art.gd").texture(game.ui_textures[kind], Vector2i(32, 32)).get_image()
		for color in game.TEAM_COLORS:
			var colored: Image = preload("res://scripts/turret_art.gd").texture(preload("res://scripts/pixel_art.gd").texture(game.ui_textures[kind], Vector2i(32,32)), kind, game.TEAM_COLORS[color]).get_image()
			var changed := 0
			var unchanged := 0
			var alpha_preserved := true
			for y in 32:
				for x in 32:
					var before := original.get_pixel(x,y)
					var after := colored.get_pixel(x,y)
					alpha_preserved = alpha_preserved and before.a == after.a
					if before.a < 0.5: continue
					if before == after: unchanged += 1
					else: changed += 1
			check(changed > 0 and unchanged > changed and alpha_preserved, kind + " " + color + " changes only accents, preserving most artwork and transparency (%d/%d, alpha %s)" % [changed, unchanged, alpha_preserved])
	check(filters.color_buttons.blue.visible, "Color buttons appear in the open turret menu")
	game.hud.hide_tray()
	filters.refresh()
	check(not filters.color_buttons.blue.visible, "Closing turret menu hides color buttons")
	game.hud._rebuild_cards()
	var cell := Vector2i(32, 25)
	game.inventory.copper = 10000
	game.inventory.iron = 10000
	game.inventory.verdite = 10000
	game.inventory.pink = 10000
	game.place_building(cell, "solar", 0)
	check(game.building_at(cell).get("color", "") == "blue", "Placed turret uses selected color")
	check(filters.group_for("verdite_store") == "verdite", "Plutonium silo belongs to plutonium filter")
	filters.toggle_material("verdite")
	check(not filters.allows("reactor") and not filters.allows("verdite_store") and filters.allows("belt"), "Plutonium filter only hides associated structures")
	game.hud.category = "Infrastructure"
	game.hud._rebuild_cards()
	filters.refresh()
	check(not filters.color_buttons.blue.visible, "Other structure menus hide color buttons")
	check(not game.hud.cards.has("verdite_store") and game.hud.cards.has("iron_store"), "Filtered menu hides plutonium silos")
	filters.toggle_material("base")
	filters.toggle_material("pink")
	check(game.hud.cards.is_empty() and not game.hud.expanded.visible, "All filters off hides an empty structure menu")
	game.hud.preview_kind = "reactor"
	filters.refresh_description()
	check(filters.description.text.contains("production"), "Upper bar shows hovered structure description")
	game.researched.erase("turret_color")
	filters.refresh()
	check(game.build_color == "red" and game.unlocked_colors("solar") == ["red"], "Without color research only red is available")
	check(not filters.color_buttons.blue.visible, "Color buttons wait for research")
	var state = preload("res://scripts/save_state.gd")
	var old: Dictionary = state.capture(game)
	old.resources.alloy = 500
	old.tech.industry = true
	old.tech.solar_green = true
	for kind in ["forge", "alloy_store", "repeater", "cannon"]:
		old.buildings.append({"kind":kind,"cell":Vector2i(80,80)})
	var restored: Array = state.expand(game, old)
	check(not restored.is_empty(), "Older saves remain loadable after content removal")
	check(not restored[1][0].has("alloy") and not restored[1][1].has("industry") and not restored[1][1].has("solar_green"), "Migration discards retired resources and technologies")
	check(restored[2].size() == game.buildings.size(), "Migration removes retired structures while preserving active ones")
	print("BUILD FILTERS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
