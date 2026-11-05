extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.rocks.clear()
	game.fog_disabled = true
	game.camera.position = game.cell_center(game.current_core + Vector2i(4, 2))
	game.camera.zoom = Vector2(1.5, 1.5)
	game._add_building(game.current_core + Vector2i(2, 0), "drill", 0)
	game._add_building(game.current_core + Vector2i(4, 0), "solar", 0)
	game._add_building(game.current_core + Vector2i(5, 0), "wall", 0)
	for i in 3:
		var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(game.current_core + Vector2i(i * 3, 5)), ["red", "green", "blue"][i])
		enemy.angle = 0.0
		enemy.aim = i * PI / 2
		game.enemies.append(enemy)
	game._reveal_map()
	game.queue_redraw()
	await shot("res://tests/enemy_cannon_aim.png")
	for wave in [1, 2, 3]:
		game.wave = wave
		game.active_spawners[0].waves_completed = wave
		game.saves.capture()
	game.hud.refresh()
	game.hud.save_browser.show_browser()
	await shot("res://tests/save_summary_icons.png")
	game.hud.close_modal()
	await process_frame
	var gate = game.active_spawners[0]
	game.hover_cell = Vector2i((gate.position / game.TILE).floor())
	var key := InputEventKey.new()
	key.keycode = KEY_ALT
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game.hud._refresh_tooltip(game.get_canvas_transform() * gate.position)
	await shot("res://tests/spawn_forecast.png")
	quit()

