extends SceneTree
var passed := 0
var failed := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.onboarding_completed = true
	game.tutorial.waves_started = true
	game._reveal_map()
	check(game.building_cost("solar", 0).copper == 10 and game.building_cost("solar", 1).copper == 13 and game.building_cost("solar", 2).copper == 16, "Tower prices compound by twenty-five percent per owned tower")
	var store: Vector2i = game.current_core + Vector2i(0, 3)
	game._add_building(store, "copper_store", 0)
	game.buildings[store].paid_cost = {"scrap": 17, "copper": 20}
	check(game.demolition_refund(store) == {"scrap": 17, "copper": 2}, "Demolition refunds all paid scrap and ten percent of other materials")
	game.remove_building(store)
	check(game.inventory.scrap == 17, "Demolition actually deposits the full scrap refund")
	game._add_building(game.current_core + Vector2i(1, 0), "drill", 0)
	game._add_building(game.current_core + Vector2i(2, 0), "belt", 0)
	game._add_building(game.current_core + Vector2i(3, 0), "wall", 0)
	game._add_building(game.current_core + Vector2i(4, 0), "solar", 0)
	game._add_building(game.current_core + Vector2i(5, 0), "solar", 0)
	game._add_building(game.current_core + Vector2i(0, 5), "forge", 0)
	var gate = game.active_spawners[0]
	gate.credits_per_wave = PackedInt32Array([9, 9, 9])
	gate.wave_enemy_lists.assign([PackedStringArray(["heavy", "scout"]), PackedStringArray(["heavy", "scout"]), PackedStringArray(["heavy", "scout"])])
	game.wave = 1
	game.hud.refresh()
	game.saves.capture()
	game.wave = 2
	game.saves.capture()
	var summary: Dictionary = game.saves.summary_from_snapshot(game.saves.load_snapshot(0))
	check(summary.buildings == 3 and summary.turrets == 2, "Checkpoint counts exclude belts and barriers and separate turrets")
	check(summary.enemies == {"heavy": 1, "scout": 1} and summary.techs == game.researched.size(), "Checkpoint counts include researched tech and the seeded next-wave roster")
	game.tutorial.first_wave_completed = true
	game.tutorial.tech_available = true
	game.research("barriers", true)
	game.hud.refresh()
	check(game.hud.category_buttons.Infrastructure.visible and game.hud.pause_button.visible and game.hud.tech_button.visible, "Later progress reveals split categories, pause and tech controls")
	check(game.saves.restore(0) and game.wave == 1 and game.researched.has("barriers"), "Rollback restores gameplay research to wave one")
	check(game.hud.category_buttons.Infrastructure.visible and game.hud.category_buttons.Defence.visible and not game.hud.category_buttons.Structures.visible, "Rollback keeps the structure categories split")
	check(game.hud.pause_button.visible and game.hud.tech_button.visible and game.hud.wave_controls.visible, "Rollback keeps previously revealed controls visible")
	check(game.saves.restore(1) and game.wave == 2 and game.hud.tech_button.visible and game.hud.category_buttons.Defence.visible, "Wave-two rollback also preserves revealed UI")
	game.hud.save_browser.show_browser()
	var row: Button = game.hud.save_browser.rows[0]
	var stat_labels := 0
	for child in row.get_children():
		if child is Label and child.text.begins_with("x"): stat_labels += 1
	check(stat_labels == 5 and row.get_meta("summary").enemies.heavy == 1, "Save rows show icon-times-count groups for structures, turrets, tech and enemy types")
	game.hud.close_modal()
	await process_frame
	var rng_before: int = game.wave_rng.state
	var forecast: Dictionary = game.next_wave_forecast()
	check(forecast.by_spawn[0].counts == {"heavy": 1, "scout": 1} and game.wave_rng.state == rng_before, "Forecasting is seeded and does not advance gameplay RNG")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.hover_cell = Vector2i((gate.position / game.TILE).floor())
	game.hud._refresh_tooltip(game.get_canvas_transform() * gate.position)
	check(game.hud.tooltip.visible and game.hud.tooltip_title.text.contains("Wave 3") and game.hud.tooltip_body.get_parsed_text().contains("Enemies: 2"), "Alt hovering a spawn shows the next wave's statistics")
	alt.pressed = false
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	game.paused = false
	key(KEY_E)
	check(game.speed == 3 and game.hud.speed_button.get_node("Hotkey").text == "E", "E controls speed and matches the button hint")
	key(KEY_Q)
	game.advance_wave_warp(2.0)
	check(game.wave == 3 and game.spawn_remaining == 2 and game.hud.next_button.get_node("Hotkey").text == "Q", "Q starts the forecast wave and matches the button hint")
	game.enemies.clear()
	game.buildings.clear()
	game.occupied.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.current_core = Vector2i(20, 20)
	game._add_building(game.current_core, "core", 0)
	game._add_building(Vector2i(22, 20), "wall", 0)
	var enemy: Dictionary = game.create_enemy("heavy", game.cell_center(Vector2i(23, 20)), "red")
	enemy.cooldown = 0.0
	enemy.windup = 0.0
	enemy.aim = 0.0
	game.enemies.append(enemy)
	check(not game.enemy_has_line_of_sight(enemy.pos, game.current_core) and game.enemy_has_line_of_sight(enemy.pos, Vector2i(22, 20)), "A barrier blocks shots beyond itself while remaining shootable")
	game._update_enemies(0.02)
	check(game.buildings[game.current_core].hp == game.buildings[game.current_core].max_hp and game.buildings[Vector2i(22, 20)].hp < game.buildings[Vector2i(22, 20)].max_hp, "Enemy fire damages the blocking barrier rather than passing through")
	check(absf(enemy.aim) > 0.01 and absf(enemy.aim) < PI - 0.01 and not is_equal_approx(enemy.aim, enemy.angle), "Enemy cannon aim lerps independently of hull rotation")
	check(game.Content.ENEMY_TYPES.heavy.reach == game.TILE * 4 and game.textures.has("heavy_gun") and game.textures.has("heavy_body"), "Heavy range is four tiles and hull/gun sprites are separate")
	game.remove_building(Vector2i(22, 20), false)
	check(game.enemy_has_line_of_sight(enemy.pos, game.current_core), "Destroying the barrier immediately opens the firing line")
	print("COMBAT CHECKPOINT UI CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

