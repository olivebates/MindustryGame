extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.set_camera_zoom(2)
	game.camera.position = game.cell_center(game.current_core)
	game.camera.force_update_scroll()
	var enemy: Dictionary = game.create_enemy("bulwark", game.cell_center(game.current_core) - Vector2(50, 0), "red")
	enemy.aim = 0.0
	enemy.charge = 0.85
	game.enemies.assign([enemy])
	var siege: Dictionary = game.create_enemy("siege", game.cell_center(game.current_core) - Vector2(170, 0), "red")
	siege.aim = 0.0
	siege.charge = 0.85
	game.enemies.append(siege)
	var slugger: Vector2i = game.current_core + Vector2i(0, 3)
	game._add_building(slugger, "turret", 0)
	game.buildings[slugger].progress = 3.4
	game.buildings[slugger].aim = 0.0
	game.research("slugger_shield", true)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/bulwark_charge.png")
	print("BULWARK CHARGE CAPTURE FINISHED")
	game.free()
	quit()
