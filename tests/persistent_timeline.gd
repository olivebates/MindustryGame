extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.saves.directory = "res://.godot/timeline_regression"
	game.saves.entries.clear()
	game.saves.current = -1
	game.wave = 1
	game.saves.capture()
	game.wave = 2
	game.saves.capture()
	game.hud.refresh()
	var browser = game.hud.save_browser
	check(browser.strip.is_visible_in_tree() and not game.hud.saves_button.visible, "Persistent timeline replaces the browse button")
	check(browser.timeline.max_value == 1 and browser.timeline.get_child_count() == 2, "Each save has a marker")
	var live_core: Vector2i = game.current_core
	var live_buildings: Dictionary = game.buildings.duplicate(true)
	var old_position: Vector2 = game.camera.position
	browser.begin_scrub()
	browser.preview_save(0)
	check(game.paused and game.current_core == live_core and game.buildings == live_buildings, "Scrubbing pauses without changing live buildings or core")
	check(game.camera.position == game.cell_center(live_core) and browser.wave_caption.text == "Wave 1", "Scrubbing focuses saved core and displays checkpoint wave")
	browser.finish_scrub()
	check(game.camera.position == old_position and is_instance_valid(game.hud.modal), "Releasing asks for confirmation")
	check(find_text(game.hud.modal, "Are you sure you want to rewind back to wave 1?"), "Rewind confirmation names selected wave")
	game.hud.close_modal()
	browser.confirm_restore(1, true)
	check(find_text(game.hud.modal, "Are you sure you want to restart the current wave?"), "Restart uses distinct confirmation")
	game.hud.close_modal()
	game.lost = true
	game.hud.refresh()
	check(browser.death_title.visible and browser.death_title.text == "You lost your core." and game.hud.tutorial_prompt.text == "Use the arrow button or timeline to roll back time.", "Death shows loss title and timeline instruction")
	check((not is_instance_valid(game.hud.modal) or not game.hud.modal.visible), "Death uses timeline without a blocking save browser")
	game.lost = false
	game._add_building(Vector2i(27, 25), "drill", 0)
	game.ores[Vector2i(27, 25)] = "iron"
	game._add_building(Vector2i(28, 25), "turret", 0)
	var drill: Dictionary = game.buildings[Vector2i(27, 25)]
	drill.item = "iron"
	game.buildings[Vector2i(28, 25)].ammo = 0
	game.update_splitter_route(Vector2i(27, 25), drill)
	check(drill.route_dir == 0, "Extractor routes iron directly to adjacent Slugger")
	drill.travel = 1
	game._move_items()
	check(game.buildings[Vector2i(28, 25)].ammo == 1 and drill.item == "", "Adjacent structure receives extracted ore")
	check(game.tutorial.supply_connected(Vector2i(27, 25), Vector2i(28, 25)), "Direct extractor supply completes ammo lesson")
	var style = game.hud.next_button.get_theme_stylebox("normal")
	check(style.border_width_left == 2 and game.hud.speed_button.icon.get_size() == Vector2(32, 32), "GUI outlines are two pixels and icons have thirty-two-pixel rasters")
	for zoom in game.ZOOM_LEVELS:
		game.set_camera_zoom(zoom)
		check(is_equal_approx(game.tower_outline_width() * game.get_screen_transform().x.length(), 1), "Tower outlines retain one screen pixel at every zoom")
	var layer: TileMapLayer = game.get_node("Level/RockWalls")
	check(layer.tile_set.get_source_count() == 4, "Painted rock layer uses four deterministic variants")
	game.paused = false
	game.selected = ""
	var ore := Vector2i(24, 25)
	game.ores[ore] = "copper"
	game.inventory.copper = 0
	game.speed = 3
	game.update_manual_mining(1.0 / 3.0, ore, true)
	check(game.inventory.copper == 1, "Triple speed mines one copper in a third of a second")
	game.ores[ore] = "iron"
	game.manual_mining_progress = 0
	game.inventory.iron = 0
	game.update_manual_mining(5.0 / 3.0, ore, true)
	check(game.inventory.iron == 1, "Triple speed applies equally to iron mining")
	game.enemies.clear()
	game.shots.clear()
	var enemy: Dictionary = game.create_enemy("scout", game.building_center(Vector2i(28, 25)) + Vector2(50, 0), "red")
	enemy.hp = 100
	enemy.max_hp = 100
	game.enemies.append(enemy)
	var slugger: Dictionary = game.buildings[Vector2i(28, 25)]
	slugger.ammo = 10
	slugger.cooldown = 0
	game._update_turret(Vector2i(28, 25), slugger, 0.05)
	check(game.shots.size() == 1 and game.shots[0].projectile and enemy.hp == 100, "Slugger fires an iron projectile without instant beam damage")
	game.simulate(0.2)
	check(enemy.hp == 50, "Iron projectile applies damage on arrival")
	game._add_building(Vector2i(29, 24), "solar", 0)
	game._update_turret(Vector2i(29, 24), game.buildings[Vector2i(29, 24)], 0.05)
	if game.shots.size() > 1: check(game.shots[-1].color == Color("69cbff") and not game.shots[-1].projectile, "Solar weapon uses a blue beam")
	game.hud.refresh()
	check(game.hud.resource_views.copper.row.position == Vector2(8, 8), "Inventory has eight pixels of top and left padding")
	print("PERSISTENT TIMELINE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
func find_text(node: Node, value: String) -> bool:
	if not is_instance_valid(node): return false
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if find_text(child, value): return true
	return false








