extends SceneTree
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
func alt(held: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ALT
	key.pressed = held
	Input.parse_input_event(key)
	Input.flush_buffered_events()
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	check(game.hud.tutorial_prompt.text == "Press and hold on an ore deposit.", "Mining prompt uses the new wording")
	check(game.material_capacity("copper") == 40 and game.material_capacity("iron") == 500, "Copper starts capped at forty without reducing other minerals")
	game.add_resource("copper", 4)
	check(not game.hud.palette.visible, "Four copper does not reveal Structures")
	game.add_resource("copper", 1)
	check(game.hud.palette.visible and game.tutorial.stage == game.tutorial.Stage.EXTRACTOR, "Five copper reveals Structures and the extractor")
	check(game.building_cost("drill") == {"copper": 5}, "First extractor costs the normal five copper")
	game.hud.toggle_category("Structures")
	var point: Vector2 = game.hud.cards.drill.get_global_rect().get_center()
	game.hud._refresh_tooltip(point)
	check(not game.hud.tooltip.visible, "Build-menu info stays hidden without Alt")
	alt(true)
	game.hud._refresh_tooltip(point)
	check(game.hud.tooltip.visible and game.hud.tooltip_body.text.contains("Extracts ore") and game.hud.tooltip_body.text.contains("Extraction:") and game.hud.tooltip_body.text.contains("Health:"), "Alt on a menu building shows one-sentence description and useful stats")
	check(game.hud.tooltip_title.position == Vector2(8, 8) and game.hud.tooltip_body.position.x == 8 and game.hud.tooltip.size.y - game.hud.tooltip_body.get_rect().end.y == 8, "Mouse popups retain eight-pixel padding")
	check(game.hud.tooltip_layer.layer > game.hud.layer and game.hud.tooltip.get_parent().get_parent() == game.hud.tooltip_layer, "Info popups render in their own layer above the HUD and modals")
	alt(false)
	game.hud._refresh_tooltip(point)
	check(not game.hud.tooltip.visible, "Releasing Alt immediately hides the popup")
	game.select_building("drill")
	check(game.place_building(Vector2i(20, 22), "drill", 0) and game.inventory.copper == 0, "First extractor deducts all five starting copper")
	game.placement_counts.belt = 150
	check(game.building_cost("belt") == {"copper": 1}, "Tutorial belts ignore inflation before the first core connection")
	game.add_resource("copper", 2)
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	check(game.tutorial.extractor_connected_once and game.tutorial.stage == game.tutorial.Stage.SOLAR, "First extractor connection permanently records the discount milestone")
	check(game.building_cost("belt", 100).copper > 1, "Normal belt inflation resumes after the first connection")
	check(game.building_cost("drill").copper > 2, "Later extractors do not receive the first-build discount")
	game.hud.refresh()
	game.select_building("solar")
	game.hud.refresh()
	check(game.hud.tutorial_prompt.visible and game.hud.tutorial_prompt.text == "Wait for enough copper extraction.", "Opened Structures tutorial explains waiting for copper")
	game.add_resource("copper", 10)
	game.hud.refresh()
	check(not game.hud.tutorial_prompt.visible, "Waiting prompt clears once the next tutorial structure is affordable")
	game.remove_building(Vector2i(21, 22), false)
	check(game.building_cost("belt", 100).copper > 1, "Removing the connection never restores the tutorial belt discount")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.add_resource("copper", 10)
	game.select_building("solar")
	game.place_building(Vector2i(31, 22), "solar", 0)
	game.hud.refresh()
	check(game.hud.map_panel.size.y == 152 and game.hud.wave_label.position.y >= 156, "Timer sits outside the minimap background and border")
	check(game.hud.wave_label.get_theme_constant("shadow_outline_size") == 5 and game.hud.wave_label.get_theme_color("font_shadow_color") == Color.BLACK, "Timer text has a surrounding black shadow")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = game.get_canvas_transform() * game.cell_center(Vector2i(31, 22))
	game._input(right)
	game._unhandled_input(right)
	check(game.buildings.has(Vector2i(31, 22)) and not game.right_demolishing, "Repeated right clicks never destroy a structure")
	check(game.selected == "" and game.active_tool == "build", "Right click only cancels construction and tools")
	var delete := InputEventKey.new()
	delete.keycode = KEY_DELETE
	delete.pressed = true
	game.hover_cell = Vector2i(31, 22)
	game._unhandled_input(delete)
	check(game.buildings.has(Vector2i(31, 22)), "Delete is harmless outside demolition mode")
	game.select_tool("abolish")
	game.hud._process(0)
	check(game.hud.screen_edges.visible and game.hud.screen_edges.material.get_shader_parameter("demolishing"), "Demolition enables the red screen-edge glow")
	game.hover_cell = Vector2i(32, 22)
	game.begin_drag(Vector2i(31, 22))
	check(not game.buildings.has(Vector2i(31, 22)), "Left click in demolition mode deletes the building")
	game.finish_drag()
	game._input(right)
	check(game.active_tool == "build", "Right click exits demolition mode")
	game.hud._process(0)
	check(not game.hud.screen_edges.visible, "Red edge glow clears when demolition ends")
	check(game.tutorial.bottom_message() == "", "Pause reminder does not depend on wave number or time")
	game._damage_building(game.current_core, 10)
	game.tutorial.on_wave_completed(1)
	check(game.tutorial.central_message() == "Press space to pause and build.", "First actual building damage immediately shows the pause reminder")
	game.toggle_pause()
	game.hud._process(0)
	check(game.tutorial.paused_once and game.tutorial.central_message() == "", "Scrap instruction waits until a completed wave has left scrap")
	check(game.hud.screen_edges.visible and game.hud.screen_edges.material.get_shader_parameter("paused"), "Pause enables a cyan screen-edge glow")
	game.tutorial.barrier_tree_closed = true
	game.tutorial.collected_tutorial_scrap = 27
	game.hover_cell = game.current_core
	game.hud._refresh_tooltip(Vector2(700, 400))
	game.tutorial.update_info_hover(3.0, game.hud.tooltip.visible)
	check(game.tutorial.info_hover_time == 0, "Hover without Alt never completes the info tutorial")
	alt(true)
	game.hud._refresh_tooltip(Vector2(700, 400))
	check(game.hud.tooltip.visible and game.hud.tooltip_body.text.contains("Health: 1990 / 2000") and game.hud.tooltip_body.text.contains("Copper capacity: 40"), "Alt on a placed core shows live health and storage stats")
	game.tutorial.update_info_hover(0.8, game.hud.tooltip.visible)
	alt(false)
	game.hud._refresh_tooltip()
	game.tutorial.update_info_hover(1.0, game.hud.tooltip.visible)
	check(is_equal_approx(game.tutorial.info_hover_time, 0.8), "Time spent without a visible popup does not count")
	alt(true)
	game.hud._refresh_tooltip(Vector2(700, 400))
	game.tutorial.update_info_hover(1.2, game.hud.tooltip.visible)
	check(game.tutorial.bottom_message() == "", "Two cumulative seconds of Alt inspection dismiss the info hint")
	alt(false)
	game.toggle_pause()
	game._damage_building(game.current_core, 1)
	game.tutorial.on_wave_completed(1)
	check(game.tutorial.bottom_message() == "", "Later damage never restores completed pause or info prompts")
	game.add_resource("copper", 100)
	check(game.inventory.copper == 40, "Resource deliveries respect the initial forty-copper cap")
	game._add_building(Vector2i(25, 20), "copper_store", 0)
	check(game.material_capacity("copper") == 90, "A copper silo adds five hundred to the starting copper cap")
	game.wave = 1
	game._complete_wave()
	var saved: Array = game.saves.snapshot().duplicate(true)
	game.tutorial.info_hover_time = 0
	game.tutorial.extractor_connected_once = false
	game.base_copper_capacity = 900
	check(game.saves.restore(0) and game.saves.snapshot()[1] == saved[1] and game.tutorial.info_hover_time >= saved[3][14] and game.tutorial.extractor_connected_once, "Savings restore capacity, connection milestone and completed tutorial hints")
	var legacy := saved.duplicate(true)
	legacy[0] = 1
	legacy[1].resize(21)
	legacy[3].resize(11)
	var raw := var_to_bytes(legacy)
	var file := FileAccess.open(game.saves.directory.path_join(game.saves.entries[0].file), FileAccess.WRITE)
	file.store_buffer("EWS1".to_ascii_buffer())
	file.store_8(FileAccess.COMPRESSION_ZSTD)
	file.store_32(raw.size())
	file.store_buffer(game.saves.checksum(raw))
	file.store_buffer(raw.compress(FileAccess.COMPRESSION_ZSTD))
	file.close()
	check(game.saves.restore(0) and game.base_copper_capacity == 40 and game.tutorial.extractor_connected_once and game.tutorial.first_damage_taken, "Previous save format migrates capacity, connection and damage progress")
	var info = load("res://scripts/structure_info.gd")
	var complete := true
	for kind in game.BUILDINGS:
		complete = complete and info.description(game, kind).ends_with(".") and info.stats(game, kind).contains("Health:")
		game.hud.show_structure_info(kind, {}, Vector2(700, 400))
		complete = complete and game.hud.tooltip_body.size.y >= game.hud.tooltip_body.get_content_height()
	check(complete, "Every building has a simple description and stats that fit without clipping")
	for entry in game.saves.entries: DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	game.free()
	print("ALT INFO AND DEMOLITION CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)








