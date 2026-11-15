extends "res://tests/iron_supply_zoom.gd"
class WebGame extends "res://scripts/game.gd":
	func platform_debug_features() -> PackedStringArray: return PackedStringArray(["web"])
func key(code: Key, down := true, shift := true, echo := false) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	event.shift_pressed = shift
	event.echo = echo
	return game.handle_debug_shortcut(event)
func run() -> void:
	fresh()
	game.tutorial.tech_available = true
	game.research("barriers", true)
	game.hud.show_tech_tree()
	var node: Dictionary = game.hud.tech_buttons.solar_health
	var sprite: TextureRect = node.button.get_meta("cost_sprites")[0]
	check(sprite.position == Vector2(8, node.button.size.y - 24), "Unresearched tech price is at the bottom-left corner")
	check(not game.hud.visible_tech_ids().has("containment_engine"), "Late tech is normally hidden")
	key(KEY_Z)
	check(game.debug_tech_reveal and game.hud.tech_buttons.size() == game.TECH.size(), "Holding Shift+Z reveals every tech in the open tree")
	check(game.hud.tech_buttons.containment_engine.button.disabled == false, "Debug mode makes core-gated technologies clickable")
	for resource in game.inventory: game.inventory[resource] = 0
	var inventory: Dictionary = game.inventory.duplicate()
	var chosen := "isotope_lance"
	var chosen_y: float = game.TECH[chosen].pos.y
	var prior: Array[String] = []
	for id in game.TECH:
		if game.TECH[id].pos.y < chosen_y: prior.append(id)
	game.hud.tech_buttons[chosen].button.pressed.emit()
	check(game.researched.has(chosen) and prior.all(func(id): return game.researched.has(id)), "Debug click researches the chosen tech and every previous row")
	check(game.researched.has("reactor") and game.researched.has("refining"), "Debug research unlocks prerequisite technologies")
	check(game.inventory == inventory, "Debug tech research spends no resources")
	check(not game.researched.has("containment_engine"), "Rows beyond the clicked technology remain locked")
	if game.TECH.emergency_injector.pos.y == chosen_y:
		check(not game.researched.has("emergency_injector"), "Unselected technologies on the clicked row remain locked")
	key(KEY_Z, false)
	check(not game.debug_tech_reveal and game.hud.tech_buttons.size() < game.TECH.size(), "Releasing Z restores normal tech visibility")
	node = game.hud.tech_buttons[chosen]
	sprite = node.button.get_meta("cost_sprites")[0]
	var label_width: float = node.state.get_theme_font("font").get_string_size("RESEARCHED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	check(sprite.position.x >= node.state.position.x + label_width + 8 and sprite.position.y == node.state.position.y, "Researched tech price sits beside the researched text")
	check(not sprite.visible, "Researched prices stay hidden without Alt-hover")
	game.hud.tech_list_mode = true
	game.hud._rebuild_tech_nodes()
	node = game.hud.tech_buttons.solar_health
	game.hud.layout_tech_price(node, false, "solar_health")
	sprite = node.button.get_meta("cost_sprites")[0]
	check(sprite.position == Vector2(8, node.button.size.y - 24), "List-view prices also use the bottom-left corner")
	var initial_core: Vector2i = game.current_core
	var initial_count: int = game.cores.size()
	game.enemies.append(game.create_enemy("scout", game.cell_center(initial_core + Vector2i(5, 0)), "red"))
	game.spawn_queue.assign([{"kind":"scout", "pos":Vector2.ZERO, "color":"red"}])
	game.spawn_remaining = 1
	game.pending_waves[1] = [0]
	key(KEY_Z)
	check(key(KEY_M) and game.cores.size() > initial_count and game.current_core != initial_core, "Shift+Z+M finishes the core and captures the next one")
	check(game.enemies.is_empty() and game.spawn_remaining == 0 and game.pending_waves.is_empty() and game.paused, "Core navigation clears combat and pauses safely")
	var count_after: int = game.cores.size()
	key(KEY_M, true, true, true)
	check(game.cores.size() == count_after, "Holding the shortcut does not repeatedly advance cores")
	key(KEY_M, false)
	check(key(KEY_N) and game.current_core == initial_core and game.cores.size() == initial_count, "Shift+Z+N returns to the previous core")
	check(not game.active_spawners.is_empty() and game.active_spawners[0].waves_completed == 0 and not game.active_spawners[0].converted, "Returning reopens the captured gate with fresh waves")
	check(game.camera.position.distance_to(game.clamp_camera_position(game.cell_center(initial_core))) < 1, "Returning focuses the previous core")
	key(KEY_N, false)
	key(KEY_N)
	check(game.current_core == initial_core, "Going back at the first core is a harmless no-op")
	key(KEY_N, false)
	key(KEY_Z, false)
	check(game.inventory == inventory, "Core debug navigation does not grant or spend resources")
	game.free()
	game = load("res://scenes/main.tscn").instantiate()
	game.set_script(WebGame)
	root.add_child(game)
	game.set_process(false)
	key(KEY_Z)
	check(not game.debug_tech_reveal, "Full-tech debug view remains disabled on web builds")
	var web_core: Vector2i = game.current_core
	check(not key(KEY_M) and game.current_core == web_core, "Core navigation debug shortcut remains disabled on web builds")
	print("TECH DEBUG NAVIGATION: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
