extends "res://tests/iron_supply_zoom.gd"
func settle() -> void:
	for frame in 4: await process_frame
func run() -> void:
	fresh()
	game.tutorial.skip_to_ready()
	game.tutorial.tech_available = true
	game.research("barriers", true)
	game.research("solar_speed", true)
	game.hud.tech_list_mode = true
	game.hud.show_tech_tree()
	await settle()
	var hud = game.hud
	check(game.paused and hud.tech_mode_button.text == "List view", "Research opens paused with a button to switch to the list")
	var rows := {}
	var parents_above := true
	for id in hud.tech_buttons:
		var row: float = hud.tech_buttons[id].button.position.y
		rows[row] = rows.get(row, 0) + 1
		var parent: String = game.TECH[id].parent
		if hud.tech_buttons.has(parent) and hud.tech_buttons[parent].button.position.y >= hud.tech_buttons[id].button.position.y: parents_above = false
	check(rows.values().max() == 4 and parents_above, "First opening defaults to tree view with four columns and prerequisites above their children")
	check(game.TECH.values().all(func(data): return not str(data.get("description", "")).is_empty()), "Every static and color technology has a description")
	check(not hud.tech_buttons.barriers.effect.text.is_empty(), "Technology with no stat summary shows its new description")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/tech_four_columns.png")
	hud.tech_mode_button.pressed.emit()
	await settle()
	check(hud.tech_list_mode and hud.tech_scroll.list_mode and hud.tech_mode_button.text == "Tree view", "View button switches to the research list")
	var researched_bottom := 0.0
	var available_top := INF
	var cards: Array[Rect2] = []
	var list_columns := {}
	for id in hud.tech_buttons:
		var card: Button = hud.tech_buttons[id].button
		list_columns[card.position.x] = true
		if game.researched.has(id): researched_bottom = maxf(researched_bottom, card.position.y + card.size.y)
		else: available_top = minf(available_top,card.position.y)
		cards.append(Rect2(card.position,card.size))
		check(card.size == Vector2(444,136), "List card fits a half-width column: " + id)
	check(list_columns.size() == 2, "List uses two columns")
	check(researched_bottom < available_top, "Every researched technology appears before every available technology")
	var overlap := false
	for i in cards.size():
		for j in range(i + 1,cards.size()):
			if cards[i].intersects(cards[j]): overlap = true
	check(not overlap, "Research list rows do not overlap")
	var header_y: float = hud.tech_list_available_y - hud.tech_scroll.scroll_vertical
	check(absf(header_y - 112) <= 1 and researched_bottom > hud.tech_scroll.scroll_vertical, "List opens on Available with the bottom of researched entries visible above it")
	check(hud.tech_buttons.solar_speed.button.get_meta("cost_labels", {}).values().all(func(amount): return not amount.visible), "Researched entries hide prices until Alt-hovered")
	var clean_states := true
	for id in hud.tech_buttons:
		if not game.researched.has(id) and hud.tech_buttons[id].state.text != "": clean_states = false
	check(clean_states, "Unresearched list buttons omit Research and Insufficient status text")
	var original_zoom: float = hud.tech_scroll.zoom
	hud.tech_scroll.zoom_at(0.5,Vector2(200,200))
	check(hud.tech_scroll.zoom == original_zoom, "List keeps a fixed readable scale")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/tech_list_mode.png")
	hud.tech_buttons.turret_range.button.pressed.emit()
	await settle()
	check(game.researched.has("turret_range") and hud.tech_buttons.turret_range.button.disabled, "Research works from the list and moves the entry into the researched section")
	check(hud.tech_buttons.turret_range.button.position.y < hud.tech_list_available_y, "Newly researched entry is sorted above Available")
	hud.close_modal()
	await settle()
	check(not game.paused, "Closing the research list restores the previous pause state")
	hud.show_tech_tree()
	await settle()
	check(hud.tech_list_mode and absf(hud.tech_list_available_y - hud.tech_scroll.scroll_vertical - 112) <= 1, "Reopening remembers list mode and returns to the first unresearched section")
	hud.toggle_tech_view()
	await settle()
	check(not hud.tech_list_mode and not hud.tech_scroll.list_mode and hud.tech_buttons.barriers.button.size == Vector2(216,128), "Switching back restores the tree layout")
	print("TECH LIST CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
