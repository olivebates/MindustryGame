extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.audio.muted = true
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.tutorial_enabled = false
	game.rocks.clear()
	game.buildings.clear()
	game.occupied.clear()
	game._add_building(Vector2i(30, 22), "core", 0)
	for x in range(24, 30): game._add_building(Vector2i(x, 22), "belt", 0)
	game.ores[Vector2i(23, 22)] = "copper"
	game._add_building(Vector2i(23, 22), "drill", 0)
	var before: int = game.delivered
	for frame in 2400: game.simulate(1.0 / 60.0)
	check(game.delivered - before >= 1, "One item per ten seconds extractor feeds a slower belt line")
	var delivered: int = game.delivered
	for frame in 600: game.simulate(1.0 / 60.0)
	check(game.delivered - delivered == 1, "Steady state delivers one item in ten seconds")
	var fractional_ranges := false
	for stats in game.Content.ENEMY_TYPES.values(): fractional_ranges = fractional_ranges or fmod(stats.reach, game.TILE) != 0
	for kind in ["solar", "turret", "repeater", "cannon"]: fractional_ranges = fractional_ranges or fmod(game.turret_range(kind), game.TILE) != 0
	check(not fractional_ranges and game.Content.ENEMY_TYPES.scout.reach == 64, "Attack ranges round to full tiles")
	game.selected = "belt"
	game.hover_cell = Vector2i(24, 22)
	game.buildings[game.hover_cell].item = "copper"
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.pressed = true
	game._unhandled_input(key)
	check(game.active_tool == "build" and game.selected == "belt" and game.buildings[game.hover_cell].item == "", "Z clears without changing construction selection")
	check(game.hud.tool_buttons.is_empty(), "Demolition and clearing have no toolbar buttons")
	game.discovered_resources.copper = true
	game.discovered_resources.scrap = true
	game.inventory.copper = 20
	game.inventory.scrap = 0
	game.tutorial.tech_available = true
	game.research("barriers", true)
	game.inventory.copper = 30
	game.hud.show_tech_tree()
	var prices: Dictionary = game.hud.tech_buttons.turret_range.button.get_meta("cost_labels")
	check(prices.copper.get_theme_color("font_color") == Color.WHITE and prices.scrap.get_theme_color("font_color") == game.hud.ERROR_COLOR, "Tech prices independently color affordable copper white and missing scrap red")
	game.inventory.copper = 0
	game.inventory.scrap = 7
	game.hud.refresh()
	check(prices.copper.get_theme_color("font_color") == game.hud.ERROR_COLOR and prices.scrap.get_theme_color("font_color") == Color.WHITE, "Tech price colors update independently as inventory changes")
	game.hud.close_modal()
	game.lost = true
	game.hud.save_browser.show_browser(true)
	var modal = game.hud.modal
	game.hud.close_modal()
	check(is_instance_valid(modal) and not modal.is_queued_for_deletion(), "Death browser cannot be dismissed")
	var cancel_disabled := false
	for child in modal.get_child(0).get_children():
		if child is Button and child.text == "Cancel": cancel_disabled = not child.visible
	check(cancel_disabled, "Death browser hides Cancel")
	game.lost = false
	game.hud.close_modal()
	check(modal.is_queued_for_deletion(), "Normal browser can still be dismissed")
	print("LATEST CHANGE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)



