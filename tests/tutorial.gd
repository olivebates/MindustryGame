extends SceneTree
class WebGame extends "res://scripts/game.gd":
	func platform_debug_features() -> PackedStringArray:
		return PackedStringArray(["web", "wasm32"])
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
func fresh(web: bool = false) -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	if web: game.set_script(WebGame)
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
func shift_p() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.shift_pressed = true
	key.pressed = true
	return key
func run() -> void:
	fresh()
	var sector: Node2D = game.get_node("Level")
	var rocks: TileMapLayer = sector.get_node("RockWalls")
	var ores: TileMapLayer = sector.get_node("OreDeposits")
	var ground: TileMapLayer = sector.get_node("Ground")
	check(ground.get_used_cells().size() == game.WIDTH * game.HEIGHT and not rocks.get_used_cells().is_empty() and not ores.get_used_cells().is_empty(), "Level contains saved, paintable ground, rock-wall and ore TileMapLayers")
	check(game.rocks.size() == rocks.get_used_cells().size() and game.ores.size() == ores.get_used_cells().size(), "Runtime obstacles and resources are read from painted cells")
	check(ores.tile_set.get_source_count() == 3 and ores.get_cell_tile_data(Vector2i(20, 22)).get_custom_data("resource") == "copper", "Ore atlas exposes copper, iron and verdite with resource metadata")
	check(ores.tile_set.get_source(0).texture.get_size() == Vector2(32, 32), "Painted tile textures match the 32-pixel world grid")
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://scenes/sector.tscn")
	game.simulate(100)
	check(FileAccess.get_file_as_bytes("res://scenes/sector.tscn") == saved_bytes and game.rocks.size() == rocks.get_used_cells().size(), "Playing does not regenerate or overwrite the authored level")
	var painted_cell := Vector2i(21, 19)
	ores.set_cell(painted_cell, 1, Vector2i.ZERO)
	game._load_level()
	check(game.ores[painted_cell] == "iron", "Newly painted ore is interpreted as the selected mineral")
	var packed := PackedScene.new()
	packed.pack(sector)
	check(ResourceSaver.save(packed, "res://.godot/painted-sector-check.tscn") == OK, "Painted level can be saved as a normal Godot scene")
	var reloaded = ResourceLoader.load("res://.godot/painted-sector-check.tscn", "", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	check(reloaded.get_node("OreDeposits").get_cell_source_id(painted_cell) == 1, "Painted cells survive saving and loading")
	reloaded.free()
	fresh()
	var progress = game.tutorial
	check(game.inventory.copper == 0 and game.inventory.iron == 0 and game.buildings.size() == 1 and game.buildings[game.current_core].kind == "core", "Tutorial starts with an empty inventory and only a core")
	check(game.hud.tutorial_prompt.visible and game.hud.tutorial_prompt.text == "Press and hold on an ore deposit.", "Initial screen shows the requested mining prompt")
	check(not game.hud.palette.visible and not game.hud.inventory_panel.visible and not game.hud.map_panel.visible and not game.hud.wave_controls.visible and not game.hud.wave_label.visible, "All normal GUI is hidden before the first resource")
	check(not game.unlocked("belt") and not game.unlocked("drill") and not game.unlocked("solar"), "Tutorial gates construction until its corresponding step")
	game.simulate(500)
	check(game.wave == 0 and game.wave_timer == game.initial_wave_delay, "Wave timer never starts during the initial tutorial")
	check(not game.is_cell_visible(Vector2i(59, 21)), "The enemy-spawn corridor remains fogged during onboarding")
	game.update_manual_mining(1, Vector2i(18, 22), true)
	game.hud.refresh()
	check(progress.stage == progress.Stage.FUNDS and game.hud.inventory_panel.visible, "First extracted resource reveals the left inventory")
	check(game.hud.resource_views.copper.row.visible and not game.hud.resource_views.iron.row.visible and not game.hud.resource_views.verdite.row.visible, "Only minerals the player has owned appear in the inventory")
	game.pay({"copper": 1})
	game.hud.refresh()
	check(game.hud.resource_views.copper.row.visible and game.inventory.copper == 0, "Discovered mineral rows remain visible when their amount returns to zero")
	game.update_manual_mining(5, Vector2i(18, 22), true)
	game.hud.refresh()
	check(progress.stage == progress.Stage.EXTRACTOR and game.unlocked("drill") and not game.unlocked("belt"), "Five copper unlocks only the extractor step")
	check(game.hud.palette.visible and game.hud.category_buttons.Structures.visible, "Five copper reveals the Structures menu")
	var retained := true
	for group in ["Logistics", "Extraction", "Defense", "Production", "Support", "Storage"]:
		retained = retained and game.hud.category_buttons.has(group) and not game.hud.category_buttons[group].visible
	check(retained, "Original category buttons are retained but hidden behind the Structures menu")
	check(game.hud.category_buttons.Structures.get_meta("tutorial_glow"), "Structures glows until clicked")
	game.hud.toggle_category("Structures")
	check(not game.hud.category_buttons.Structures.get_meta("tutorial_glow") and game.hud.cards.size() == 1 and game.hud.cards.has("drill"), "Opening Structures clears its glow and shows only the extractor")
	check(game.hud.cards.drill.get_meta("tutorial_glow"), "Extractor card glows until selected")
	game.hud.cards.drill.pressed.emit()
	check(game.selected == "drill" and not game.hud.cards.drill.get_meta("tutorial_glow") and progress.extractors_ever_built == 0, "Selecting the extractor stops the card glow and enables ore guidance")
	check(game.place_building(Vector2i(20, 22), "drill", 0), "The first extractor can be built with the mined minerals")
	check(progress.stage == progress.Stage.BELTS and game.unlocked("belt") and not game.unlocked("solar"), "Building an extractor unlocks belts, not the turret")
	check(game.buildings[Vector2i(20, 22)].dir == 0 and progress.extractors_ever_built == 1, "First extractor has a fixed orientation")
	game.hud.refresh()
	check(not game.hud.category_buttons.Structures.get_meta("tutorial_glow"), "Belt guidance waits for enough copper to complete the route")
	game.cancel_build_selection()
	game.update_manual_mining(5, Vector2i(18, 22), true)
	game.hud.toggle_category("Structures")
	check(game.hud.cards.belt.get_meta("tutorial_glow") and game.hud.cards.size() == 2, "Belt card glows while both starter production buildings remain available")
	game.hud.cards.belt.pressed.emit()
	progress.refresh_guide()
	check(not progress.guide_path.is_empty() and progress.guide_path[0] == Vector2i(21, 22) and progress.guide_path[-1] == game.current_core, "Belt guidance starts at the extractor output and reaches the core")
	check(progress.guide_path.size() == 3, "Unobstructed conveyor guidance takes the shortest route")
	game.ores[Vector2i(22, 22)] = "iron"
	var avoiding: Array = progress.find_guide_path(Vector2i(21, 22), game.current_core)
	check(not avoiding.has(Vector2i(22, 22)) and avoiding.size() == 5, "Conveyor guidance detours around avoidable ore deposits")
	game.ores.erase(Vector2i(22, 22))
	game.rocks[Vector2i(22, 22)] = true
	check(not progress.find_guide_path(Vector2i(21, 22), game.current_core).has(Vector2i(22, 22)), "Conveyor guidance avoids rock walls")
	game.rocks.erase(Vector2i(22, 22))
	game.begin_drag(Vector2i(21, 22))
	game.extend_drag(game.current_core)
	game.finish_drag()
	progress.check_connection()
	check(progress.has_extractor_connection() and progress.stage == progress.Stage.SOLAR, "A correctly directed extractor-to-core line unlocks the solar turret")
	check(game.unlocked("solar") and game.hud.category_buttons.Structures.get_meta("tutorial_glow"), "Solar unlock restarts the Structures glow")
	game.update_manual_mining(10, Vector2i(18, 22), true)
	game.hud.toggle_category("Structures")
	check(game.hud.cards.size() == 3 and game.hud.cards.has("solar") and game.hud.cards.solar.get_meta("tutorial_glow"), "Structures contains exactly Belt, Extractor and Solar turret after onboarding unlocks")
	game.hud.cards.solar.pressed.emit()
	check(game.selected == "solar" and not game.hud.cards.solar.get_meta("tutorial_glow"), "Selecting Solar stops its button glow")
	var target: Vector2i = game.current_core + Vector2i(8, 0)
	check(game.valid_site(target, "solar") and progress.stage == progress.Stage.SOLAR, "The suggested turret tile is eight tiles right of the core and buildable")
	check(game.place_building(target, "solar", 0, "red"), "Solar turret can be placed at the tutorial target")
	game.hud.refresh()
	game.select_tool("abolish")
	game.cancel_build_selection()
	check(progress.stage == progress.Stage.READY and game.hud.wave_controls.visible and game.hud.map_panel.visible, "Completing the demolition lesson reveals the first-wave controls")
	check(game.is_cell_visible(Vector2i(59, 21)), "First turret lifts fog along the enemy-spawn corridor")
	var tools_hidden := true
	for tool in game.hud.tool_buttons.values(): tools_hidden = tools_hidden and not tool.visible
	check(tools_hidden, "Utility tools remain hidden until the first wave is called")
	check(game.hud.next_button.size.y == 72 and game.hud.speed_button.size.y == 72 and game.hud.pause_button.size.y == 72, "Wave controls match the bottom toolbar button height")
	check(game.hud.wave_label.get_theme_font_size("font_size") == 34 and game.hud.wave_label.get_theme_color("font_color") == game.hud.INK and game.hud.wave_label.text == "01:05", "Wave countdown is large off-white time-only text")
	check(game.hud.wave_label.position.y >= game.hud.minimap.size.y, "Countdown sits immediately below the minimap")
	game.simulate(300)
	check(game.wave == 0 and game.wave_timer == game.initial_wave_delay and not progress.waves_started, "Completing onboarding does not arm the timer before the first wave button")
	var q := InputEventKey.new()
	q.keycode = KEY_E
	q.pressed = true
	game._unhandled_input(q)
	check(game.speed == 3, "Q changes x1 directly to x3")
	game._unhandled_input(q)
	check(game.speed == 1, "Q changes x3 directly back to x1")
	game.hud.next_button.pressed.emit()
	game.advance_wave_warp(2.0)
	game.hud.refresh()
	check(game.wave == 1 and progress.waves_started, "Start first wave arms the wave sequence")
	var tools_visible := true
	for tool in game.hud.tool_buttons.values(): tools_visible = tools_visible and tool.visible and tool.text == "" and tool.get_child_count() == 1
	check(tools_visible, "First wave reveals Clear track, Blueprint and Demolish as icon-only buttons")
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.wave = 3
	game._complete_wave()
	game.hud.refresh()
	check(not progress.tech_available and not game.hud.tech_button.visible, "Research remains hidden before wave four has cleared")
	game.wave = 4
	game._complete_wave()
	progress.paused_once = true
	progress.on_scrap_collected(27)
	game.hud.refresh()
	check(progress.tech_available and game.hud.tech_button.visible and game.hud.tech_button.get_meta("tutorial_glow"), "Tutorial scrap collection reveals a glowing tech-tree button")
	game.hud.show_tech_tree()
	check(progress.tech_opened and not game.hud.tech_button.get_meta("tutorial_glow"), "Opening research stops the tech-tree button glow")
	check(game.hud.tech_buttons.size() == 1 and game.hud.tech_buttons.has("barriers") and game.TECH.barriers.cost == {"scrap": 3, "copper": 20}, "First research frontier contains Barriers for three scrap and twenty copper")
	check(game.hud.tech_buttons.barriers.button.get_meta("tutorial_glow"), "Barriers glows until researched")
	game.add_resource("scrap", 3)
	game.add_resource("copper", 20)
	game.hud.refresh()
	var before: int = game.inventory.scrap
	game.hud.tech_buttons.barriers.button.pressed.emit()
	check(game.researched.has("barriers") and game.inventory.scrap == before - 3 and game.unlocked("wall"), "Barriers research charges three scrap and unlocks walls")
	check(not game.hud.tech_buttons.barriers.button.get_meta("tutorial_glow"), "Researching Barriers ends its glow")
	check(game.hud.tech_buttons.has("conveyor_speed") and game.hud.tech_buttons.has("turret_range") and not game.hud.tech_buttons.has("repeater") and not game.hud.tech_buttons.has("cannon"), "Tech tree reveals immediate successors and hides deeper upgrades")
	game.hud.close_modal()
	fresh()
	game.ores[Vector2i(23, 27)] = "iron"
	game.ores[Vector2i(23, 26)] = "iron"
	game.update_manual_mining(5, Vector2i(23, 27), true)
	check(game.tutorial.stage == game.tutorial.Stage.FUNDS and not game.unlocked("drill"), "Iron does not bypass the five-copper tutorial threshold")
	game.add_resource("copper", 10)
	game.pay({"copper": 10})
	game.tutorial.extractors_ever_built = 1
	game.hud.toggle_category("Structures")
	check(game.hud.card_views.drill.amounts.has("iron") and not game.hud.card_views.drill.amounts.has("copper"), "Alternative extractor recipe is shown with the correct mineral icon and price")
	check(game.place_building(Vector2i(23, 26), "drill", 0) and game.inventory.iron == 0 and game.buildings[Vector2i(23, 26)].dir == 0, "An iron-funded extractor is paid correctly without rotation")
	fresh()
	game._input(shift_p())
	check(game.debug_unlock_step == 1 and game.tutorial.stage == game.tutorial.Stage.READY and game.tutorial.skipped, "First desktop Shift+P skips every tutorial stage")
	var three_only := true
	for kind in game.BUILDINGS:
		three_only = three_only and game.unlocked(kind) == (kind in ["belt", "drill", "solar"])
	check(three_only and game.researched == {"solar_red": true}, "First debug press unlocks exactly the three starter designs and their initial red solar color")
	check(game.inventory.copper == 0 and game.inventory.iron == 0 and not game.tutorial.waves_started, "Debug skip grants no free resources and does not start the wave clock")
	var maximum: float = game.buildings[game.current_core].max_hp
	game._input(shift_p())
	check(game.debug_unlock_step == 2 and game.researched.size() == game.TECH.size() and game.tutorial.tech_available, "Second desktop Shift+P unlocks every technology")
	check(is_equal_approx(game.buildings[game.current_core].max_hp, maximum * 1.25), "Debug unlock applies upgrade effects to existing buildings")
	game._input(shift_p())
	check(is_equal_approx(game.buildings[game.current_core].max_hp, maximum * 1.25), "Repeated debug unlocks never stack a purchased upgrade again")
	check(game.within_build_radius(game.current_core + Vector2i(20, 0)) and not game.within_build_radius(game.current_core + Vector2i(21, 0)), "Construction radius is exactly twenty tiles from a core")
	check(game.within_build_radius(game.current_core + Vector2i(14, 14)) and not game.within_build_radius(game.current_core + Vector2i(15, 15)), "Build radius uses a circle rather than a square")
	check(game.is_cell_visible(game.current_core + Vector2i(21, 0)) and not game.valid_site(game.current_core + Vector2i(21, 0), "solar"), "Revealed enemy corridors do not bypass the core construction radius")
	check(not game.valid_site(game.current_core + Vector2i(19, 0), "forge"), "Every tile in a large building's footprint must fit inside the radius")
	var second_core := Vector2i(60, 40)
	game._add_building(second_core, "core", 0)
	game.cores.append(second_core)
	game.rocks.erase(second_core + Vector2i(19, 0))
	game._reveal_map()
	check(game.valid_site(second_core + Vector2i(19, 0), "solar"), "Additional cores extend the player's construction area")
	fresh()
	game.tutorial.skip_to_ready()
	game._add_building(game.current_core + Vector2i(8, 0), "solar", 0)
	var solar: Dictionary = game.buildings[game.current_core + Vector2i(8, 0)]
	var opponent: Dictionary = game.create_enemy("scout", game.cell_center(game.current_core + Vector2i(10, 0)), "red")
	opponent.hp = 100.0
	opponent.max_hp = 100.0
	game.enemies.append(opponent)
	game._update_turret(game.current_core + Vector2i(8, 0), solar, 0)
	check(solar.ammo == 0 and opponent.hp == 97.0 and game.BUILDINGS.solar.reload == 0.6, "Solar turret shoots for three damage with no ammunition and a 0.6-second cooldown")
	game._update_turret(game.current_core + Vector2i(8, 0), solar, 0.59)
	check(opponent.hp == 97.0, "Solar turret cannot fire early")
	game._update_turret(game.current_core + Vector2i(8, 0), solar, 0.011)
	check(opponent.hp == 94.0 and solar.ammo == 0, "Solar turret fires again without consuming resources")
	check(not game.can_receive(game.current_core + Vector2i(8, 0), "copper") and not game.can_receive(game.current_core + Vector2i(8, 0), "iron"), "Solar turret never accepts ammunition from a conveyor")
	fresh(true)
	game._input(shift_p())
	game._unhandled_input(shift_p())
	check(game.debug_unlock_step == 0 and game.tutorial.stage == game.tutorial.Stage.MINE and game.researched == {"solar_red": true}, "Web-platform input ignores Shift+P in both input handlers")
	check(not game.debug_features_allowed(PackedStringArray(["HTML5"])) and not game.debug_features_allowed(PackedStringArray(["wasm64"])), "Legacy HTML5 and WebAssembly feature tags also disable debug shortcuts")
	print("TUTORIAL AND EDITOR CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(0 if failures == 0 else 1)








