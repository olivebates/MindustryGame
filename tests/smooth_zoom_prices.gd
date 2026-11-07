extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.tutorial.skipped = true
	game.tutorial.extractor_connected_once = true
	var base: Dictionary = game.building_cost("solar", 0)
	var next: Dictionary = game.building_cost("solar", 1)
	var third: Dictionary = game.building_cost("solar", 2)
	check(base.copper == 10 and next.copper == 11 and third.copper == 12, "Turret prices compound by ten percent with existing rounding")
	game.set_camera_zoom(2)
	game.step_camera_zoom(-1)
	check(game.camera.zoom.x == 2 and game.camera_zoom_target == 1, "Scroll begins a transition to 100 percent")
	await create_timer(0.1).timeout
	check(game.camera.zoom.x > 1 and game.camera.zoom.x < 2, "Zoom has intermediate values during its 0.2-second lerp")
	await create_timer(0.15).timeout
	check(game.camera.zoom == Vector2.ONE, "Zoom completes at the chosen discrete level")
	game.step_camera_zoom(-1)
	game.step_camera_zoom(1)
	check(game.camera_zoom_target == 1, "Rapid scroll uses the destination level rather than intermediate zoom")
	await create_timer(0.25).timeout
	check(game.camera.zoom == Vector2.ONE, "Rapid scroll settles at the requested zoom")
	game.step_camera_zoom(1)
	game.set_camera_zoom(0.5)
	await create_timer(0.25).timeout
	check(game.camera.zoom == Vector2.ONE * 0.5, "Immediate restore cancels a pending zoom tween")
	print("SMOOTH ZOOM AND PRICE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
