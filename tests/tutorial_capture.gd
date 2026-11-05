extends SceneTree
var game
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	game.hud.refresh()
	game.tutorial.queue_redraw()
	game.queue_redraw()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/tutorial_%s.png" % name)
func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio.muted = true
	game.set_process(false)
	game.tutorial.set_process(false)
	await shot("initial")
	game.add_resource("copper", 10)
	game.hud.toggle_category("Structures")
	game.hud.cards.drill.pressed.emit()
	await shot("extractor")
	game.place_building(Vector2i(20, 22), "drill", 0)
	game.add_resource("copper", 30)
	game.hud.toggle_category("Structures")
	game.hud.cards.belt.pressed.emit()
	game.tutorial.refresh_guide()
	await shot("belts")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	game.hud.toggle_category("Structures")
	game.hud.cards.solar.pressed.emit()
	await shot("solar")
	game.place_building(Vector2i(31, 22), "solar", 0, "red")
	await shot("ready")
	game.launch_wave()
	await shot("first_wave")
	game.tutorial.on_wave_completed(4)
	game.hud.refresh()
	game.hud.show_tech_tree()
	await shot("barriers")
	game.research("barriers")
	game.hud._rebuild_tech_nodes()
	await shot("frontier")
	print("TUTORIAL CAPTURES COMPLETE")
	quit()

