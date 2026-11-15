extends RefCounted
static func clear_combat(game: Node2D) -> void:
	game.cancel_final_wave_completion()
	game.cancel_wave_warp()
	game.capture_effect.cancel()
	game.enemies.clear()
	game.spawn_queue.clear()
	game.spawn_remaining = 0
	game.spawn_timer = 0.0
	game.pending_waves.clear()
	game.wave_in_progress = false
	game.shots.clear()
	game.particles.clear()
	game.enemy_visual_offsets.clear()
	if game.developer_waves != null:
		game.developer_waves.running = false
		game.developer_waves.status = "G: first turret / H: all turrets"
	game.lost = false
	game.won = false
	game.victory_shown = false
	if is_instance_valid(game.hud.modal): game.hud.close_modal()
	game.paused = true
	game.core_under_attack = false
	game.activate_pending_buildings(true)
static func next_core(game: Node2D) -> void:
	if game.active_spawners.is_empty():
		game.toast("No next core available")
		return
	clear_combat(game)
	var count: int = game.cores.size()
	# Some authored gate groups finish without becoming cores. Finish those
	# too, stopping as soon as a new core has actually been captured.
	for group in game.spawners.size():
		if game.active_spawners.is_empty() or game.cores.size() > count: break
		for gate in game.active_spawners: gate.waves_completed = gate.waves_before_conversion - 1
		game._complete_wave(-1, true)
	game.hud.refresh()
static func previous_core(game: Node2D) -> void:
	var index: int = game.cores.find(game.current_core)
	if index <= 0:
		game.toast("Already at the first core")
		return
	clear_combat(game)
	var retired: Array = game.cores.slice(index)
	var order := 2147483647
	for gate in game.spawners:
		if retired.has(Vector2i((gate.position / game.TILE).floor())): order = mini(order, gate.Order)
	for gate in game.spawners:
		if gate.Order >= order:
			gate.converted = false
			gate.waves_completed = 0
			gate.show()
	for cell in retired:
		if game.buildings.has(cell) and game.buildings[cell].kind == "core":
			game.buildings.erase(cell)
			game.occupied.erase(cell)
			game.building_centers.erase(cell)
	game.cores.resize(index)
	game.current_core = game.cores.back()
	if not game.buildings.has(game.current_core): game._add_building(game.current_core, "core", 0)
	game.core_health = game.buildings[game.current_core].hp
	game.wave = 0
	game.wave_timer = 240.0
	game._activate_spawners()
	game.enemy_navigation.invalidate(game)
	game.tutorial.on_new_core(game.current_core)
	game.set_camera_zoom(1.0)
	game.camera.position = game.clamp_camera_position(game.cell_center(game.current_core))
	game.camera.force_update_scroll()
	game.hud.refresh()
static func unlock_through_row(game: Node2D, id: String) -> bool:
	if not game.debug_tech_reveal or not game.TECH.has(id): return false
	var ids: Array[String] = []
	ids.assign(game.TECH.keys())
	var was_list: bool = game.hud.tech_list_mode
	game.hud.tech_list_mode = false
	var positions: Dictionary = game.hud.tech_positions(ids)
	game.hud.tech_list_mode = was_list
	var visited := {}
	for candidate in ids:
		if positions[candidate].y < positions[id].y or candidate == id: unlock_dependencies(game, candidate, visited)
	return true
static func unlock_dependencies(game: Node2D, id: String, visited: Dictionary) -> void:
	if id == "" or visited.has(id) or not game.TECH.has(id): return
	visited[id] = true
	unlock_dependencies(game, game.TECH[id].parent, visited)
	for required in game.TECH[id].get("requires", []): unlock_dependencies(game, required, visited)
	game.research(id, true)
