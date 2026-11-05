extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1
func fresh(clear_world: bool = true) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	game.core_build_radius = 100000
	game.separate_build_categories = true
	game.researched["barriers"] = true
	game.researched["weapons"] = true
	game.researched["industry"] = true
	game.researched["copper_storage"] = true
	for kind in ["turret", "repeater", "cannon"]:
		for color in ["red", "green", "blue"]: game.researched[kind + "_" + color] = true
	game.base_copper_capacity = 500
	root.add_child(game)
	game.tutorial.extractors_ever_built = 1
	game.tutorial.extractor_connected_once = true
	for gate in game.spawners: gate.wave_color_palettes.clear()
	game.tutorial.waves_started = true
	game.tutorial.tech_available = true
	game.selected = "belt"
	game.set_process(false)
	game.base_material_capacity = 100000
	game.base_copper_capacity = 100000
	game.fog_disabled = true
	if clear_world:
		for cell in game.buildings.keys():
			if cell != game.CORE: game.remove_building(cell, false)
		game.rocks.clear()
		game.ores.clear()
		for resource in game.inventory: game.inventory[resource] = 10000
func add(cell: Vector2i, kind: String = "belt", direction: int = 0) -> Dictionary:
	game._add_building(cell, kind, direction)
	return game.buildings[cell]
