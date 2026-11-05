extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.set_camera_zoom(2.0)
	game.tutorial.skipped = true
	game.get_node("Level/RockWalls").clear()
	var center: Vector2 = game.cell_center(game.current_core)
	game.camera.position = center
	game.camera.force_update_scroll()
	game.enemies.clear()
	for pair in [["scout", Vector2(-130, 0)], ["bulwark", Vector2(-40, 0)], ["siege", Vector2(80, 0)]]:
		var enemy: Dictionary = game.create_enemy(pair[0], center + pair[1], "red")
		enemy.angle = 0
		enemy.aim = 0
		game.enemies.append(enemy)
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/siege_redesign.png")
	game.free()
	quit()
