extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.capture_effect.set_process(false)
	var old_core: Vector2i = game.current_core
	var new_core := old_core + Vector2i(48, 0)
	game.visible_cells = {old_core: true}
	var effect = game.capture_effect
	effect.begin(new_core)
	game.cores.append(new_core)
	game.current_core = new_core
	game._reveal_map()
	var middle := old_core + Vector2i(24, 0)
	var near_old := old_core + Vector2i(4, 4)
	check(game.visible_cells.has(middle + Vector2i(0, 15)), "Captured core route permanently reveals a radial corridor")
	check(effect.previous_origin == game.cell_center(old_core), "Reveal begins from the previous core")
	check(effect.cell_revealed(new_core), "New core starts its own circular reveal immediately")
	effect.advance(effect.REVEAL_DELAY + 0.9)
	check(effect.cell_revealed(near_old) and effect.cell_revealed(new_core + Vector2i(2, 0)), "Route and new-core circle reveal terrain together")
	effect.advance(effect.REVEAL_DURATION)
	check(not effect.active and game.render_visible_cells().has(middle), "Corridor reveal finishes within the original animation duration")
	print("CORE REVEAL CORRIDOR: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
