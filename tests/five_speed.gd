extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	check(game.initial_wave_delay == 120 and game.inter_wave_delay == 120 and game.wave_timer == 120, "Initial and regular wave intervals are two minutes")
	game.cycle_speed()
	check(game.speed == 1, "Speedup requires research")
	game.research("barriers", true)
	game.research("time_speed", true)
	game.cycle_speed()
	check(game.speed == 5, "E speedup switches to five times speed")
	game.hud.refresh()
	check(game.hud.speed_button.get_meta("info")[1].contains("x5"), "Alt tooltip describes five times speed")
	check(game.hud.tech_stat_summary("time_speed") == "Press E for x5 speed" and game.TECH.time_speed.description.contains("five times"), "Research text describes five times speed")
	game.cycle_speed()
	check(game.speed == 1, "Speedup switches back to normal")
	game.speed = 5
	var snapshot: Array = game.saves.snapshot()
	game.speed = 1
	game.saves.restore_snapshot(snapshot, -1)
	check(game.speed == 5, "Five times speed survives checkpoint restore")
	snapshot[1][game.saves.FIELDS.find("speed")] = 3
	game.saves.restore_snapshot(snapshot, -1)
	check(game.speed == 5, "Legacy fast checkpoints use the current five times speed")
	print("FIVE SPEED CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
