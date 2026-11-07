extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	var gate = game.active_spawners[0]
	gate.position = game.cell_center(game.current_core) - Vector2(140, 0)
	gate.active = true
	gate.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/spawn_face.png")
	print("HORNED SPAWN FACE CAPTURE FINISHED")
	game.free()
	quit()
