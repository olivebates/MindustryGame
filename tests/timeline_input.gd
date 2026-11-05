extends "res://tests/rebalance_capture.gd"
func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)
	Input.flush_buffered_events()
	await process_frame
func run() -> void:
	fresh()
	game.saves.directory = "res://.godot/timeline_native_input"
	game.saves.entries.clear()
	for i in 3:
		game.wave = i + 1
		game.saves.capture()
	game.hud.refresh()
	await process_frame
	var browser = game.hud.save_browser
	var area: Rect2 = browser.timeline.get_global_rect()
	var point := area.position + Vector2(area.size.x * 0.15, area.size.y / 2)
	await pointer(point, true)
	if not browser.dragging: push_error("FAIL: Native mouse press should start timeline scrubbing")
	var motion := InputEventMouseMotion.new()
	motion.position = area.position + Vector2(area.size.x * 0.52, area.size.y / 2)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	if browser.selected != 1: push_error("FAIL: Native dragging should preview middle save")
	await pointer(motion.position, false)
	if not is_instance_valid(game.hud.modal) or not game.hud.modal.visible: push_error("FAIL: Native release should open rewind confirmation")
	await shot("timeline_mouse_confirmation")
	game.hud.close_modal()
	await process_frame
	game.saves.entries.resize(1)
	game.saves.current = 0
	game.lost = true
	game.hud.refresh()
	await process_frame
	area = browser.timeline.get_global_rect()
	point = area.position + Vector2(area.size.x * 0.5, area.size.y / 2)
	await pointer(point, true)
	await pointer(point, false)
	if not is_instance_valid(game.hud.modal) or not game.hud.modal.visible: push_error("FAIL: A single checkpoint remains usable after death")
	print("NATIVE TIMELINE INPUT FINISHED")
	game.free()
	quit()

