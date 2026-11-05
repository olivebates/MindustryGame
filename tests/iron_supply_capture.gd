extends "res://tests/rebalance_capture.gd"
func click_event(point: Vector2, pressed: bool) -> void:
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
	game.get_node("Level/RockWalls").clear()
	game.camera.zoom = Vector2(1.8, 1.8)
	game.research("weapons", true)
	game.research("copper_storage", true)
	game.research("splitter", true)
	var core: Vector2i = game.current_core
	game._add_building(core + Vector2i(1, 3), "solar", 0)
	game._add_building(core + Vector2i(3, 3), "copper_store", 0)
	var ore: Vector2i = core + Vector2i(-4, 0)
	game.ores.clear()
	game.ores[ore] = "iron"
	game.get_node("Level/OreDeposits").clear()
	game.get_node("Level/OreDeposits").set_cell(ore, 1, Vector2i.ZERO)
	game.place_building(core + Vector2i(6, 0), "turret", 0)
	game.camera.position = game.cell_center(core + Vector2i(1, 1))
	game.camera.force_update_scroll()
	await shot("iron_supply_art")
	game._add_building(ore, "drill", 0)
	game.tutorial.refresh_ammo_guide()
	await shot("iron_extractor_built")
	game.spawn_remaining = 1
	await shot("smaller_in_progress")
	game.spawn_remaining = 0
	fresh()
	for tech in ["barriers", "turret_range", "copper_storage"]: game.research(tech, true)
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	game.hud.tech_scroll.zoom_at(0.55, game.hud.tech_scroll.size / 2)
	await shot("smooth_tech")
	var card: Button = game.hud.tech_buttons.splitter.button
	var point: Vector2 = card.get_global_rect().get_center()
	Input.warp_mouse(point)
	await process_frame
	await click_event(point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point - Vector2(25, 5)
	motion.global_position = motion.position
	motion.relative = Vector2(-25, -5)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	Input.flush_buffered_events()
	await process_frame
	await click_event(motion.position, false)
	if game.researched.has("splitter"): push_error("FAIL: Left-dragging a tech card purchased it")
	point = card.get_global_rect().get_center()
	Input.warp_mouse(point)
	await process_frame
	await click_event(point, true)
	await click_event(point, false)
	if not game.researched.has("splitter"): push_error("FAIL: Clicking a tech card no longer purchases it")
	print("NATIVE TECH DRAG: drag cancels purchase; click purchases normally")
	game.hud.close_modal()
	await process_frame
	fresh()
	var next: Vector2i = game.current_core + Vector2i(15, 0)
	game._add_building(next, "core", 0)
	game.cores.append(next)
	game.current_core = next
	game.camera.position = game.cell_center(next)
	game._reveal_map()
	game.camera.force_update_scroll()
	await shot("core_glow")
	quit()


