extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	check(game.BUILDINGS.turret.damage == 50 and game.BUILDINGS.turret.reload == 4.0, "Slugger deals fifty damage every four seconds")
	check(game.TECH.weapons.cost == {"iron": 5, "scrap": 70}, "Slugger research costs iron and scrap")
	check(game.material_capacity("iron") == 40, "Starting iron capacity is forty")
	check(not game.hud.build_hotkeys_available(), "Build hotkeys are unavailable before category split")
	game.researched.barriers = true
	game.hud.refresh()
	check(game.hud.build_hotkeys_available() and not game.researched.has("build_hotkeys"), "Category split enables hotkeys without research")
	check(not game.hud.visible_tech_ids().has("build_hotkeys"), "Hotkey research is absent from tech tree")
	game.researched.weapons = true
	var target := Vector2i(29, 25)
	game.tutorial.ammo_tutorial_stage = 0
	game.tutorial.ammo_tutorial_target = game.INVALID
	check(game.place_building(target, "turret", 0), "First Slugger can be placed")
	var drill := Vector2i(27, 25)
	game.ores[drill] = "iron"
	game._add_building(drill, "drill", 0)
	game.tutorial.refresh_ammo_guide()
	game.tutorial.on_ammo_inspected()
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_tutorial_stage == 2 and not game.tutorial.ammo_guide_path.is_empty() and game.tutorial.central_message().contains("Some turrets require ammo"), "Inspecting ammo leaves lesson and conveyor ghosts active")
	var adjacent := Vector2i(29, 24)
	game.ores[adjacent] = "iron"
	game._add_building(adjacent, "drill", 0)
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_tutorial_stage == 2 and not game.tutorial.ammo_guide_path.is_empty() and game.anchor_at(game.tutorial.ammo_guide_path[0]) != target, "Direct adjacency keeps the lesson active and shows a belt detour")
	game.remove_building(adjacent, false)
	game._add_building(Vector2i(28, 25), "belt", 0)
	game.tutorial.refresh_ammo_guide()
	check(game.tutorial.ammo_tutorial_stage == 3 and game.tutorial.ammo_guide_path.is_empty(), "Conveyor connection completes Slugger lesson")
	var enemy: Dictionary = game.create_enemy("scout", game.building_center(target) + Vector2(40, 0), "red")
	enemy.hp = 500
	game.enemies.append(enemy)
	var particles: int = game.particles.size()
	game._update_turret(target, game.buildings[target], 0.05)
	check(game.particles.size() >= particles + 10 and game.shots[-1].damage == 50, "Slugger fires damaging iron projectile and muzzle sparks")
	var gate = game.active_spawners[0]
	game.hover_cell = Vector2i((gate.position / game.TILE).floor())
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	var pointer: Vector2 = game.get_canvas_transform() * gate.position
	game.hud._refresh_tooltip(pointer)
	check(game.hud.tooltip.visible and not game.hud.tooltip_body.visible and game.hud.spawn_preview.visible, "Spawn hover displays icon summary and separate cards")
	check(game.hud.spawn_preview.get_child_count() > 0 and game.hud.spawn_preview.get_child(0).has_meta("enemy_kind"), "Each forecast enemy has its own stats card")
	check(not game.hud.tooltip_body.text.contains("Credits:"), "Spawn summary omits old text statistics")
	alt.pressed = false
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(pointer)
	check(not game.hud.spawn_preview.visible and not game.hud.spawn_preview.summary.visible, "Releasing Alt hides all forecast boxes")
	fresh()
	game.wave = 8
	game.active_spawners[0].waves_before_conversion = 1
	game.active_spawners[0].waves_completed = 0
	game.wave_in_progress = true
	game._complete_wave()
	check(game.cores.size() == 2 and game.wave + 1 == 1 and game.paused, "New core resets the next wave to one and pauses")
	check(game.saves.entries[-1].wave == 1, "Core capture checkpoint is labeled wave one")
	print("SPAWN AND SLUGGER CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)



