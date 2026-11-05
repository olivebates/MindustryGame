extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.hud.show_info("Enemy spawn — Wave 5", "", Vector2(750, 400))
	var preview = preload("res://scripts/spawn_preview.gd").new()
	preview.hud = game.hud
	game.hud.info_root.add_child(preview)
	preview.show_forecast({"scout": 3, "heavy": 2, "runner": 4}, Vector2(750, 400), 5)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/spawn_preview.png")
	preview.show_forecast({"scout": 3, "heavy": 2, "runner": 4, "skirmisher": 2, "bulwark": 1, "siege": 1, "mender": 1}, Vector2(1700, 800), 5)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/spawn_preview_all.png")
	game.free()
	quit()
