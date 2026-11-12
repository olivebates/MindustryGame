extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.fog_disabled = true
	game.tutorial.skip_to_ready()
	game.camera.position = game.cell_center(Vector2i(25, 25))
	game.set_camera_zoom(2.0)
	game.camera_zoom_target = 2.0
	for i in 7:
		var kind: String = game.Content.ENEMY_TYPES.keys()[i]
		var enemy: Dictionary = game.create_enemy(kind, game.cell_center(Vector2i(16 + i * 3, 22)), ["red", "green", "blue"][i % 3])
		enemy.angle = 0.0
		enemy.aim = 0.0
		game.enemies.append(enemy)
	game._add_building(Vector2i(20, 26), "copper_store", 0)
	game._add_building(Vector2i(23, 26), "iron_store", 0)
	game._add_building(Vector2i(26, 26), "turret", 0)
	for b in game.buildings.values(): b.pending = false
	var tower: Dictionary = game.buildings[Vector2i(26, 26)]
	tower.booster_type = "pink"
	tower.booster_count = 4
	game.inventory.copper = 30
	game.inventory.iron = 30
	game.inventory.pink = 5
	game.hud._sync_tutorial_ui()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rebrand_animals.png")
	game.hud.show_structure_info("turret", tower, Vector2(1500, 1150))
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rebrand_boost.png")
	print("REBRAND CAPTURES FINISHED")
	game.free()
	quit()
