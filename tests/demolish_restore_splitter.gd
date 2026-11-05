extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.researched.splitter = true
	var cell := Vector2i(27, 25)
	game._add_building(cell, "belt", 0)
	game.buildings[cell].item = "copper"
	game.buildings[cell].paid_cost = {"copper": 1}
	game.select_building("splitter")
	game.hover_cell = cell
	game.hud.ghost_cost.update_preview(Vector2(800, 400))
	check(game.hud.ghost_cost.visible and game.can_build(cell, "splitter"), "Splitter ghost and cost preview allow replacing a belt")
	var amount: int = game.inventory.copper
	game.begin_drag(cell)
	game.finish_drag()
	check(game.buildings[cell].kind == "splitter" and game.inventory.copper == amount - 5, "Clicking a belt places a paid splitter over it")
	check(game.demolitions.size() > 0 and game.buildings[cell].item == "", "Replacing belt runs demolition and discards its cargo")
	game.select_building("belt")
	game.build_direction = 3
	game.hud.toggle_category("Structures")
	game.select_tool("abolish")
	check(game.selected == "" and game.active_tool == "abolish" and not game.hud.expanded.visible, "Entering demolition clears selection and closes tray")
	game.select_tool("abolish")
	check(game.selected == "belt" and game.active_tool == "build" and game.build_direction == 3 and not game.hud.expanded.visible, "Leaving demolition restores prior building and orientation")
	game.select_tool("abolish")
	game.cancel_build_selection()
	check(game.selected == "belt" and game.active_tool == "build", "Right-click cancellation of demolition restores the building")
	game.cancel_build_selection()
	check(game.selected == "", "A subsequent deselect clears the restored building")
	game.capture_blueprint(cell, cell)
	var original: Array = game.blueprint.duplicate(true)
	var dimensions: Vector2i = game.blueprint_size
	game.select_tool("abolish")
	game.remove_building(cell)
	game.select_tool("abolish")
	check(game.active_tool == "blueprint_stamp" and game.blueprint == original and game.blueprint_size == dimensions, "Demolition preserves and restores copied configuration even if source is removed")
	game.select_tool("abolish")
	game.cancel_build_selection(false)
	check(game.active_tool == "build" and game.selected == "" and game.demolish_selection.is_empty(), "Loading or explicit reset can clear saved demolition selection")
	for distance in [12, 15, 16]:
		fresh()
		var origin := Vector2i(8, 25)
		var tower := origin + Vector2i(distance, 0)
		var drill := origin + Vector2i.RIGHT
		game._add_building(tower, "solar", 0)
		game._add_building(drill, "drill", 0)
		var actor: Dictionary = game.create_enemy("scout", game.cell_center(origin), "red")
		game.enemies.append(actor)
		var route: Dictionary = game.enemy_navigation.route(game, actor.pos, false, game.Content.ENEMY_TYPES.scout.reach, actor)
		check(route.target == (tower if distance <= 15 else drill), "Turret priority uses a fifteen-tile boundary: %d" % distance)
	print("DEMOLITION RESTORE AND SPLITTER CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
