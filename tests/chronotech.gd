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
func fresh() -> void:
	if is_instance_valid(game): game.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
func run() -> void:
	fresh()
	game.add_resource("copper", 5)
	game.hud.toggle_category("Structures")
	game.hud.cards.drill.pressed.emit()
	game.place_building(Vector2i(20, 22), "drill", 0)
	check(game.selected == "drill", "First extractor remains selected after being placed")
	check(not game.tutorial.menu_should_glow() and not game.tutorial.building_should_glow("belt"), "Belt and Structures glows wait for the full path cost")
	game.add_resource("copper", 1)
	check(not game.tutorial.menu_should_glow(), "One copper cannot enable the two-belt guidance glow")
	game.add_resource("copper", 1)
	check(game.tutorial.menu_should_glow() and game.tutorial.building_should_glow("belt"), "Both guidance buttons glow when the path becomes affordable")
	game.select_building("belt")
	game.place_building(Vector2i(21, 22), "belt", 0)
	game.place_building(Vector2i(22, 22), "belt", 0)
	check(game.tutorial.stage == game.tutorial.Stage.BELTS and game.tutorial.central_message() == "Mine some more ore.", "Copper extraction wait is hidden before selecting Solar")
	game.select_building("solar")
	check(not game.unlocked("solar") and game.tutorial.central_message() == "Mine some more ore.", "Selecting unaffordable Solar enables its copper wait prompt")
	game.add_resource("copper", 10)
	game.place_building(Vector2i(31, 22), "solar", 0)
	game.select_tool("abolish")
	game.cancel_build_selection()
	game.hud.minimap.update_bounds()
	check(game.hud.minimap.bounds.size.x <= game.WIDTH and game.hud.minimap.map_scale > 0, "Minimap fits its revealed bounds")
	check(not game.hud.tool_buttons.has("blueprint_select"), "Blueprint button has been removed from the toolbar")
	game.hud.toggle_category("Structures")
	var child_icon: TextureRect
	for child in game.hud.cards.belt.get_children():
		if child is TextureRect:
			child_icon = child
			break
	check(child_icon.position == Vector2(8, 8), "Structure cards have eight-pixel inner padding")
	game.cancel_build_selection()
	check(game.hud.category == "" and not game.hud.expanded.visible, "Deselecting closes the open structure tray")
	game.tutorial.paused_once = true
	var scrap_pos: Vector2 = game.cell_center(game.current_core)
	game.scraps.append({"pos": scrap_pos, "amount": 27, "magnetized": false})
	check(game.tutorial.central_message() == "", "Scrap tutorial waits for the first completed wave")
	game.tutorial.on_wave_completed(1)
	game.paused = true
	game.tutorial.paused_once = true
	check(game.tutorial.central_message() == "Mouse over the scraps to collect.", "Completed first wave enables the post-pause scrap prompt")
	game.scraps.clear()
	check(game.tutorial.central_message() == "", "Scrap instruction hides when no scrap is on the ground")
	game.tutorial.barrier_tree_closed = true
	game.tutorial.info_hover_time = 2.0
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.wave = 5
	game.paused = true
	check(game.tutorial.central_message() != "Press E to speed up time.", "Speed reminder waits while wave five is paused")
	game.paused = false
	check(game.tutorial.central_message() == "Press E to speed up time.", "Unpaused wave five prompts the speed shortcut")
	game.cycle_speed()
	check(game.tutorial.central_message() != "Press E to speed up time.", "Toggling speed permanently dismisses the reminder")
	game.hud.refresh()
	check(game.hud.speed_button.icon.get_meta("source_path", "").ends_with("speed3.svg") and game.hud.speed_button.get_theme_stylebox("normal").bg_color.a > 0, "Triple speed keeps the double-arrow icon and has a colored active background")
	game.cycle_speed()
	check(game.hud.speed_button.icon.get_meta("source_path", "").ends_with("speed3.svg"), "Normal speed retains the same double-arrow icon")
	check(game.Content.ENEMY_TYPES.scout.hp == 36.0, "Small tanks have triple their previous base health")
	game.wave = 4
	check(game.create_enemy("scout", Vector2.ZERO, "red").max_hp == 4.0, "Small tank health growth is tripled as well")
	game.wave = 2
	# Input geometry, extractor priority and the second-belt reversal.
	game.rocks.clear()
	game._add_building(Vector2i(24, 24), "drill", 0)
	game._add_building(Vector2i(25, 24), "belt", 1)
	game.refresh_belt_inputs()
	check(game.buildings[Vector2i(25, 24)].input_dir == 0, "A neighboring extractor supplies the input when there are no incoming belts")
	game._add_building(Vector2i(25, 23), "belt", 1)
	game.refresh_belt_inputs()
	check(game.buildings[Vector2i(25, 24)].input_dir == 1, "An actual belt input takes priority over an adjacent extractor")
	game._add_building(Vector2i(26, 24), "belt", 2)
	game.refresh_belt_inputs()
	check(game.buildings[Vector2i(25, 24)].input_dir == game.buildings[Vector2i(25, 24)].dir, "Multiple incoming belts use a straight sprite")
	game.remove_building(Vector2i(25, 23), false)
	game.remove_building(Vector2i(26, 24), false)
	check(game.buildings[Vector2i(25, 24)].input_dir == 0, "Removing belt inputs restores extractor input automatically")
	game.inventory.copper = 40
	game._add_building(Vector2i(28, 25), "belt", 1)
	game.select_building("belt")
	game.build_direction = 0
	game.begin_drag(Vector2i(27, 25))
	game.extend_drag(Vector2i(27, 26))
	game.finish_drag()
	check(game.buildings[Vector2i(28, 25)].dir == 1 and game.buildings[Vector2i(27, 25)].dir == 1, "Second belt preserves the older receiver while turning the new belt")
	# Unaffordable tech clicks are actionable feedback rather than disabled controls.
	game.tutorial.tech_available = true
	game.inventory.scrap = 0
	game.hud.show_tech_tree()
	check(not game.hud.tech_buttons.barriers.button.disabled, "Unaffordable unlockable technology remains clickable")
	game.hud.tech_buttons.barriers.button.pressed.emit()
	var shortage := false
	for caption in game.hud.feedback_labels: shortage = shortage or caption.text == "Not enough resources..."
	check(shortage and not game.researched.has("barriers"), "Unaffordable tech shows floating red Not enough resources text")
	game.hud.close_modal()
	await process_frame
	# Colored icon stats, a quick fade and demolition refund preview.
	game._add_building(Vector2i(27, 21), "turret", 0)
	var tower: Dictionary = game.buildings[Vector2i(27, 21)]
	tower.hp = 100
	tower.ammo = 0
	tower.paid_cost = {"copper": 35, "iron": 12}
	game.hover_cell = Vector2i(27, 21)
	game.active_tool = "abolish"
	game.hud.show_structure_info("turret", tower, Vector2(700, 400))
	check(game.hud.tooltip_body.text.contains("[img=14x14]") and game.hud.tooltip_body.text.contains("[color=#ff716c]Health:") and game.hud.tooltip_body.text.contains("[color=#ff716c]Ammo:"), "Damaged health and empty ammunition get colored icon stats")
	check(game.hud.tooltip_body.get_parsed_text().contains("Refund:") and game.hud.tooltip_body.get_parsed_text().contains("3"), "Demolition preview includes the material refund")
	check(game.hud.tooltip.modulate.a < 1, "Info popup begins a short fade-in")
	await create_timer(0.25).timeout
	check(is_equal_approx(game.hud.tooltip.modulate.a, 1.0), "Info popup fade completes quickly")
	game._add_building(Vector2i(29, 24), "belt", 0)
	var blocked: Dictionary = game.buildings[Vector2i(29, 24)]
	blocked.item = "copper"
	game.hover_cell = Vector2i(29, 24)
	game.hud.show_structure_info("belt", blocked, Vector2(700, 400))
	check(game.hud.tooltip_body.text.contains("[color=#ff716c]Status: Output blocked"), "Blocked material outputs get a colored warning")
	game.paused = true
	game.remove_building(Vector2i(27, 21))
	check(game.demolitions.size() == 1 and not game.buildings.has(Vector2i(27, 21)), "Demolition starts a short collapsing sprite and debris effect")
	game.update_demolition_effects(0.31)
	check(game.demolitions.is_empty(), "Demolition animations finish while the simulation is paused")
	check(is_equal_approx(game.audio.streams.demolish.get_length(), 0.12), "Dismantling uses the crisp regenerated sound")
	# Disk previews, stable rows, elapsed time and a right-to-left timeline.
	game.wave = 1
	game.saves.capture()
	game.wave = 2
	game.saves.capture()
	check(FileAccess.file_exists(game.saves.preview_path(game.saves.entries[0].file)), "Checkpoints include an image preview file")
	var browser = game.hud.save_browser
	check(browser.age_text(0) == "Just now" and browser.age_text(60) == "1m ago" and browser.age_text(3600) == "1h ago" and browser.age_text(3661) == "1h 1m ago", "Save ages omit seconds and zero hours or minutes")
	var recorded: Array = game.saves.load_snapshot(0)
	var old_core: Vector2i = game.current_core
	game.current_core += Vector2i(15, 0)
	var drawing: Node2D = load("res://scripts/save_preview.gd").new()
	drawing.configure(game, recorded)
	check(drawing.core == old_core and drawing.tiles.has(old_core), "Legacy thumbnails use the saved core and revealed area rather than the live camera")
	drawing.free()
	game.current_core = old_core
	DirAccess.remove_absolute(game.saves.preview_path(game.saves.entries[0].file))
	browser.show_browser()
	await process_frame
	check(browser.timeline.value == browser.timeline.max_value, "Timeline starts at the latest checkpoint")
	browser.begin_scrub()
	browser.preview_save(0)
	check(browser.selected == 0 and browser.wave_caption.text == "Wave 1", "Scrubbing left previews older history with its wave label")
	browser.finish_scrub()
	game.hud.close_modal()
	browser.confirm_restore(0)
	var words: Array[String] = []
	for node in game.hud.modal.get_child(0).get_children():
		if node is Label: words.append(node.text)
	check(words.has("Return to wave start") and words.has("Are you sure you want to rewind back to wave 1?"), "Rollback confirmation uses the requested title and question")
	game.hud.close_modal()
	await process_frame
	game.paused = false
	game._damage_building(game.current_core, 10000)
	game.hud.refresh()
	check(game.lost and browser.death_title.visible and game.hud.tutorial_prompt.text == "Use the timeline at the bottom to roll back time.", "Death directs the player to the persistent timeline")
	game.hud.close_modal()
	await process_frame
	var future_preview: String = game.saves.preview_path(game.saves.entries[1].file)
	check(game.saves.restore(0) and not game.lost and game.paused, "Death can be reversed by loading a checkpoint, immediately paused")
	game.hud.close_modal()
	game.toggle_pause()
	check(not FileAccess.file_exists(future_preview), "Committing a rollback also deletes previews for discarded future saves")
	for entry in game.saves.entries:
		DirAccess.remove_absolute(game.saves.directory.path_join(entry.file))
		DirAccess.remove_absolute(game.saves.preview_path(entry.file))
	DirAccess.remove_absolute(game.saves.directory)
	fresh()
	game.hud.minimap.update_bounds()
	check(game.hud.minimap.bounds.size.x <= 41 and game.hud.minimap.bounds.size.y <= 41, "Initial minimap zooms into the revealed core circle")
	game._damage_building(game.current_core, 10000)
	check(game.lost and game.hud.save_browser.strip.visible and game.saves.entries.size() > 0, "Death before the first checkpoint still offers the initial timeline checkpoint")
	game.free()
	print("CHRONOTECH AND FEEDBACK CHECKS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)