func run() -> void:
	fresh(false)
	for i in 1000: game.simulate(0.05)
	check(game.inventory.copper == 0 and game.inventory.iron == 0 and game.buildings.size() == 1, "Authored levels start with only the core and no free mining lines")
	check(game.wave == 0 and not game.wave_active(), "Initial countdown leaves time for factory preparation")
	check(add(Vector2i(29, 19), "turret").ammo == 80, "Created ammo turrets are fully loaded")
	fresh()
	var a := Vector2i(4, 4)
	var b := Vector2i(5, 4)
	add(a).item = "copper"
	add(b)
	game._update_items(game.FLOW_INTERVAL * 0.5)
	check(is_equal_approx(game.buildings[a].travel, 0.5) and game.buildings[b].item == "", "Cargo interpolates halfway before logical transfer")
	check(is_equal_approx(game.FLOW_INTERVAL, 1.0), "Belts transport one item per second")
	game._update_items(game.FLOW_INTERVAL * 0.5 + 0.0001)
	check(game.buildings[a].item == "" and game.buildings[b].item == "copper", "Cargo arrives after a complete lerp")
	check(game.buildings[b].travel == 0, "Arriving cargo starts at the next tile center without teleporting ahead")
	game._update_items(1.0)
	check(game.buildings[b].item == "copper" and game.buildings[b].travel <= 0.43, "Back pressure preserves cargo on an unconnected belt")
	fresh()
	game.begin_drag(Vector2i(4, 4))
	game.extend_drag(Vector2i(8, 4))
	game.extend_drag(Vector2i(8, 8))
	game.finish_drag()
	check(game.buildings[Vector2i(8, 4)].dir == 1 and game.buildings[Vector2i(7, 4)].dir == 0, "Dragging makes a functional conveyor corner")
	check(game.buildings[Vector2i(8, 4)].input_dir == 0, "Conveyor corner remembers its incoming direction for its SVG")
	check(game.buildings.has(Vector2i(8, 7)), "Fast dragging fills skipped grid cells")
	fresh()
	game.begin_drag(Vector2i(4, 4))
	game.extend_drag(Vector2i(7, 4), true)
	game.extend_drag(Vector2i(10, 9), true)
	check(game.buildings.has(Vector2i(10, 4)) and not game.buildings.has(Vector2i(10, 9)), "Shift locks a drag to its first built direction")
	game.finish_drag()
	game.ores[Vector2i(12, 6)] = "verdite"
	add(Vector2i(12, 7))
	check(game.place_building(Vector2i(12, 6), "drill", 3) and game.buildings[Vector2i(12, 6)].dir == 0, "A newly placed extractor has no orientation")
	fresh()
	var crossed := add(Vector2i(6, 5), "belt", 1)
	crossed.item = "iron"
	game.begin_drag(Vector2i(4, 5))
	game.extend_drag(Vector2i(8, 5))
	game.finish_drag()
	var entrance := Vector2i(5, 5)
	var exit := Vector2i(7, 5)
	check(game.buildings[entrance].tunnel_pair == exit and game.buildings[exit].tunnel_pair == entrance, "Crossing a belt creates a linked entrance and exit")
	check(game.buildings[Vector2i(6, 5)].dir == 1 and crossed.item == "iron", "Crossing leaves the existing belt and its cargo intact")
	game.buildings[entrance].item = "copper"
	game._update_items(game.FLOW_INTERVAL + 0.001)
	check(game.buildings[exit].item == "copper" and crossed.item == "iron", "Tunnel cargo teleports past the independent crossing belt")
	game.remove_building(exit)
	check(not game.buildings.has(entrance) and not game.buildings.has(exit), "Demolishing either tunnel endpoint removes both")
	check(game.buildings.has(Vector2i(6, 5)), "Paired demolition keeps the crossed conveyor")
	fresh()
	for x in range(4, 13): add(Vector2i(x, 5), "belt", 1)
	game.begin_drag(Vector2i(3, 5))
	game.extend_drag(Vector2i(13, 5))
	check(game.buildings[Vector2i(3, 5)].tunnel_pair == Vector2i(13, 5), "A tunnel spanning exactly ten tiles is allowed")
	fresh()
	for x in range(4, 14): add(Vector2i(x, 5), "belt", 1)
	game.begin_drag(Vector2i(3, 5))
	game.extend_drag(Vector2i(14, 5))
	check(game.buildings[Vector2i(3, 5)].tunnel_role == "" and not game.buildings.has(Vector2i(14, 5)), "A tunnel longer than ten tiles is rejected without creating an orphan")
	fresh()
	for x in range(4, 10): add(Vector2i(x, 5)).item = "copper"
	var initial: Dictionary = game.inventory.duplicate()
	game.active_tool = "clear"
	game.begin_drag(Vector2i(4, 5))
	game.extend_drag(Vector2i(9, 5))
	game.finish_drag()
	var empty := true
	for x in range(4, 10): empty = empty and game.buildings[Vector2i(x, 5)].item == ""
	check(empty and game.buildings.size() == 7, "Clear track drag removes cargo while retaining every belt")
	check(game.inventory == initial, "Clearing cargo does not create free stored resources")
	fresh()
	game.researched.forge = true
	var before: Dictionary = game.inventory.duplicate()
	check(game.place_building(a, "forge", 0), "Unlocked forge can be constructed")
	check(game.anchor_at(a + Vector2i.ONE) == a and game.occupied.size() == 5, "Forge occupies all four tiles of its 2 by 2 footprint")
	check(not game.place_building(a + Vector2i.ONE, "wall", 0), "Construction cannot overlap a forge's secondary tiles")
	game.remove_building(a + Vector2i.ONE)
	check(game.inventory.copper == before.copper - 80 + 8 and game.inventory.iron == before.iron - 50 + 5, "Demolition returns only ten percent of paid construction materials")
	check(game.anchor_at(a) == game.INVALID and game.anchor_at(a + Vector2i.ONE) == game.INVALID, "Demolition from any forge tile releases the entire footprint")
	var after: Dictionary = game.inventory.duplicate()
	game.remove_building(a)
	check(game.inventory == after, "Repeated demolition cannot refund the same structure twice")
	fresh()
	var forge := add(a, "forge")
	check(game.can_receive(a + Vector2i.ONE, "copper") and game.can_receive(a + Vector2i.ONE, "iron"), "Every forge footprint tile can accept recipe inputs")
	forge.buffer.copper = 2
	forge.buffer.iron = 2
	game._update_forge(forge, 2.9)
	check(forge.item == "", "Forge requires the full three-second crafting time")
	game._update_forge(forge, 0.11)
	check(forge.item == "alloy" and forge.buffer.copper == 0 and forge.buffer.iron == 0, "Forge consumes two copper and two iron to make one repair alloy")
	check(game.output_target(a, forge) == a + Vector2i(2, 0), "Forge output clears its own two-tile footprint")
	fresh()
	check(not game.research("cannon"), "Tech tree enforces research prerequisites")
	var cu: int = game.inventory.copper
	check(game.research("repeater") and game.unlocked("repeater") and game.inventory.copper == cu - 60, "Research charges materials and unlocks a new turret")
	check(not game.research("repeater"), "Research cannot be purchased twice")
	check(game.research("cannon") and game.unlocked("cannon"), "Child research becomes available after its parent")
	game.research("conveyor_speed", true)
	var wall := add(a, "wall")
	check(game.research("armor") and is_equal_approx(wall.max_hp, 550 * 1.25), "Health upgrade affects existing structures")
	check(is_equal_approx(add(b, "wall").max_hp, 550 * 1.25), "Health upgrade also affects future structures")
	check(game.research("forge") and game.research("healer") and game.unlocked("healer"), "Production research leads to healing-beacon research")
	fresh()
	var healer := add(Vector2i(10, 10), "healer")
	var inside := add(Vector2i(12, 10), "wall")
	var outside := add(Vector2i(12, 11), "wall")
	inside.hp = 100.0
	outside.hp = 100.0
	healer.buffer.verdite = 0
	healer.buffer.alloy = 0
	game._update_healer(Vector2i(10, 10), healer, 1.0)
	check(inside.hp == 100 and healer.buffer.alloy == 0, "Beacon cannot operate without consumables")
	check(not game.can_receive(Vector2i(10, 10), "verdite") and not game.can_receive(Vector2i(10, 10), "alloy"), "Beacons cannot accept either consumable between waves")
	healer.buffer.verdite = 2
	healer.buffer.alloy = 2
	game.spawn_remaining = 1
	healer.cooldown = 0
	game._update_healer(Vector2i(10, 10), healer, 0.99)
	check(inside.hp == 100, "Healing waits for the full one-second pulse interval")
	game._update_healer(Vector2i(10, 10), healer, 0.01)
	check(is_equal_approx(inside.hp, 105.5), "Healing restores exactly one percent of maximum HP per second")
	check(outside.hp == 100, "Healing excludes buildings outside a two-tile circular radius")
	check(healer.buffer.verdite == 1 and healer.buffer.alloy == 1, "A healing pulse consumes one verdite and one repair alloy")
	check(game.can_receive(Vector2i(10, 10), "verdite") and game.can_receive(Vector2i(10, 10), "alloy"), "Beacon accepts both consumables during active waves")
	healer.buffer.alloy = 0
	game._update_healer(Vector2i(10, 10), healer, 1.0)
	check(is_equal_approx(inside.hp, 105.5), "Beacon cannot heal without repair alloy")
	fresh()
	var turret := add(a, "turret")
	var cannon := add(Vector2i(6, 4), "cannon")
	check(turret.ammo == 80 and cannon.ammo == 80, "New copper and iron weapons start with full magazines")
	turret.ammo = 0
	cannon.ammo = 0
	var loading_inventory: Dictionary = game.inventory.duplicate()
	game.load_ammo(a)
	check(turret.ammo == 0 and game.can_receive(a, "copper"), "Manual turret loading is disabled while conveyor loading remains enabled")
	game.spawn_remaining = 1
	game.load_ammo(a)
	game.load_ammo(Vector2i(6, 4))
	check(turret.ammo == 0 and cannon.ammo == 0 and game.inventory == loading_inventory, "Manual loading cannot fill turrets or spend storage during waves")
	check(game.can_receive(Vector2i(6, 4), "iron") and not game.can_receive(Vector2i(6, 4), "copper"), "Iron cannon accepts iron and rejects copper")
	var strengths := {"red": "green", "green": "blue", "blue": "red"}
	for attacker in ["red", "green", "blue"]:
		for defender in ["red", "green", "blue"]:
			turret.color = attacker
			turret.ammo = 80
			turret.cooldown = 0.0
			var enemy: Dictionary = game.create_enemy("scout", game.cell_center(a) + Vector2(120, 0), defender)
			enemy.hp = 1000.0
			enemy.max_hp = 1000.0
			game.enemies.clear()
			game.enemies.append(enemy)
			game._update_turret(a, turret, 0.05)
			var factor := 1.0 if attacker == defender else (2.0 if strengths[attacker] == defender else 0.5)
			check(is_equal_approx(1000 - enemy.hp, 22 * factor), "%s turret vs %s enemy applies correct affinity damage" % [attacker, defender])
	fresh()
	game.selected = "turret"
	var savings: Dictionary = game.inventory.duplicate()
	game.begin_drag(a)
	check(game.radial_pending == a and not game.buildings.has(a), "Turret press opens the radial picker before construction")
	check(game.hud.radial.selected_at(Vector2(0, -65)) == "red" and game.hud.radial.selected_at(Vector2.ZERO) == "", "Radial picker requires dragging onto a color")
	check(not game.finish_affinity("") and game.inventory == savings, "Releasing without selecting a color cancels without charging resources")
	game.begin_drag(a)
	check(game.finish_affinity("green") and game.buildings[a].color == "green", "Completing radial selection constructs the chosen turret color")
	check(not game.place_building(b, "turret", 0), "Turrets cannot bypass mandatory color selection")
	fresh()
	game.launch_wave()
	game.simulate(0.05)
	check(game.wave == 1 and game.enemies.size() == 1 and game.spawn_remaining == game.last_wave_budget / game.Content.ENEMY_TYPES.scout.credits - 1, "Manual wave launch starts the spawn queue")
	check(game.enemies[0].color == game.current_wave_color, "Wave enemies share the deterministically planned color")
	check(game.TEAM_COLORS.has(game.current_wave_color), "Wave colors stay within the configured palette")
	check(game.Content.ENEMY_TYPES.size() == 7, "Roster contains both original enemies plus five new types")
	game.enemies.clear()
	game.wave = 8
	game.active_spawners[0].credits_per_wave = PackedInt32Array([1000])
	game.active_spawners[0].allowed_enemies = PackedStringArray(game.Content.ENEMY_TYPES.keys())
	game._prepare_colors(8)
	game._plan_wave()
	var planned_count: int = game.spawn_queue.size()
	for i in planned_count:
		game._spawn_enemy()
		game.spawn_remaining -= 1
	var kinds: Dictionary = {}
	var uniform := true
	for enemy in game.enemies:
		kinds[enemy.kind] = true
		uniform = uniform and enemy.color == game.current_wave_color
	check(kinds.has("bulwark") and uniform, "Late waves prioritize the most expensive enemy with a shared color")
	fresh()
	var runner: Dictionary = game.create_enemy("runner", game.cell_center(Vector2i(40, 22)), "blue")
	runner.angle = 0.0
	game.enemies.clear()
	game.enemies.append(runner)
	game._update_enemies(0.1)
	check(runner.velocity == Vector2.ZERO, "Enemies wind up before moving")
	check(absf(runner.angle) > 0.01 and absf(runner.angle) < PI - 0.01, "Enemy rotation lerps instead of snapping to face the core")
	for i in 3: game._update_enemies(0.1)
	check(runner.velocity.length() > 0 and runner.velocity.length() < runner.speed, "Enemy movement accelerates gradually after windup")
	runner.pos = game.cell_center(game.CORE) + Vector2(40, 0)
	runner.velocity = Vector2(-40, 0)
	game._update_enemies(0.1)
	check(runner.velocity.length() > 0 and runner.velocity.length() < 40, "Enemies brake gradually when entering attack range")
	fresh()
	game.researched.forge = true
	game.researched.healer = true
	game.place_building(Vector2i(4, 4), "forge", 1)
	game.place_building(Vector2i(7, 4), "turret", 0, "blue")
	game.place_building(Vector2i(7, 6), "healer", 0)
	game.buildings[Vector2i(7, 4)].ammo = 50
	game.buildings[Vector2i(7, 6)].buffer.alloy = 15
	check(game.capture_blueprint(Vector2i(4, 4), Vector2i(8, 7)) and game.blueprint.size() == 3, "Blueprint captures complete multi-tile buildings and their configuration")
	var price: Dictionary = game.blueprint_cost()
	var wallet: Dictionary = game.inventory.duplicate()
	check(game.stamp_blueprint(Vector2i(14, 4)), "A valid blueprint stamps all buildings atomically")
	check(game.buildings[Vector2i(14, 4)].dir == 1 and game.buildings[Vector2i(17, 4)].color == "blue", "Blueprint preserves forge orientation and turret affinity")
	check(game.buildings[Vector2i(17, 4)].ammo == 80 and game.buildings[Vector2i(17, 6)].buffer.alloy == 0, "Blueprint turrets start full while production inventory is not cloned")
	check(game.inventory.copper == wallet.copper - price.copper and game.inventory.alloy == wallet.alloy - price.alloy, "Blueprint charges the combined normal construction cost")
	wallet = game.inventory.duplicate()
	var count: int = game.buildings.size()
	check(not game.stamp_blueprint(Vector2i(14, 4)) and game.inventory == wallet and game.buildings.size() == count, "Blocked blueprint leaves resources and world unchanged")
	game.inventory.copper = 0
	check(not game.stamp_blueprint(Vector2i(25, 4)), "Blueprint cannot partially build when total materials are insufficient")
	fresh()
	add(Vector2i(6, 5), "belt", 1)
	game.begin_drag(Vector2i(4, 5))
	game.extend_drag(Vector2i(8, 5))
	game.finish_drag()
	game.capture_blueprint(Vector2i(4, 5), Vector2i(8, 5))
	check(game.stamp_blueprint(Vector2i(4, 10)) and game.buildings[Vector2i(5, 10)].tunnel_pair == Vector2i(7, 10), "Blueprint remaps copied tunnel links to the new endpoints")
	game.active_tool = "blueprint_stamp"
	game.hover_cell = Vector2i(5, 10)
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	cancel.position = game.get_canvas_transform() * game.cell_center(Vector2i(5, 10))
	game._unhandled_input(cancel)
	check(game.active_tool == "build" and not game.right_demolishing and game.buildings.has(Vector2i(5, 10)), "Right-click cancels blueprint mode without demolishing under the cursor")
	game._unhandled_input(cancel)
	check(game.buildings.has(Vector2i(5, 10)) and game.buildings.has(Vector2i(7, 10)), "Ordinary right-click preserves both tunnel endpoints")
	fresh()
	game.wave = 12
	for spawner in game.spawners: spawner.converted = spawner != game.active_spawners[0]
	game.active_spawners[0].waves_completed = game.active_spawners[0].waves_before_conversion - 1
	game.wave_in_progress = true
	game.simulate(0.05)
	check(game.won and game.paused, "Converting the final enemy spawn enters the victory state")
	game._damage_building(game.current_core, 3000)
	check(game.lost and game.core_health == 0, "Core destruction still ends the expedition")
	fresh()
	game.wave = 7
	game._prepare_colors(7)
	game.active_spawners[0].credits_per_wave = PackedInt32Array([200])
	game._plan_wave()
	var plan: Array = game.spawn_queue.duplicate(true)
	var plan_color: String = game.current_wave_color
	for i in 300:
		game.rng.randf()
		game._sparks(Vector2.ZERO, Color.WHITE, 1)
	game._prepare_colors(7)
	game._plan_wave()
	check(plan == game.spawn_queue and plan_color == game.current_wave_color, "Wave-number seed reproduces enemy types, positions and color independently of effects RNG")
	var spent := 0
	for entry in game.spawn_queue: spent += game.Content.ENEMY_TYPES[entry.kind].credits
	check(spent <= 200 and spent > 190, "Seeded wave roster spends the configured credit budget without overspending")
	game.wave = 2
	game.active_spawners[0].credits_per_wave = PackedInt32Array([100])
	game.active_spawners[0].allowed_enemies = PackedStringArray(["runner"])
	game.active_spawners[0].possible_colors = PackedStringArray(["blue"])
	game._prepare_colors(2)
	game._plan_wave()
	var correct_palette := true
	for entry in game.spawn_queue: correct_palette = correct_palette and entry.color == "blue" and entry.kind == "runner"
	check(game.spawn_queue.size() == 50 and correct_palette, "Spawner budget, allowed types and allowed colors constrain the seeded roster")
	game.active_spawners[0].wave_color_palettes.append(PackedStringArray(["green"]))
	game._prepare_colors(2)
	game._plan_wave()
	check(game.current_wave_color == "green", "Spawner supports a separate allowed-color palette for each configured wave")
	fresh()
	var first_gate = game.active_spawners[0]
	check(game.active_spawners.size() == 1 and first_gate.Order == 1, "Only the lowest unconverted Order activates initially")
	var exported_order := false
	for property in first_gate.get_property_list():
		if property.name == "Order": exported_order = (property.usage & PROPERTY_USAGE_EDITOR) != 0
	check(exported_order, "Enemy spawn Order is exported in the Godot inspector")
	game.wave = 1
	game.wave_in_progress = true
	game.simulate(0.05)
	check(not first_gate.converted and first_gate.waves_completed == 1, "Spawner remains active until its configured number of completed turns")
	first_gate.waves_completed = first_gate.waves_before_conversion - 1
	game.wave_in_progress = true
	game.simulate(0.05)
	var gate_cell := Vector2i((first_gate.position / game.TILE).floor())
	check(first_gate.converted and game.cores.has(gate_cell) and game.buildings[gate_cell].kind == "core", "Cleared spawn converts into a real core building")
	check(game.current_core == gate_cell and game.active_spawners[0].Order == 2, "Core conversion activates the next ordered enemy spawn")
	check(game.wave == 1 and not game.wave_active(), "Advancing to a new gate does not start a wave automatically")
	fresh()
	game.spawners[1].Order = 1
	game._activate_spawners()
	check(game.active_spawners.size() == 2, "Spawns with the same Order activate together")
	fresh()
	game.fog_disabled = false
	game._reveal_map()
	check(game.is_cell_visible(game.CORE + Vector2i(0, 20)), "Fog reveals the complete twenty-tile radius around a core")
	check(not game.is_cell_visible(game.CORE + Vector2i(0, 21)), "Fog hides terrain outside the core radius when no corridor reaches it")
	check(game.is_cell_visible(Vector2i(44, 31)) and not game.is_cell_visible(Vector2i(44, 32)), "Fog reveals a twenty-tile-wide corridor to the active spawn")
	check(not game.is_cell_visible(Vector2i(95, 45)), "Future enemy spawns remain behind fog")
	check(not game.can_build(Vector2i(95, 50), "wall"), "Construction cannot bypass fog of war")
	fresh()
	check(game.place_building(Vector2i(4, 4), "wall", 0), "First barrier can be placed at base price")
	check(game.building_cost("wall").copper == roundi(3 * 1.05), "Repeated barrier placement increases its next price by five percent")
	check(game.building_cost("drill").copper == 5, "Price inflation is independent for each building type")
	game.placement_counts.belt = 100
	check(game.building_cost("belt", 100).copper == roundi(pow(1.01, 100)), "Conveyor prices compound at one percent per placement")
	var old_count: int = game.placement_counts.wall
	game.place_building(Vector2i(4, 4), "wall", 0)
	check(game.placement_counts.wall == old_count, "Failed placements do not increase prices")
	game.launch_wave()
	check(game.building_cost("wall").copper == 3 and game.building_cost("belt").copper == 1, "Starting a wave preserves prices based on owned buildings")
	fresh()
	add(Vector2i(4, 4), "wall")
	add(Vector2i(5, 4), "wall")
	game.capture_blueprint(Vector2i(4, 4), Vector2i(5, 4))
	check(game.blueprint_cost().copper == 3 + roundi(3 * 1.05), "Blueprint quotes include inflation for repeated buildings within the same stamp")
	check(game.stamp_blueprint(Vector2i(4, 8)) and game.buildings[Vector2i(5, 8)].paid_cost.copper == 3, "Blueprints record each inflated paid price for correct demolition refunds")
	fresh()
	game.base_material_capacity = 500
	game.base_copper_capacity = 500
	for resource in game.inventory: game.inventory[resource] = 0
	check(game.add_resource("copper", 700) == 500 and game.inventory.copper == 500, "Resource delivery is limited to the base material cap")
	check(not game.can_receive(game.CORE, "copper"), "Full storage applies back pressure to core conveyor inputs")
	game.inventory.copper = 200
	game.inventory.iron = 100
	game.inventory.scrap = 25
	check(game.place_building(Vector2i(4, 4), "copper_store", 0), "Scrap and normal materials construct a resource silo")
	check(game.material_capacity("copper") == 550 and game.material_capacity("iron") == 500, "Each silo increases only its corresponding resource cap")
	game.add_resource("copper", 5000)
	check(game.inventory.copper == 550, "Silo capacity is enforced after expansion")
	game.remove_building(Vector2i(4, 4))
	check(game.material_capacity("copper") == 500 and game.inventory.copper == 500, "Removing a silo lowers and enforces the remaining capacity")
	fresh()
	game.inventory.scrap = 0
	var cheap: Dictionary = game.create_enemy("scout", game.cell_center(Vector2i(10, 10)), "red")
	var costly: Dictionary = game.create_enemy("bulwark", game.cell_center(Vector2i(15, 10)), "red")
	game._drop_scrap(cheap)
	game._drop_scrap(costly)
	check(game.scraps[0].amount == 1 and game.scraps[1].amount == 48, "Small tank scrap uses its explicit reward and other enemies retain credit-based rewards")
	var origin: Vector2 = game.scraps[0].pos
	game.collect_scrap(2.0, origin + Vector2(90, 0))
	game.collect_scrap(0.01, origin + Vector2(90, 0))
	check(not game.scraps[0].magnetized, "Scrap outside the two-tile mouse radius is not collected")
	game.collect_scrap(0.01, origin + Vector2(50, 0))
	check(game.scraps[0].magnetized and game.scraps[0].pos != origin, "Nearby scrap is animated toward the pointer")
	for i in 20: game.collect_scrap(0.05, origin + Vector2(50, 0))
	check(game.inventory.scrap == 1 and game.scraps.size() == 1, "Magnetized scrap deposits into capped inventory on arrival")
	game.base_material_capacity = 500
	game.base_copper_capacity = 500
	game.inventory.scrap = 500
	var remaining: int = game.scraps[0].amount
	game.collect_scrap(1.0, game.scraps[0].pos)
	check(game.scraps[0].amount == remaining and game.inventory.scrap == 500, "Full scrap storage leaves uncollected salvage on the ground")
	fresh()
	game.hover_cell = Vector2i(4, 4)
	game.select_tool("clear")
	check(game.active_tool == "clear", "Clear-track GUI button activates its own tool")
	game.select_tool("blueprint_select")
	check(game.active_tool == "blueprint_select", "Blueprint keyboard tool remains available without a toolbar button")
	game.select_tool("abolish")
	check(game.active_tool == "abolish", "Demolish GUI button activates the removal brush")
	game.hud.toggle_category("Storage")
	check(game.hud.expanded.visible and game.hud.cards.size() == 5, "Storage category expands upward with all five resource depots")
	game.hud.toggle_category("Storage")
	check(not game.hud.expanded.visible, "Clicking an open category collapses it")
	fresh()
	game.wave_timer = 0.1
	game.simulate(0.05)
	check(game.wave == 0 and game.wave_timer > 0, "Restored countdown does not launch a wave prematurely")
	game.simulate(0.06)
	check(game.wave == 1 and game.wave_active(), "Restored countdown automatically launches the next wave")
	game.enemies.clear()
	game.spawn_remaining = 0
	game.spawn_queue.clear()
	game.simulate(0.01)
	check(game.wave_timer > game.inter_wave_delay - 0.02 and game.wave_timer <= game.inter_wave_delay, "Completing a wave resets the inter-wave countdown")
	fresh()
	var moving_belt := add(Vector2i(4, 4))
	moving_belt.item = "copper"
	add(Vector2i(5, 4))
	var frozen_enemy: Dictionary = game.create_enemy("runner", game.cell_center(Vector2i(40, 22)), "red")
	game.enemies.append(frozen_enemy)
	var enemy_position: Vector2 = frozen_enemy.pos
	var countdown: float = game.wave_timer
	var clock: float = game.elapsed
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_SPACE
	pause_key.pressed = true
	game._unhandled_input(pause_key)
	game.simulate(5.0)
	check(game.paused and moving_belt.travel == 0 and frozen_enemy.pos == enemy_position and game.elapsed == clock, "Space freezes conveyors, enemies and simulation time")
	check(game.wave_timer == countdown, "Pause also freezes the wave countdown")
	check(game.place_building(Vector2i(7, 7), "wall", 0), "Construction remains available while the simulation is paused")
	game.remove_building(Vector2i(7, 7))
	check(not game.buildings.has(Vector2i(7, 7)), "Demolition remains available while paused")
	game.capture_blueprint(Vector2i(4, 4), Vector2i(5, 4))
	check(game.stamp_blueprint(Vector2i(4, 8)), "Blueprint stamping is available while paused")
	game.hud.refresh()
	check(game.hud.pause_button.text == "" and game.hud.pause_button.icon.resource_path.ends_with("play.svg"), "Pause button displays the resume icon")
	game.hud.pause_button.pressed.emit()
	game.hud.refresh()
	check(not game.paused and game.hud.pause_button.text == "" and game.hud.pause_button.icon.resource_path.ends_with("pause.svg"), "Pause GUI button resumes the simulation")
	game.simulate(0.1)
	check(moving_belt.travel > 0, "Conveyor movement resumes after unpausing")
	fresh()
	var waiting_turret := add(Vector2i(5, 4), "turret")
	waiting_turret.ammo = 0
	var loading_belt := add(Vector2i(4, 4))
	loading_belt.item = "copper"
	game._update_items(game.FLOW_INTERVAL + 0.001)
	check(waiting_turret.ammo == 1 and not game.wave_active(), "Conveyors refill turrets between waves")
	fresh()
	var stocked_beacon := add(Vector2i(10, 10), "healer")
	var repair_target := add(Vector2i(11, 10), "wall")
	repair_target.hp = 100.0
	stocked_beacon.buffer.verdite = 1
	stocked_beacon.buffer.alloy = 1
	game._update_healer(Vector2i(10, 10), stocked_beacon, 1.0)
	check(is_equal_approx(repair_target.hp, 105.5) and not game.wave_active(), "A fueled beacon continues its one-percent repair pulse between waves")
	fresh()
	game.launch_wave()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.enemies.clear()
	game.launch_wave()
	check(game.wave == 2 and game.active_spawners[0].waves_completed == 1, "Immediate manual next-wave starts still count the cleared wave for gate progression")
	var immediate_plan: Array = game.spawn_queue.duplicate(true)
	game._prepare_colors(2)
	game._plan_wave()
	check(game.spawn_queue == immediate_plan, "Immediate manual wave starts retain the same wave-number seed and color planning")
	fresh()
	var motion = preload("res://scripts/conveyor_motion.gd")
	check(is_equal_approx(motion.SPEED, 32.0), "Conveyor cargo and markings share the thirty-two-pixel-per-second speed")
	check(is_equal_approx(motion.arrow_phase(0.1), motion.SPEED * 0.1), "Arrow displacement follows cargo speed exactly")
	var loop_time: float = motion.ARROW_SPACING / motion.SPEED
	var initial_lines: Array = motion.arrow_segments(0, 0, 0.123)
	var repeated_lines: Array = motion.arrow_segments(0, 0, 0.123 + loop_time)
	var periodic: bool = initial_lines.size() == repeated_lines.size()
	for i in mini(initial_lines.size(), repeated_lines.size()):
		for point in 2: periodic = periodic and initial_lines[i][point].is_equal_approx(repeated_lines[i][point])
	check(periodic, "Conveyor markings form an exactly repeating loop")
	var clipped := true
	for direction in 4:
		for incoming in 4:
			for frame in 40:
				for line in motion.arrow_segments(direction, incoming, float(frame) / 60):
					for point in line: clipped = clipped and absf(point.x) <= 16.0001 and absf(point.y) <= 16.0001
	check(clipped, "Animated arrows remain clipped inside every straight and corner tile")
	check(motion.path_point(1, 0, 8) == Vector2(-8, 0) and motion.path_point(1, 0, 24) == Vector2(0, 8), "Corner arrows follow the incoming and outgoing belt directions")
	check(is_equal_approx(fposmod(motion.TILE, motion.ARROW_SPACING), 0), "Arrow spacing divides tile length so neighboring belt patterns line up")
	print("SIMULATION CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(0 if failures == 0 else 1)











