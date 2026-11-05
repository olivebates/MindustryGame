extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.tutorial.skip_to_ready()
	game.hud.refresh()
	game.research("build_hotkeys", true)
	key(game, KEY_1)
	check(game.hud.expanded.visible and game.hud.category == "Structures", "First number opens its category")
	game.research("build_hotkeys", true)
	key(game, KEY_2)
	check(game.selected == game.hud.cards.keys()[1], "Open tray gives number shortcuts to its buildings")
	game.select_tool("abolish")
	check(game.selected == "" and game.hud.category == "" and not game.hud.expanded.visible, "Demolition deselects construction and closes the tray")
	game.cancel_build_selection()
	game.tutorial.tech_available = true
	game.hud.refresh()
	key(game, KEY_T)
	check(game.paused and is_instance_valid(game.hud.modal), "T opens a paused tech tree")
	game.toggle_pause()
	check(game.paused, "Pause cannot be toggled off under a modal")
	game.hud.close_modal()
	check(not game.paused, "Closing research restores the prior running state")
	await process_frame
	game.research("barriers", true)
	game.research("conveyor_speed", true)
	check(game.TECH.copper_storage.parent == "conveyor_speed" and game.TECH.copper_storage.cost == {"scrap": 15, "copper": 35}, "Copper storage research follows belt speed and costs fifteen scrap plus thirty-five copper")
	check(not game.unlocked("copper_store"), "Silo remains locked until its own research")
	game.research("copper_storage", true)
	check(game.unlocked("copper_store") and game.building_cost("copper_store") == {"scrap": 10}, "Copper silo starts at ten scrap")
	game.inventory.scrap = 30
	game.rocks.clear()
	var cell: Vector2i = game.current_core + Vector2i(0, 3)
	var capacity: int = game.material_capacity("copper")
	check(game.place_building(cell, "copper_store", 0) and game.material_capacity("copper") == capacity + 50, "New silo increases copper capacity")
	check(game.within_build_radius(game.current_core + Vector2i(20, 0)) and not game.within_build_radius(game.current_core + Vector2i(20, 1)), "Build radius is a twenty-tile circle")
	check(game.enemy_navigation.grid.is_point_solid(cell), "Building immediately updates pathfinding solidity")
	game.remove_building(cell, false)
	check(not game.enemy_navigation.grid.is_point_solid(cell), "Removing a building immediately clears its pathfinding cell")
	game._add_building(game.current_core + Vector2i(4, 0), "solar", 0)
	var covered: Vector2i = game.current_core + Vector2i(4, 2)
	check(game.enemy_navigation.grid.get_point_weight_scale(covered) > 1 and game.enemy_navigation.grid.get_point_weight_scale(game.current_core + Vector2i(0, 8)) == 1, "Pathfinding weights penalize turret coverage")
	game.remove_building(game.current_core + Vector2i(4, 0), false)
	check(game.enemy_navigation.grid.get_point_weight_scale(covered) == 1, "Destroyed turret removes its danger cost immediately")
	key(game, KEY_Q)
	game.advance_wave_warp(2.0)
	check(game.wave == 1 and game.spawn_remaining > 0, "S starts the next wave")
	var timer: float = game.wave_timer
	game.spawn_timer = 1.0
	game.simulate(0.1)
	check(game.wave_timer == timer, "Timer waits while the spawn queue is still active")
	game.spawn_queue.resize(1)
	game.spawn_remaining = 1
	game.spawn_timer = 0.0
	game.simulate(0.1)
	game.simulate(0.1)
	check(game.spawn_remaining == 0 and game.wave_timer < timer and not game.enemies.is_empty(), "Countdown begins after the last spawn while enemies remain")
	var remaining: float = game.wave_timer
	game.enemies.clear()
	game._complete_wave()
	check(game.wave_timer == remaining, "Defeating the wave retains the existing countdown")
	game.hud.refresh()
	check(game.hud.next_wave_label.text == "Next Wave: 2" and game.hud.next_button.get_node("Hotkey").text == "Q" and game.hud.tech_button.get_node("Hotkey").text == "T", "Wave label and persistent hotkey hints reflect current controls")
	var map = game.hud.minimap
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.size / 2
	map._gui_input(click)
	var first: Vector2 = game.camera.position
	var motion := InputEventMouseMotion.new()
	motion.position = click.position + Vector2(10, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	map._gui_input(motion)
	check(game.camera.position.x > first.x, "Dragging the minimap continuously moves the camera")
	print("CONTROLS PATHS STORAGE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)



