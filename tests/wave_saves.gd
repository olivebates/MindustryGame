extends SceneTree
class WebGame extends "res://scripts/game.gd":
	func platform_debug_features() -> PackedStringArray: return PackedStringArray(["web", "wasm32"])
var game
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)
func key(code: int, shift: bool = false, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	return event
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.audio.muted = true
	game.add_resource("copper", 4)
	check(game.tutorial.stage == game.tutorial.Stage.FUNDS and not game.hud.palette.visible, "Four copper keeps construction hidden")
	game.add_resource("iron", 50)
	check(game.tutorial.stage == game.tutorial.Stage.FUNDS, "Iron alone does not bypass the five-copper tutorial threshold")
	game.add_resource("copper", 1)
	check(game.tutorial.stage == game.tutorial.Stage.EXTRACTOR, "Five copper reveals extractor construction")
	game.hud.toggle_category("Structures")
	game.hud.apply_button_glow(game.hud.cards.drill)
	var background: StyleBoxFlat = game.hud.cards.drill.get_theme_stylebox("normal")
	check(background.bg_color.a == 1 and background.bg_color.r >= 0.2, "Tutorial buttons glow across their background")
	game.hud.cards.drill.pressed.emit()
	check(game.place_building(Vector2i(20, 22), "drill", 3) and game.buildings[Vector2i(20, 22)].dir == 0, "Extractor ignores placement rotation")
	check(game.building_cost("belt").copper == 1, "Base belt cost is one copper")
	game.add_resource("copper", 100)
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	check(game.tutorial.stage == game.tutorial.Stage.SOLAR, "An adjacent conveyor route unlocks solar")
	check(game.unlocked_colors("solar") == ["red"], "Solar initially has only red affinity")
	game.select_building("solar")
	game.begin_drag(Vector2i(31, 22))
	check(game.buildings.has(Vector2i(31, 22)) and game.buildings[Vector2i(31, 22)].color == "red" and not is_instance_valid(game.hud.radial), "One-color turret places directly without a radial menu")
	game.hud.refresh()
	check(game.hud.next_button.get_meta("tutorial_glow") and game.hud.next_button.text in ["Start", "Skip"], "First start/skip action glows after the turret is placed")
	game.select_tool("abolish")
	game.cancel_build_selection()
	game.launch_wave()
	game.hud.refresh()
	check(not game.hud.next_button.get_meta("tutorial_glow") and game.hud.next_button.text == "In Progress...", "First wave start stops the Start glow")
	check(game.hud.tool_buttons.is_empty(), "Toolbar contains clear and demolish without a blueprint button")
	for code in [KEY_Z, KEY_X, KEY_C]:
		game.active_tool = "build"
		game._unhandled_input(key(code))
		var expected: String = {KEY_Z: "build", KEY_X: "abolish", KEY_C: "blueprint_select"}[code]
		check(game.active_tool == expected, "Shortcut selects " + expected)
	for target in [game.hud.speed_button, game.hud.pause_button]:
		check(target.text == "" and target.has_meta("info") and target.get_meta("info")[2] != "", "Icon-only toolbar action includes shortcut help")
		Input.parse_input_event(key(KEY_ALT))
		Input.flush_buffered_events()
		game.hud._refresh_tooltip(target.get_global_rect().get_center())
		check((game.hud.tooltip.visible and game.hud.tooltip_title.text.contains(target.get_meta("info")[2]) and game.hud.tooltip_body.text == target.get_meta("info")[1]) if target.is_visible_in_tree() else not game.hud.tooltip.visible, "Visible actions show Alt hover help while hidden pause stays hidden")
	Input.parse_input_event(key(KEY_ALT, false, false))
	Input.flush_buffered_events()
	game.wave = 2
	game.simulate(1.9)
	game.hud.refresh()
	check(game.hud.tool_hint.text == "", "No pause reminder appears before damage")
	# Core damage now has its own higher-priority breach warning.
	game._damage_building(Vector2i(31, 22), 1)
	game.tutorial.on_wave_completed(1)
	game.hud.refresh()
	check(game.tutorial.central_message() == "Press space to pause and build.", "Pause reminder appears after the first building damage")
	game.toggle_pause()
	check(game.tutorial.central_message() == "" and game.tutorial.paused_once, "First real pause dismisses the reminder")
	game.toggle_pause()
	game.research("barriers", true)
	game.research("turret_color", true)
	check(game.unlocked_colors("solar").size() == 3 and game.unlocked_colors("turret").size() == 3, "Turret Color unlocks every color for every turret")
	game.hud.build_filters.select_color("green")
	game.select_building("solar")
	game.begin_drag(Vector2i(32, 22))
	check(game.radial_pending == game.INVALID and game.building_at(Vector2i(32, 22)).get("color", "") == "green", "Turrets place directly using the selected toolbar color")
	game.cancel_build_selection()
	game.finish_drag()
	game._add_building(Vector2i(25, 20), "copper_store", 0)
	game.handle_debug_shortcut(key(KEY_Z, true))
	game.handle_debug_shortcut(key(KEY_L, true))
	var full := true
	for resource in game.inventory: full = full and game.inventory[resource] == 10000 and (resource == "scrap" or game.material_capacity(resource) == 10000)
	check(full, "Shift+Z+L fills every resource and gives capped materials ten thousand capacity")
	# Exercise fair extractor routing on all four outputs and under back pressure.
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.activate_pending_buildings()
	var center := Vector2i(15, 20)
	game.ores[center] = "copper"
	game._add_building(center, "drill", 0)
	var drill: Dictionary = game.buildings[center]
	for direction in 4: game._add_building(center + game.DIRS[direction], "belt", direction)
	var sent := [0, 0, 0, 0]
	for i in 12:
		drill.item = "copper"
		drill.travel = 0
		game._update_items(game.FLOW_INTERVAL * 4 + 0.01)
		for direction in 4:
			var belt: Dictionary = game.buildings[center + game.DIRS[direction]]
			if belt.item != "":
				sent[direction] += 1
				belt.item = ""
	check(sent == [3, 3, 3, 3], "Extractor distributes evenly to four adjacent outgoing belts")
	var blocked: Dictionary = game.buildings[center + game.DIRS[drill.next_output]]
	blocked.item = "iron"
	drill.item = "copper"
	game._update_items(0.1)
	check(drill.item == "copper" and game.output_target(center, drill) != center + game.DIRS[drill.next_output], "Extractor waits for its turn under output back pressure")
	# Isolate serialization from checkpoints created by earlier UI/tutorial checks.
	game.saves.directory += "_serialization"
	# Exercise explicit snapshot serialization independently of auto-save scheduling.
	game.saves.entries.clear()
	game.saves.current = -1
	game.saves.pending_branch = false
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.wave_in_progress = true
	game.wave = 1
	game.scraps.append({"pos": Vector2(100, 200), "amount": 12, "magnetized": true})
	game._complete_wave()
	print("SAVE STATUS: ", game.saves.directory, " ", game.saves.last_error)
	check(game.saves.entries.size() == 1 and FileAccess.file_exists(game.saves.directory.path_join(game.saves.entries[0].file)), "Wave completion writes a persistent checkpoint")
	var original: Array = game.saves.snapshot().duplicate(true)
	var raw_size := var_to_bytes(original).size()
	var save_size := FileAccess.get_file_as_bytes(game.saves.directory.path_join(game.saves.entries[0].file)).size()
	print("SAVE SIZE: ", save_size, " / ", raw_size, " bytes")
	check(save_size < raw_size / 3, "Binary checkpoint compresses to less than one third of raw state")
	Input.parse_input_event(key(KEY_ALT, false, false))
	Input.flush_buffered_events()
	game.wave = 2
	game.inventory.copper = 123
	game._complete_wave()
	game.wave = 3
	game.inventory.copper = 456
	game._complete_wave()
	check(game.saves.entries.size() == 3, "Each completed wave adds one checkpoint")
	var history = load("res://scripts/wave_saves.gd").new(game)
	history.directory = game.saves.directory
	history.read_index()
	check(history.entries.size() == 3 and history.load_snapshot(0) == original, "Checkpoint history and exact state survive reopening disk files")
	check(game.saves.restore(0) and game.paused and game.wave == 1, "Restoring an older checkpoint pauses immediately")
	check(game.saves.snapshot()[1] == original[1] and game.saves.snapshot()[2] == original[2] and game.saves.snapshot()[4] == original[4] and game.saves.snapshot()[8] == original[8], "Restore reproduces durable state and deterministically rebuilds derived runtime state")
	game.tutorial.info_hover_time = 2.0
	game.tutorial.inspected_things = {"core": true, "belt": true, "enemy": true}
	game.tutorial.pause_exit_completed = true
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.tutorial.speed_toggled = true
	check(game.saves.restore(0) and game.tutorial.info_hover_time == 0.0 and game.tutorial.pause_exit_completed and not game.tutorial.speed_toggled and game.tutorial.inspected_things.is_empty(), "Rollback derives tutorial progress instead of retaining unrelated lesson history")
	check(game.saves.entries.size() == 3 and game.saves.pending_branch, "Restoring retains future saves while paused")
	game.hud.save_browser.show_browser()
	check(not game.hud.save_browser.strip.visible and game.hud.saves_button.visible and is_instance_valid(game.hud.modal), "Save browser replaces the persistent timeline")
	check(game.hud.save_browser.timeline.max_value == 2, "Timeline has all three checkpoints")
	game.hud.save_browser.begin_scrub()
	game.hud.save_browser.preview_save(0)
	check(game.hud.save_browser.selected == 0, "Timeline selects oldest checkpoint")
	game.hud.save_browser.preview_save(2)
	check(game.hud.save_browser.selected == 2, "Timeline selects newest checkpoint")
	game.hud.save_browser.finish_scrub()
	game.hud.close_modal()
	await process_frame
	check(game.paused and game.saves.entries.size() == 3, "Cancelling the browser keeps restore paused and preserves future history")
	game.hud.save_browser.confirm_restore(1)
	check(is_instance_valid(game.hud.modal) and game.paused, "Going back opens a confirmation dialog")
	for node in game.hud.modal.get_child(0).get_children():
		if node is Button and node.text == "Confirm": node.pressed.emit()
	await process_frame
	check(game.wave == 2 and game.paused and game.saves.current == 1 and game.saves.entries.size() == 3, "Confirming a restore loads that checkpoint and keeps later saves")
	game.saves.restore(0)
	game.toggle_pause()
	check(not game.paused and game.saves.entries.size() == 1 and not game.saves.pending_branch, "Resuming commits the branch and deletes later saves")
	history.read_index()
	check(history.entries.size() == 1, "Discarded future checkpoints are deleted from disk")
	Input.parse_input_event(key(KEY_ALT, false, false))
	Input.flush_buffered_events()
	game.wave = 2
	game._complete_wave()
	check(game.saves.entries.size() == 2 and game.saves.entries[1].wave == 2, "New waves append to the restored branch")
	var corrupt_path: String = game.saves.directory.path_join(game.saves.entries[1].file)
	var file := FileAccess.open(corrupt_path, FileAccess.READ_WRITE)
	file.seek(10)
	file.store_8(255)
	file.close()
	var before: int = game.wave
	check(not game.saves.restore(1) and game.wave == before, "Checksum rejects a damaged save without changing the game")
	# Remove only this test's own checkpoint files.
	for entry in game.saves.entries: DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	game.free()
	game = load("res://scenes/main.tscn").instantiate()
	game.set_script(WebGame)
	root.add_child(game)
	game.set_process(false)
	game.handle_debug_shortcut(key(KEY_Z, true))
	game.handle_debug_shortcut(key(KEY_L, true))
	check(game.inventory.copper == 0 and game.base_material_capacity == 500, "Resource debug chord is disabled on web builds")
	game.free()
	print("WAVE SAVE AND UX CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)













