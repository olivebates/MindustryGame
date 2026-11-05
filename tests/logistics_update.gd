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
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	game.core_build_radius = 100000
	game.separate_build_categories = true
	game.researched["barriers"] = true
	game.researched["weapons"] = true
	game.researched["industry"] = true
	game.researched["splitter"] = true
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
	game.base_material_capacity = 100000
	game.base_copper_capacity = 100000
	game.fog_disabled = true
	game.rocks.clear()
	for cell in game.buildings.keys():
		if cell != game.CORE: game.remove_building(cell, false)
	for resource in game.inventory: game.inventory[resource] = 10000
func add(cell: Vector2i, kind: String = "belt", direction: int = 0) -> Dictionary:
	game._add_building(cell, kind, direction)
	return game.buildings[cell]
func run() -> void:
	fresh()
	add(Vector2i(4, 4), "wall")
	add(Vector2i(5, 4))
	add(Vector2i(6, 5), "turret")
	game.selected = "drill"
	var camera_before: Vector2 = game.camera.position
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = game.get_canvas_transform() * game.cell_center(Vector2i(4, 4))
	game._unhandled_input(middle)
	check(game.middle_blueprint_drag and game.active_tool == "blueprint_select" and game.selected == "", "Middle press starts a blueprint selection box and clears construction")
	game.extend_drag(Vector2i(7, 6))
	check(game.blueprint_end == Vector2i(7, 6) and game.camera.position == camera_before, "Middle dragging grows the box without panning the camera")
	middle.pressed = false
	middle.position = game.get_canvas_transform() * game.cell_center(Vector2i(7, 6))
	game._input(middle)
	check(not game.dragging and not game.middle_blueprint_drag and game.active_tool == "blueprint_stamp", "Middle release transitions directly into blueprint stamping")
	check(game.blueprint.size() == 3 and game.stamp_blueprint(Vector2i(14, 4)), "Middle-drag blueprint captures and places the complete configuration")
	check(game.buildings[Vector2i(16, 5)].ammo == 80, "Blueprint-created turrets start fully loaded")
	game.begin_middle_blueprint(Vector2i(4, 4))
	game.cancel_build_selection()
	check(not game.middle_blueprint_drag and game.active_tool == "build" and not game.dragging, "Right-click cancellation also stops a middle-drag selection")
	fresh()
	for kind in ["turret", "repeater", "cannon"]:
		var tower := add(Vector2i(10, 10), kind)
		check(tower.ammo == 80, "%s spawns with a full magazine" % kind)
		tower.ammo = 7
		game.hover_cell = Vector2i(10, 10)
		var inventory: Dictionary = game.inventory.duplicate()
		var reload_key := InputEventKey.new()
		reload_key.keycode = KEY_E
		reload_key.pressed = true
		game._unhandled_input(reload_key)
		check(tower.ammo == 7 and game.inventory == inventory, "E cannot reload %s or spend stored materials" % kind)
		var rectangle: Rect2 = game.ammo_bar_rect(Vector2i(10, 10))
		check(rectangle.size == Vector2(game.TILE * game.footprint_size(kind), 3) and rectangle.end == game.building_center(Vector2i(10, 10)) + Vector2.ONE * (game.TILE * game.footprint_size(kind) / 2.0), "%s ammo bar spans the sprite and is flush inside its bottom edge" % kind)
		game.remove_building(Vector2i(10, 10), false)
	var tower := add(Vector2i(10, 10), "turret")
	tower.ammo = 7
	var feeder := add(Vector2i(9, 10))
	feeder.item = "iron"
	game._update_items(game.FLOW_INTERVAL * 4 + 0.001)
	check(tower.ammo == 8 and feeder.item == "", "Conveyors remain able to refill a depleted turret")
	fresh()
	var center := Vector2i(10, 10)
	var router := add(center, "splitter")
	add(center + Vector2i.LEFT, "belt", 0)
	add(center + Vector2i.RIGHT, "belt", 0)
	add(center + Vector2i.DOWN, "belt", 1)
	add(center + Vector2i.UP, "belt", 3)
	var outputs: Array = game.splitter_outputs(center)
	check(outputs.size() == 3 and not outputs.has(2), "Splitter recognizes outgoing belts and excludes its incoming belt")
	var totals := {0: 0, 1: 0, 3: 0}
	var conserved := true
	for index in 12:
		var resource: String = game.Content.RESOURCES[index % game.Content.RESOURCES.size()]
		var input: Dictionary = game.buildings[center + Vector2i.LEFT]
		input.item = resource
		input.travel = 1.0
		game._move_items()
		conserved = conserved and router.item == resource and input.item == ""
		game._update_items(game.FLOW_INTERVAL * 4 + 0.001)
		var count := 0
		for direction in outputs:
			var belt: Dictionary = game.buildings[center + game.DIRS[direction]]
			if belt.item != "":
				count += 1
				conserved = conserved and belt.item == resource
				totals[direction] += 1
				belt.item = ""
				belt.travel = 0.0
		conserved = conserved and count == 1
	check(conserved, "Splitter routes mixed copper, iron, verdite, alloy and scrap without loss or duplication")
	check(totals[0] == 4 and totals[1] == 4 and totals[3] == 4, "Splitter distributes evenly in a rotating round-robin sequence")
	router.item = "copper"
	router.next_output = 0
	router.route_dir = -1
	game.buildings[center + Vector2i.RIGHT].item = "iron"
	game._update_items(game.FLOW_INTERVAL * 4)
	check(router.item == "" and router.next_output == 2, "Splitter skips a blocked output and delivers to the next free belt")
	game.buildings[center + Vector2i.RIGHT].item = ""
	game._update_items(game.FLOW_INTERVAL * 4)
	check(router.item == "" and router.next_output == 2, "Splitter advances its direction only after successful delivery")
	router.item = "verdite"
	router.route_dir = 0
	router.travel = 0.5
	game.remove_building(center + Vector2i.RIGHT, false)
	game._update_items(0.1)
	check(router.route_dir == 3 and router.item == "verdite", "Splitter selects a remaining unfilled belt when its route is removed")
	fresh()
	router = add(center, "splitter")
	router.item = "alloy"
	game._update_items(10)
	check(router.item == "alloy" and router.travel == 0 and game.output_target(center, router) == game.INVALID, "An unconnected splitter stores its cargo safely at its center")
	fresh()
	add(center, "splitter", 3)
	check(game.capture_blueprint(center, center) and game.stamp_blueprint(Vector2i(20, 10)), "Splitters can be copied with blueprints")
	check(game.buildings[Vector2i(20, 10)].next_output == 3 and game.buildings[Vector2i(20, 10)].item == "", "Copied splitters preserve initial direction without copying cargo")
	fresh()
	var belt := add(Vector2i(4, 4), "belt", 0)
	add(Vector2i(4, 5), "wall")
	game.begin_drag(Vector2i(4, 4))
	game.extend_drag(Vector2i(4, 5))
	check(belt.dir == 1 and game.buildings[Vector2i(4, 5)].kind == "wall", "An explicitly dragged conveyor follows the drag even toward occupied tiles")
	fresh()
	add(Vector2i(4, 4), "belt", 0)
	var existing := add(Vector2i(5, 4), "belt", 2)
	add(Vector2i(5, 5), "wall")
	game.begin_drag(Vector2i(4, 4))
	game.extend_drag(Vector2i(5, 4))
	check(existing.dir == 0 and game.tunnel_pending == game.INVALID and not game.drag_blocked, "Painting a reverse belt aligns it with the drag")
	game.extend_drag(Vector2i(5, 5))
	check(existing.dir == 1, "A painted conveyor turns as the drag changes direction")
	var header: Panel = game.hud.root.get_node("MaterialInventory")
	check(header.position.x == 0 and header.size.x == 160 and game.hud.palette.size.x == game.hud.root.size.x, "Inventory occupies the left edge and the bottom GUI spans the viewport")
	var frame: StyleBoxFlat = header.get_theme_stylebox("panel")
	check(frame.bg_color == game.hud.BACK and frame.border_color == game.hud.BORDER and frame.border_width_top == 2, "GUI panels retain black backgrounds and two-pixel tan outlines")
	var clean_catalog := true
	for data in game.BUILDINGS.values(): clean_catalog = clean_catalog and not data.has("description")
	for data in game.TECH.values(): clean_catalog = clean_catalog and not data.has("description")
	game.hud.refresh()
	check(clean_catalog and game.hud.tool_hint.text == "", "Description fields and instructional HUD prose have been removed")
	check(not game.audio.streams.has("pickup"), "Resource pickup audio is no longer part of the active sound catalog")
	game.hud.toggle_category("Logistics")
	check(game.hud.cards.has("splitter"), "The new splitter is available in Logistics")
	print("LOGISTICS UPDATE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(0 if failures == 0 else 1)











