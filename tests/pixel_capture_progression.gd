extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var gate = game.active_spawners[0]
	gate.waves_before_conversion = 2
	gate.waves_completed = 0
	var index: int = game.spawners.find(gate)
	game.wave = 2
	game.pending_waves = {1: [index], 2: [index]}
	game.wave_in_progress = true
	var old_core: Vector2i = game.current_core
	var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(old_core + Vector2i(10, 0)), "red")
	enemy.wave_id = 1
	enemy.cooldown = 100.0
	game.enemies.append(enemy)
	game._complete_wave(2)
	check(not gate.converted and game.current_core == old_core and not game.paused, "Finishing the newest wave waits for surviving enemies from earlier waves")
	game.hud.refresh()
	check(game.last_round_active() and game.hud.wave_label.text == "Last Round", "The timer displays Last Round while the sector's final enemies remain")
	var timer: float = game.wave_timer
	game.simulate(0.05)
	check(game.wave_timer == timer and not gate.converted, "Last Round stops the next-wave countdown without creating a core")
	game.request_next_wave()
	game.launch_wave()
	check(game.wave == 2 and not game.wave_warp_active, "The final round cannot queue additional waves")
	game.enemies.clear()
	game.simulate(0.01)
	var next_core: Vector2i = Vector2i((gate.position / game.TILE).floor())
	check(gate.converted and game.current_core == next_core and game.buildings.has(next_core), "The core appears once every enemy has been defeated")
	check(game.paused and not game.last_round_active(), "Creating a core automatically pauses time and clears Last Round")
	game.hud.refresh()
	check(game.hud.wave_label.text != "Last Round", "The new sector restores the normal timer display")
	fresh()
	game.research("weapons", true)
	var ore := Vector2i(20, 25)
	var tower := Vector2i(30, 25)
	game.ores[ore] = "iron"
	game.place_building(tower, "turret", 0)
	var guide = game.tutorial
	guide.guide_grid_signature = -1
	guide.ammo_guide_signature = -1
	var builds: int = guide.guide_grid_builds
	var queries: int = guide.ammo_path_queries
	var start := Time.get_ticks_usec()
	guide.refresh_ammo_guide()
	var cold := Time.get_ticks_usec() - start
	check(guide.guide_grid_builds == builds + 1 and guide.ammo_path_queries == queries + 1 and not guide.ammo_guide_path.is_empty(), "Cold ammo guide builds one grid and runs one path search")
	start = Time.get_ticks_usec()
	for tick in 100: guide.refresh_ammo_guide()
	var warm := (Time.get_ticks_usec() - start) / 100.0
	check(guide.guide_grid_builds == builds + 1 and guide.ammo_path_queries == queries + 1, "Unchanged ammo guides reuse both the grid and path")
	var blocked: Vector2i = guide.ammo_guide_path[2]
	game._add_building(blocked, "wall", 0)
	guide.refresh_ammo_guide()
	check(guide.guide_grid_builds == builds + 2 and not guide.ammo_guide_path.has(blocked), "A new obstruction invalidates the cache and updates the guide")
	var texture_material: ShaderMaterial = game.material
	check(texture_material.shader.resource_path == "res://scripts/crisp_sprite.gdshader" and game.get_node("Level/Ground").material == texture_material and guide.material == texture_material, "World tiles, sprites and ghosts use the pixel shader")
	check(game.hud.root.theme.default_font.resource_path == "res://PixelifySans.ttf" and load("res://PixelifySans.ttf").multichannel_signed_distance_field, "All GUI uses Pixelify Sans with full-resolution distance-field text")
	check(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d") == 0 and ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "Rendering uses nearest sampling and disables multisample antialiasing")
	game.research("barriers", true)
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	var borders := true
	for data in game.hud.tech_buttons.values():
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box: StyleBoxFlat = data.button.get_theme_stylebox(state)
			borders = borders and box.border_width_left == 3 and box.border_width_bottom == 3
	check(borders, "All tech-card interaction states retain three-pixel borders")
	print("AMMO GUIDE TIMING: cold %.2f ms; unchanged %.3f ms" % [cold / 1000.0, warm / 1000.0])
	print("PIXEL CAPTURE PROGRESSION CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

