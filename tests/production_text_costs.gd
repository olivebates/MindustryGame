extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	check(game.BUILDINGS.healer.cost == {"pink":8,"iron":15} and game.TECH.healer.name == "Heal Beacon", "Heal Beacon has its new name and construction cost")
	check(game.TECH.copper_storage.cost == {"copper":80} and game.TECH.iron_storage.cost == {"iron":20}, "Silo research uses only its corresponding resource")
	check(game.hud.tech_stat_summary("refining") == "Turns Chicken Nuggets and Fish Scales into Pink Stuff.", "Distillery text omits cycle time")
	check(game.hud.tech_stat_summary("copper_storage") == "+50 chicken nuggets capacity per silo when powered" and game.hud.tech_stat_summary("iron_storage") == "+40 fish scales capacity per silo when powered", "Silo descriptions include capacity and power requirement")
	var info = load("res://scripts/structure_info.gd")
	check(info.stats(game,"drill").contains("1 every 5s") and info.stats(game,"belt").contains("1 item every 2s"), "Fractional rates are displayed as seconds per item")
	check(game.manual_mining_interval("iron") == 5 and game.manual_mining_interval("copper") == 1, "Scales mine every five seconds and nuggets every second")
	var cell := Vector2i(24,25)
	game.ores[cell] = "iron"
	game.inventory.iron = 0
	game.selected = ""
	game.active_tool = "build"
	game.paused = false
	game.update_manual_mining(4.9,cell,true)
	check(game.inventory.iron == 0, "Manual scale extraction waits five seconds")
	game.update_manual_mining(0.1,cell,true)
	check(game.inventory.iron == 1, "Manual scale extraction yields one scale after five seconds")
	print("PRODUCTION TEXT CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
