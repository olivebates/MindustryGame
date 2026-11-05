extends SceneTree
var game
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.fog_disabled = true
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.onboarding_completed = true
	game.inventory.copper = 500
	game.inventory.iron = 0
	game._reveal_map()
func run() -> void:
	fresh()
	var old: Vector2i = game.current_core
	var latest: Vector2i = old + Vector2i(32, 0)
	game._add_building(latest, "core", 0)
	game.cores.append(latest)
	game.current_core = latest
	game._add_building(old + Vector2i(3, 0), "solar", 0)
	game._add_building(old + Vector2i(5, 0), "solar", 0)
	check(game.building_cost("solar", -1, old).copper == 16 and game.building_cost("solar", -1, latest).copper == 10, "Separate core zones have independent tower inflation")
	game._add_building(old + Vector2i(16, 0), "solar", 0)
	check(game.building_cost("solar", -1, old).copper == 20 and game.building_cost("solar", -1, latest).copper == 13, "An overlapping building contributes to each core range containing it")
	check(game.pricing_core_for(old + Vector2i(18, 0)) == latest and game.building_cost("solar", -1, old + Vector2i(18, 0)).copper == 13, "Overlap placement uses the newest core's local count")
	game.blueprint.assign([{"kind": "solar", "offset": Vector2i.ZERO}, {"kind": "solar", "offset": Vector2i(-32, 0)}])
	check(game.blueprint_cost(latest + Vector2i(0, 3)).copper == 33, "Blueprint quotes combine prices from each placement's core zone")
	game.blueprint[1].offset = Vector2i(0, 1)
	check(game.blueprint_cost(latest + Vector2i(0, 3)).copper == 29 and game.building_cost("solar", -1, latest).copper == 13, "Blueprint quotes apply local sequential inflation without changing owned counts")
	game.blueprint.clear()
	for offset in 4: game._add_building(latest + Vector2i(offset, 4), "wall", 0)
	game.blueprint.assign([{"kind": "solar", "offset": Vector2i.ZERO}, {"kind": "wall", "offset": Vector2i(0, 1)}])
	check(game.blueprint_cost(latest + Vector2i(0, 4)).copper == 16, "Replacing a barrier also lowers later barrier prices in a blueprint quote")
	game.blueprint.clear()
	for offset in 4: game.remove_building(latest + Vector2i(offset, 4), false)
	game.camera.position = game.cell_center(old)
	check(game.building_cost("solar").copper == 20, "GUI quote follows the core around the camera center")
	game.camera.position = game.cell_center(latest)
	check(game.building_cost("solar").copper == 13, "Panning into the new core's range changes the GUI quote")
	game.selected = "solar"
	game.hover_cell = old + Vector2i(18, 0)
	game.hud.ghost_cost.update_preview(Vector2(700, 400))
	check(game.hud.ghost_cost.visible and game.hud.ghost_cost.cost.copper == 13, "Ghost price uses the placement tile rather than the camera quote")
	var wall: Vector2i = latest + Vector2i(0, 2)
	game._add_building(wall, "wall", 0)
	game.buildings[wall].paid_cost = {"copper": 3}
	check(game.can_build(wall, "solar") and game.place_building(wall, "solar", 0, "red") and game.buildings[wall].kind == "solar", "A turret can replace a barrier")
	check(game.buildings[wall].paid_cost.copper == 13 and game.demolitions[-1].kind == "wall", "Barrier replacement pays the local price and dismantles the barrier")
	game.remove_building(wall)
	check(game.building_cost("solar", -1, latest).copper == 13, "Demolition lowers inflation in the appropriate core zone")
	var outside: Vector2i = old + Vector2i(0, -21)
	check(not game.place_building(outside, "solar", 0, "red") and game.hud.feedback_labels[-1].text == "Too far away...", "Out-of-range placement produces the requested flying error")
	var error: Label = game.hud.feedback_labels[-1]
	check(error.get_meta("duration") >= 2.2 and absf(error.get_meta("drift").y) < 40, "Red errors move more slowly and remain visible longer")
	game.inventory.copper = 0
	game.hud.toggle_category("Structures")
	var errors: int = game.hud.feedback_labels.size()
	game.hud.cards.solar.pressed.emit()
	check(game.selected == "solar" and game.hud.feedback_labels.size() == errors, "Unaffordable menu items remain selectable without shortage feedback")
	check(game.textures.has("core_inactive"), "Inactive core has a dedicated red SVG")
	fresh()
	var first: Vector2i = game.current_core
	var frontier: Vector2i = first + Vector2i(32, 0)
	game._add_building(frontier, "core", 0)
	game.cores.append(frontier)
	game.current_core = frontier
	game.tutorial.on_new_core(frontier)
	game.camera.force_update_scroll()
	check(game.tutorial.next_core_message() == "WASD to move camera.\nMove Right.", "The first frontier starts with camera movement guidance")
	game.camera.position = game.cell_center(frontier)
	game.camera.force_update_scroll()
	check(game.tutorial.next_core_message() == "This is your next core to defend.", "Moving the core at least seven tiles into view advances the guidance")
	game.camera.position = game.cell_center(first)
	game.camera.force_update_scroll()
	check(game.tutorial.next_core_message() == "Find your next core.", "Moving away temporarily requests finding the new core")
	check(game.place_building(frontier + Vector2i(0, 3), "belt", 0) and game.tutorial.next_core_stage == 3 and game.tutorial.next_core_message() == "", "The first building in the frontier completes that tutorial")
	var route: Dictionary = game.enemy_navigation.route(game, game.cell_center(first + Vector2i(1, 0)))
	check(route.target == frontier, "Enemies ignore an older core even when it is closer")
	fresh()
	var gate = game.active_spawners[0]
	gate.waves_before_conversion = 1
	gate.turns_into_core = false
	var initial: Vector2i = game.current_core
	game.wave = 1
	game._complete_wave()
	check(gate.converted and game.cores.size() == 1 and game.current_core == initial, "A spawn can finish without creating a new core")
	fresh()
	gate = game.active_spawners[0]
	gate.waves_before_conversion = 1
	var camera_before: Vector2 = game.camera.position
	game.wave = 1
	game._complete_wave()
	check(game.cores.size() == 2 and game.current_core == Vector2i((gate.position / game.TILE).floor()) and game.camera.position == camera_before, "Core creation selects the newest main core without moving the camera automatically")
	fresh()
	game.tutorial.waves_started = true
	game.wave = 1
	game.saves.capture()
	var directory: String = game.saves.directory
	game.tutorial.first_wave_completed = true
	game.tutorial.paused_once = true
	game.tutorial.pause_exit_completed = true
	game.tutorial.barrier_tree_closed = true
	game.tutorial.info_hover_time = 2.0
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.tutorial.next_core_stage = 3
	game.research("barriers", true)
	game.hud.refresh()
	check(FileAccess.file_exists(directory.path_join("tutorial.learned")), "Tutorial learning is stored independently from checkpoints")
	fresh()
	game.saves.directory = directory
	game.saves.read_index()
	check(game.saves.restore(0) and game.tutorial.pause_exit_completed and game.tutorial.next_core_stage == 3, "A fresh game instance retains completed lessons when loading an earlier checkpoint")
	game.paused = false
	check(game.tutorial.central_message() == "" and game.hud.category_buttons.Infrastructure.visible and game.hud.category_buttons.Defence.visible, "Completed pause prompts stay gone and category splits remain unlocked")
	check(game.researched.has("barriers") and game.unlocked("wall"), "Tutorial-unlocked Barrier remains available in earlier checkpoints")
	game.request_next_wave()
	game.advance_wave_warp(0.5)
	check(game.saves.restore(0) and not game.wave_warp_active and game.paused and game.wave == 1, "Rollback cancels a pending transient wave warp")
	fresh()
	game.request_next_wave()
	check(game.wave_warp_active and game.wave == 0 and is_equal_approx(game.wave_warp_speed(), 1.0), "Requesting a wave starts a warp instead of spawning immediately")
	game.advance_wave_warp(1.0)
	check(game.wave == 0 and is_equal_approx(game.wave_warp_speed(), 10.0), "The warp reaches ten times speed halfway through")
	game.paused = true
	game.advance_wave_warp(0.5)
	check(game.wave_warp_elapsed == 1.0 and game.wave == 0, "Pausing suspends the warp")
	game.paused = false
	game.advance_wave_warp(0.5)
	check(is_equal_approx(game.wave_warp_speed(), 5.5) and game.wave == 0, "Warp speed eases down before spawning")
	game.advance_wave_warp(0.5)
	check(game.wave == 1 and not game.wave_warp_active and game.speed == 1, "After two seconds the wave starts and the chosen speed is restored")
	check(game.hud.wave_announcement.text == "Wave 1" and game.hud.wave_announcement.get_theme_font_size("font_size") >= 30 and not game.notice.contains("incoming"), "Wave announcements appear as large unpadded wave numbers above the bottom bar")
	var down := InputEventKey.new()
	down.keycode = KEY_S
	down.physical_keycode = KEY_S
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	game.paused = true
	var before_y: float = game.camera.position.y
	game._process(0.1)
	check(game.camera.position.y > before_y, "Holding S moves the camera down")
	down.pressed = false
	Input.parse_input_event(down.duplicate())
	Input.flush_buffered_events()
	fresh()
	game.speed = 3
	game.request_next_wave()
	game.advance_wave_warp(1.0)
	check(is_equal_approx(game.wave_warp_speed(), 10.0), "Warp peaks at ten times speed even when triple speed was selected")
	game.advance_wave_warp(1.0)
	check(game.speed == 3 and is_equal_approx(game.wave_warp_speed(), 3.0), "Warp restores the selected triple speed afterwards")
	print("CORE ZONES AND PROGRESS CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)


