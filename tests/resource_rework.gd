extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	game.inventory.erase("scrap")
	check(not game.Content.RESOURCES.has("scrap") and not game.TECH.has("auto_scrap") and not game.BUILDINGS.has("scrap_store"), "Scrap resource, depot and auto pickup research are removed")
	var clean := true
	for data in game.TECH.values(): clean = clean and not data.cost.has("scrap")
	for data in game.BUILDINGS.values(): clean = clean and not data.cost.has("scrap")
	check(clean, "No technology or building costs scrap")
	game.spawn_scrap(50, Vector2.ZERO)
	check(game.scraps.is_empty() and game.add_resource("scrap", 10) == 0, "Removed resource cannot drop or enter inventory")
	check(game.TECH.splitter.core == 2 and game.TECH.weapons.core == 2, "Splitter and slugger unlock at core two")
	check(game.TECH.refining.parent == "weapons" and game.TECH.refining.core == 3, "Distillery follows slugger at core three")
	for id in ["copper_storage", "iron_storage", "healer"]:
		check(game.TECH[id].parent == "refining" and game.TECH[id].core == 3, id + " follows distillery at core three")
	check(game.TECH.healer.cost == {"iron": 55}, "Restoration research costs 55 scales")
	var wall := Vector2i(26,25)
	game._add_building(wall,"wall",0)
	game.research("iron_barriers",true)
	game._add_building(Vector2i(27,25),"wall_iron",0)
	check(game.buildings[wall].max_hp == 40 and game.buildings[Vector2i(27,25)].max_hp == 120 and game.BUILDINGS.wall_iron.cost == {"iron":4}, "Scale barriers are independent and triple the health")
	game.buildings[game.current_core].hp = 20
	game.core_health = 20
	game.active_spawners.clear()
	game._complete_wave(1,true)
	check(game.core_health == 200 and game.buildings[game.current_core].hp == 200, "Core fully heals at wave completion")
	var checkpoint: Array = game.saves.snapshot()
	checkpoint[1][0].scrap = 100
	checkpoint[1][1].auto_scrap = true
	game.saves.restore_snapshot(checkpoint,-1)
	check(not game.inventory.has("scrap") and not game.researched.has("auto_scrap") and game.scraps.is_empty(), "Old checkpoints discard removed scrap state")
	check(game.buildings[wall].max_hp == 40 and game.buildings[Vector2i(27,25)].max_hp == 120, "Separate barrier types survive checkpoint restore")
	var gate = load("res://scripts/enemy_spawn.gd").new()
	var fields := {}
	for property in gate.get_property_list(): fields[property.name] = property
	check(fields.allowed_enemies.hint_string.contains("Squirrel") and fields.possible_colors.hint_string.contains("red"), "Enemy and color arrays have enum dropdown hints")
	check(fields.wave_enemy_lists.hint_string.contains("Squirrel") and fields.wave_color_palettes.hint_string.contains("blue") and fields.core_resource_price_increase.hint_string.contains("pink"), "Per-wave enemies, colors and resource keys have dropdown hints")
	gate.free()
	print("RESOURCE REWORK CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
