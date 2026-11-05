extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	var numbers = preload("res://scripts/display_numbers.gd")
	for pair in [[0, "0"], [0.5, "0.5"], [12.5, "12.5"], [100, "100"], [999, "999"], [1000, "1k"], [1250, "1.25k"], [5000, "5k"], [999999, "1m"], [1000000, "1m"], [1250000, "1.25m"], [-1500, "-1.5k"]]:
		check(numbers.format(pair[0]) == pair[1], "Compact formatter handles %s" % pair[0])
	fresh()
	check(game.enemy_health("siege", 1) == 2000 and game.enemy_health("siege", 20) == 2000, "Siege health remains two thousand across waves")
	check(game.BUILDINGS.turret.damage == 50 and game.BUILDINGS.turret.reload == 4, "Slugger fires fifty damage every four seconds")
	check(game.BUILDINGS.solar.reload == 0.5, "Solar attack interval is half a second")
	game.inventory.scrap = 1234567
	game.base_copper_capacity = 1000000
	game.hud.refresh()
	game.hud._set_display_amount(1234567, "scrap")
	check(game.hud.resources.scrap.text == "1.23m" and game.inventory.scrap == 1234567, "Inventory abbreviates display without changing stored amount")
	check(game.hud.resource_views.copper.capacity.text == "/ 1m", "Inventory capacities use compact formatting")
	var card := Control.new()
	game.hud.root.add_child(card)
	var cost := {"copper": 123456, "scrap": 1500000}
	var labels: Dictionary = game.hud.cost_row(card, cost, Vector2.ZERO)
	check(labels.copper.text == "123.46k" and labels.scrap.text == "1.5m" and cost.copper == 123456, "Cost rows abbreviate prices without changing costs")
	var required: float = labels.copper.get_theme_font("font").get_string_size(labels.copper.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	check(labels.copper.size.x >= required and labels.scrap.position.x > labels.copper.get_rect().end.x, "Cost labels and following icons have room for the full compact price")
	var info = preload("res://scripts/structure_info.gd")
	var enemy: Dictionary = game.create_enemy("siege", Vector2.ZERO, "red")
	check(info.enemy_stats(game, enemy).contains("Health: 2k / 2k"), "Enemy tooltip health uses compact formatting")
	check(info.stats(game, "core").contains("Health: 2k"), "Building tooltip health uses compact formatting")
	check(info.stats(game, "turret").contains("DPS: 12.5") and info.stats(game, "turret").contains("Shot interval: 4s"), "Slugger tooltip reflects its new attack stats")
	check(info.stats(game, "solar").contains("DPS: 4") and info.stats(game, "solar").contains("Shot interval: 0.5s"), "Solar tooltip reflects its new attack interval")
	game.wave = 1499
	game.hud.refresh()
	check(game.hud.next_wave_label.text == "Next Wave: 1.5k", "Wave labels use compact formatting")
	print("COMPACT NUMBER AND COMBAT CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

