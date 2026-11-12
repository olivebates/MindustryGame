extends "res://tests/iron_supply_zoom.gd"
const Fog = preload("res://scripts/fog.gd")
func boundaries_match() -> bool:
	var revealed: Dictionary = game.render_visible_cells()
	var expected := Fog.boundary_cells(revealed)
	if expected.size() != game.fog.boundary_tiles.size(): return false
	var forest = preload("res://scripts/forest_terrain.gd")
	for cell in expected:
		if game.fog.boundary_tiles.get(cell,-1) != forest.indices[Fog.boundary_mask(revealed,cell)]: return false
	return true
func run() -> void:
	fresh()
	game.fog_disabled = false
	game.tutorial.skip_to_ready()
	game.capture_effect.set_process(false)
	game._reveal_map()
	var checkpoint: Array = game.saves.snapshot().duplicate(true)
	var fog = game.fog
	var minimap = game.hud.minimap
	game.camera.force_update_scroll()
	fog.prepare_draw_cache()
	minimap.update_bounds()
	check(boundaries_match(), "Initial cached fog boundary matches a full visibility calculation")
	var boundary_builds: int = fog.boundary_rebuilds
	var geometry_builds: int = fog.draw_cache_builds
	var map_builds: int = minimap.terrain_builds
	for frame in 12:
		game.camera.position.x += 1
		game.camera.force_update_scroll()
		fog.prepare_draw_cache()
		minimap.update_bounds()
	check(fog.boundary_rebuilds == boundary_builds and fog.draw_cache_builds == geometry_builds, "Camera movement inside padded coverage reuses fog commands without rescanning tiles")
	check(minimap.terrain_builds == map_builds, "Camera movement and repeated HUD refreshes reuse the minimap terrain texture")
	var next_core: Vector2i = game.current_core + Vector2i(28,0)
	var effect = game.capture_effect
	effect.begin(next_core)
	game._add_building(next_core,"core",0)
	game.cores.append(next_core)
	game.current_core = next_core
	game._reveal_map()
	fog.prepare_draw_cache()
	minimap.update_bounds()
	check(not effect.reveal_order.is_empty() and boundaries_match(), "A new core starts with a valid sorted reveal frontier and cached boundary")
	boundary_builds = fog.boundary_rebuilds
	var frontier_before: int = effect.frontier_index
	var first: Vector3 = effect.reveal_order[frontier_before]
	var progress: float = minf(0.9,(sqrt(first.z) + game.TILE * 2) / effect.reveal_extent)
	effect.advance(effect.REVEAL_DELAY + progress * effect.REVEAL_DURATION)
	fog.prepare_draw_cache()
	minimap.update_bounds()
	check(effect.active and effect.frontier_index > frontier_before, "Capture advances the reveal frontier without exposing the whole next core")
	var expected_visibility := true
	for cell in game.visible_cells:
		var expected: bool = effect.old_visibility.has(cell) or effect.origin.distance_squared_to(game.cell_center(cell)) <= effect.reveal_radius * effect.reveal_radius
		if game.is_cell_visible(cell) != expected: expected_visibility = false
	check(expected_visibility, "Cached reveal visibility matches the original radius rule for every cell")
	check(fog.boundary_rebuilds == boundary_builds and fog.boundary_updates > 0 and boundaries_match(), "Newly revealed cells update adjacent fog masks without rebuilding all boundaries")
	geometry_builds = fog.draw_cache_builds
	map_builds = minimap.terrain_builds
	for repeat in 8:
		fog.prepare_draw_cache()
		minimap.update_bounds()
	check(fog.draw_cache_builds == geometry_builds and minimap.terrain_builds == map_builds, "An unchanged reveal does not rebuild either rendering cache")
	effect.cancel()
	fog.prepare_draw_cache()
	minimap.update_bounds()
	check(boundaries_match() and game.render_visible_cells() == game.visible_cells, "Cancelling a capture restores normal visibility and invalidates the cached boundary")
	game.fog_disabled = true
	minimap.update_bounds()
	check(minimap.bounds == Rect2(0,0,game.WIDTH,game.HEIGHT), "Disabling fog updates minimap bounds to the full map")
	game.fog_disabled = false
	check(game.saves.restore_snapshot(checkpoint,-1), "Checkpoint can be restored after cached core reveal")
	fog.prepare_draw_cache()
	minimap.update_bounds()
	check(not effect.active and game.paused and boundaries_match(), "Rewinding cancels the reveal and rebuilds caches for the restored core")
	var bounds_before: Rect2 = minimap.bounds
	var camera_before: Vector2 = game.camera.position
	minimap.move_view(minimap.map_offset + bounds_before.size * minimap.map_scale * 0.3)
	check(game.camera.position != camera_before and minimap.bounds == bounds_before, "Minimap dragging still moves the camera while reusing cached bounds")
	print("VISIBILITY CACHE CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
