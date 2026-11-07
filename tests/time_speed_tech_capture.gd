extends "res://tests/rebalance_capture.gd"
func run() -> void:
	fresh()
	game.researched.barriers = true
	game.researched.turret_range = true
	game.tutorial.tech_available = true
	game.hud.refresh()
	game.hud.show_tech_tree()
	game.hud.tech_scroll.zoom_at(1.5, game.hud.tech_scroll.size / 2)
	await shot("time_speed_tech")
	if game.hud.tech_scroll.get_h_scroll_bar().visible or game.hud.tech_scroll.get_v_scroll_bar().visible: push_error("FAIL: Tech scrollbars should be hidden")
	var tree = game.hud.tech_scroll
	var start: Vector2 = tree.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	await process_frame
	var before := Vector2(tree.scroll_horizontal, tree.scroll_vertical)
	var motion := InputEventMouseMotion.new()
	motion.position = start - Vector2(110, 100)
	motion.relative = Vector2(-110, -100)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)
	await process_frame
	if Vector2(tree.scroll_horizontal, tree.scroll_vertical) == before: push_error("FAIL: Tech drag should pan while scrollbars are hidden")
	press.pressed = false
	press.position = motion.position
	root.push_input(press, true)
	await process_frame
	print("NATIVE HIDDEN SCROLLBAR DRAG CHECK FINISHED")
	game.hud.close_modal()
	game.free()
	quit()

