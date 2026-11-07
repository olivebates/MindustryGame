extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	var position: Vector2 = game.cell_center(game.current_core) - Vector2(100, 0)
	for i in 3:
		var enemy: Dictionary = game.create_enemy("scout", position, "red")
		enemy.hp = 1 + i
		game.enemies.append(enemy)
	game.update_enemy_visual_offsets(2)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/stacked_enemy_visuals.png")
	print("STACKED ENEMY NATIVE CAPTURE FINISHED")
	game.free()
	quit()
