extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.tutorial.skip_to_ready()
	var checkpoint: Array = game.saves.snapshot().duplicate(true)
	var tower := Vector2i(27,25)
	game._add_building(tower,"solar",0)
	game._damage_building(tower,1)
	check(not game.core_under_attack, "Damage to another building does not trigger the core breach warning")
	game._damage_building(game.current_core,0)
	check(not game.core_under_attack, "Zero damage to the core does not trigger the warning")
	game._damage_building(game.current_core,1)
	var warning := "Enemies have breached your defences.\nLoad a save form the timeline."
	check(game.core_under_attack and game.tutorial.central_message() == warning, "Actual core damage replaces tutorial text with the requested breach warning")
	game.hud.refresh()
	check(game.hud.tutorial_prompt.visible and game.hud.tutorial_prompt.text == warning, "Breach warning is displayed in the center tutorial label")
	game.tutorial_enabled = false
	game.hud.refresh()
	check(game.hud.tutorial_prompt.visible, "Breach warning remains visible when onboarding is disabled")
	check(game.saves.restore_snapshot(checkpoint,-1) and not game.core_under_attack and game.tutorial.central_message() != warning, "Loading an earlier save clears the transient breach warning")
	fresh()
	game.tutorial.skip_to_ready()
	for gate in game.active_spawners: gate.waves_before_conversion = 99
	game.wave = 1
	game.wave_in_progress = true
	var gate_index: int = game.spawners.find(game.active_spawners[0])
	game.pending_waves[1] = [gate_index]
	var enemy: Dictionary = game.create_enemy("scout",game.cell_center(Vector2i(20,25)),"red")
	enemy.wave_id = 1
	game.enemies.append(enemy)
	var wall := Vector2i(23,25)
	tower = Vector2i(24,24)
	game._add_building(wall,"wall",0)
	game._add_building(tower,"solar",0)
	game._add_building(Vector2i(22,24),"drill",0)
	check(game.has_pending_construction and game.buildings[wall].pending and game.buildings[tower].pending, "Buildings placed while old enemies remain begin as ghosts")
	game.paused = true
	game.launch_wave()
	check(game.buildings[wall].pending and game.wave == 1, "A rejected wave start does not complete pending construction")
	game.paused = false
	game.launch_wave()
	check(game.wave == 2 and game.enemies.has(enemy) and game.spawn_remaining > 0, "Next wave launches while earlier enemies remain alive")
	check(not game.has_pending_construction and game.buildings.values().all(func(building): return not building.pending), "Launching the next wave activates every ghost building")
	check(game.enemy_navigation.grid.is_point_solid(wall) and game.enemy_navigation.turret_cells.has(tower), "Activated barriers and turrets immediately update enemy navigation")
	game._damage_building(game.current_core,1)
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game._complete_wave(1)
	game._complete_wave(2)
	check(not game.core_under_attack, "Defeating the remaining waves clears the core breach warning")
	print("BREACH AND WAVE ACTIVATION CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
