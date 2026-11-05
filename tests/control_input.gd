extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	game.core_build_radius = 100000
	game.separate_build_categories = true
	game.researched["barriers"] = true
	game.researched["weapons"] = true
	game.researched["industry"] = true
	for kind in ["turret", "repeater", "cannon"]:
		for color in ["red", "green", "blue"]: game.researched[kind + "_" + color] = true
	game.base_copper_capacity = 500
	root.add_child(game)
	game.tutorial.extractors_ever_built = 1
	game.tutorial.extractor_connected_once = true
	game.tutorial.waves_started = true
	game.tutorial.tech_available = true
	game.selected = "belt"
	game.set_process(false)
	game.fog_disabled = true
	game.rocks.clear()
	game.ores.clear()
	for resource in game.inventory: game.inventory[resource] = 0
	var wall := Vector2i(26, 20)
	game._add_building(wall, "wall", 0)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = game.get_canvas_transform() * game.cell_center(wall)
	game.selected = "drill"
	game._unhandled_input(right)
	check(game.selected == "" and game.active_tool == "build", "Right click deselects the current building")
	check(game.buildings.has(wall) and not game.right_demolishing, "Deselecting by right click does not destroy the building under the pointer")
	game._unhandled_input(right)
	check(game.buildings.has(wall), "A second right click with no building selected preserves structures")
	game.selected = "turret"
	game._input(right)
	check(game.selected == "" and not game.right_demolishing, "Global right-click cancellation works before GUI event consumption")
	game._add_building(wall, "wall", 0)
	game.hover_cell = wall
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	game._unhandled_input(key)
	check(game.active_tool == "abolish" and game.selected == "", "X activates Demolish mode")
	check(game.buildings.has(wall), "X does not immediately delete the hovered building")
	key.echo = true
	game._unhandled_input(key)
	check(game.active_tool == "abolish", "Holding X does not repeatedly toggle the tool")
	key.echo = false
	game._unhandled_input(key)
	check(game.active_tool == "build", "Pressing X again leaves Demolish mode")
	var copper := Vector2i(10, 10)
	var iron := Vector2i(11, 10)
	var verdite := Vector2i(12, 10)
	game.ores[copper] = "copper"
	game.ores[iron] = "iron"
	game.ores[verdite] = "verdite"
	game.update_manual_mining(0.99, copper, true)
	check(game.inventory.copper == 0, "Manual mining waits for a complete held second")
	game.update_manual_mining(0.01, copper, true)
	check(game.inventory.copper == 1, "Holding left on ore yields exactly one item after one second")
	game.update_manual_mining(2.25, copper, true)
	check(game.inventory.copper == 3 and is_equal_approx(game.manual_mining_progress, 0.25), "Continuous manual mining preserves the one-item-per-second rate")
	game.update_manual_mining(0, copper, false)
	check(game.manual_mining_progress == 0 and game.manual_mining_cell == game.INVALID, "Releasing the mouse resets mining progress")
	game.update_manual_mining(0.6, copper, true)
	game.update_manual_mining(0, copper, false)
	game.update_manual_mining(0.5, copper, true)
	check(game.inventory.copper == 3, "Repeated short clicks cannot accumulate a mining reward")
	game.update_manual_mining(0.6, iron, true)
	check(game.inventory.iron == 0 and is_equal_approx(game.manual_mining_progress, 0.6), "Changing ore targets restarts the mining interval")
	game.update_manual_mining(0.4, iron, true)
	check(game.inventory.iron == 1, "Manual mining yields the targeted iron resource")
	game.update_manual_mining(1, verdite, true)
	check(game.inventory.verdite == 1, "Manual mining also supports green verdite")
	game.update_manual_mining(0, copper, false)
	game.update_manual_mining(0.5, copper, true)
	game.paused = true
	game.update_manual_mining(4, copper, true)
	check(game.inventory.copper == 3 and is_equal_approx(game.manual_mining_progress, 0.5), "Pause freezes manual mining and its progress")
	game.paused = false
	game.update_manual_mining(0.5, copper, true)
	check(game.inventory.copper == 4, "Mining continues from its partial interval after resuming")
	game.speed = 3
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 5, "Manual mining remains one item per real second at higher simulation speed")
	game.inventory.copper = game.material_capacity("copper")
	game.update_manual_mining(2, copper, true)
	check(game.inventory.copper == game.material_capacity("copper") and game.manual_mining_progress == 0, "Manual mining respects material capacity")
	game.inventory.copper = 5
	game._add_building(copper, "belt", 0)
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 5, "Manual mining cannot extract through a building")
	game.remove_building(copper, false)
	game.fog_disabled = false
	game.visible_cells.erase(copper)
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 5, "Hidden ore cannot be mined through fog")
	game.fog_disabled = true
	game.active_tool = "clear"
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 5, "Other tools take priority over manual mining")
	game.active_tool = "build"
	game.selected = "drill"
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 5, "Selected construction takes priority over manual mining")
	game.cancel_build_selection()
	game.update_manual_mining(1, copper, true)
	check(game.inventory.copper == 6, "Mining becomes available immediately after cancelling construction")
	print("CONTROL AND MINING CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(0 if failures == 0 else 1)



