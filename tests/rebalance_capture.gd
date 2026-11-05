extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.hud.ghost_cost.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.fog_disabled = true
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.onboarding_completed = true
	game.tutorial.first_wave_completed = true
	game.tutorial.pause_exit_completed = true
	game.tutorial.waves_started = true
	game.inventory.copper = 80
	game.inventory.iron = 80
	game.inventory.scrap = 80
	game._reveal_map()
func shot(name: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	game.tutorial.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rebalance_%s.png" % name)
func run() -> void:
	fresh()
	for tech in ["barriers", "conveyor_speed", "turret_range", "copper_storage"]: game.research(tech, true)
	game.tutorial.tech_available = true
	game.hud.refresh()
	game.hud.toggle_category("Infrastructure")
	game.hud.show_tech_tree()
	game.hud.tech_scroll.zoom_at(0.72, game.hud.tech_scroll.size / 2)
	await shot("tech")
	game.hud.close_modal()
	await process_frame
	fresh()
	game.camera.position = game.cell_center(game.current_core + Vector2i(5, 4))
	game.camera.zoom = Vector2(1.8, 1.8)
	for index in 3:
		var enemy: Dictionary = game.create_enemy("bulwark", game.cell_center(game.current_core + Vector2i(2 + index * 3, 3)), ["red", "green", "blue"][index])
		enemy.angle = 0.0
		enemy.aim = index * PI / 2
		game.enemies.append(enemy)
	var origin: Vector2 = game.cell_center(game.current_core + Vector2i(5, 6))
	game.spawn_scrap(1281, origin)
	game.collect_scrap(0.3, origin + Vector2(1000, 0), false)
	game.camera.force_update_scroll()
	await shot("bulwarks_scrap")
	fresh()
	for tech in ["barriers", "conveyor_speed", "copper_storage", "weapons"]: game.research(tech, true)
	game.inventory.copper = 80
	game.inventory.iron = 80
	var drill := Vector2i(20, 22)
	game.ores[drill] = "copper"
	game._add_building(drill, "drill", 0)
	var tower: Vector2i = game.current_core + Vector2i(8, 3)
	game.place_building(tower, "turret", 0)
	game.camera.position = game.cell_center(game.current_core + Vector2i(3, 1))
	game.camera.force_update_scroll()
	await shot("ammo")
	game.tutorial.ammo_tutorial_stage = 3
	game.tutorial.ammo_guide_path.clear()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.zoom = Vector2(0.65, 0.65)
	game.camera.force_update_scroll()
	game.hover_cell = game.current_core
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.get_canvas_transform() * game.cell_center(game.current_core))
	await shot("core_range")
	quit()
