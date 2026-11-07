extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.TECH.time_speed.parent == "copper_storage" and game.TECH.time_speed.cost == {"iron": 5}, "Speed research moved under storage for five iron")
	check(game.TECH.iron_barriers.cost == {"iron": 35, "scrap": 20} and game.BUILDINGS.copper_store.cost == {"scrap": 10, "copper": 2}, "Barrier and silo costs updated")
	check(game.TECH.slugger_shield.parent == "weapons" and game.TECH.slugger_shield.cost == {"iron": 20, "scrap": 10}, "Shield is a Slugger child with requested price")
	game.research("splitter", true)
	var ground := Vector2i(23, 25)
	var belt := Vector2i(24, 25)
	game._add_building(belt, "belt", 0)
	check(game.place_building(ground, "splitter", 0) and game.place_building(belt, "splitter", 0) and game.buildings[belt].kind == "splitter", "Splitters place on ground and replace belts")
	var slug := Vector2i(26, 25)
	game._add_building(slug, "turret", 0)
	game.research("slugger_shield", true)
	check(game.buildings[slug].hp == 150 and game.buildings[slug].shield, "Shield applies to existing 150-health Sluggers")
	game.saves.capture()
	var intact: int = game.saves.current
	game._damage_building(slug, 10000)
	check(game.buildings.has(slug) and game.buildings[slug].hp == 150 and not game.buildings[slug].shield, "First hit is completely negated and shield consumed")
	game._damage_building(slug, 25)
	check(game.buildings[slug].hp == 125, "Subsequent damage hits health")
	game.saves.capture()
	var spent: int = game.saves.current
	check(game.saves.restore(intact) and game.buildings[slug].shield, "Intact shield restores correctly")
	check(game.saves.restore(spent) and not game.buildings[slug].shield and game.buildings[slug].hp == 125, "Spent shield remains spent after restore")
	# Completing a wave recharges the shield before the wave checkpoint is taken.
	game.active_spawners.clear()
	game.victory_shown = true
	game._complete_wave(1)
	check(game.buildings[slug].shield and game.buildings[slug].hp == 125, "Wave completion restores shields without healing health")
	game._add_building(Vector2i(60, 25), "solar", 0)
	game.tutorial.ui_revealed.wave_menu_loaded = true
	game.remove_building(slug, false)
	check(game.tutorial.rewind_hint_active(), "Current core turret loss glows saves even when distant turrets survive")
	game.tutorial.on_wave_menu_opened()
	game.remove_building(Vector2i(60, 25), false)
	check(not game.tutorial.rewind_hint_active(), "Losing a distant turret does not warn about the current core")
	game._add_building(slug, "turret", 0)
	check(game.buildings[slug].shield, "New Sluggers start shielded")
	game.remove_building(slug)
	check(game.tutorial.rewind_hint_active(), "Demolishing the last turret also highlights saves")
	for id in ["barriers", "turret_range", "copper_storage", "weapons", "slugger_shield"]: game.research(id, true)
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	await process_frame
	await process_frame
	var point: Vector2 = game.TECH.weapons.pos + Vector2(108, 64)
	var view = game.hud.tech_scroll
	var on_screen: Vector2 = point * view.zoom + view.graph.position - Vector2(view.scroll_horizontal, view.scroll_vertical)
	check(on_screen.distance_to(view.size / 2) < 2, "Opening tech tree centers the last researched tech")
	check(game.TECH.splitter.pos.x < game.TECH.time_speed.pos.x and game.TECH.time_speed.pos.x < game.TECH.weapons.pos.x, "Speed tech sits between splitter and Slugger")
	print("SLUGGER SHIELD AND TECH CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
