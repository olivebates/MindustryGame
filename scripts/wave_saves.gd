extends RefCounted
## Compact wave checkpoints; future history is removed only on resume.
const VERSION := 9
const FIELDS := ["inventory", "researched", "discovered_resources", "wave", "wave_timer", "kills", "delivered", "elapsed", "speed", "current_core", "cores", "placement_counts", "base_material_capacity", "core_health", "won", "lost", "victory_shown", "current_wave_color", "next_wave_color", "debug_unlock_step", "debug_resource_capacity", "base_copper_capacity", "enemies", "spawn_queue", "spawn_remaining", "spawn_timer", "wave_in_progress", "pending_waves"]
const TUTORIAL_FIELDS := ["stage", "menu_clicked", "building_clicked", "extractors_ever_built", "turrets_ever_built", "waves_started", "tech_available", "tech_opened", "skipped", "paused_once", "second_wave_elapsed", "extractor_connected_once", "structures_opened_once", "first_damage_taken", "info_hover_time", "collected_tutorial_scrap", "barrier_tree_closed", "inspected_things", "first_wave_completed", "speed_toggled", "designated_extractor", "designated_turret", "designated_path", "misplaced_buildings", "demolish_entered", "demolish_completed", "onboarding_completed", "category_visits", "pause_exit_completed", "introduced_shortcuts", "ui_revealed", "next_core_target", "next_core_stage"]
const BUILD_FIELDS := ["kind", "dir", "input_dir", "hp", "max_hp", "item", "travel", "progress", "cooldown", "ammo", "aim", "flash", "buffer", "paid_cost", "tunnel_role", "tunnel_pair", "pulse", "next_output", "route_dir", "color"]
var game: Node2D
var directory := "user://wave_saves"
var entries: Array[Dictionary] = []
var current := -1
var pending_branch := false
var last_error := ""
var learning_directory := ""
var learned_progress: Dictionary = {}
var learned_resources: Dictionary = {}
var learning_hash := 0
const WORLD_TUTORIAL_FIELDS := ["designated_extractor", "designated_turret", "designated_path", "misplaced_buildings", "next_core_target"]
func merge_learning(destination: Dictionary, incoming: Dictionary) -> void:
	for key in incoming:
		var value = incoming[key]
		if value is Dictionary:
			if not destination.get(key) is Dictionary: destination[key] = {}
			merge_learning(destination[key], value)
		elif value is bool: destination[key] = destination.get(key, false) or value
		elif value is int or value is float: destination[key] = max(destination.get(key, value), value)
func ensure_learning_loaded() -> void:
	if learning_directory == directory: return
	learning_directory = directory
	learned_progress = {}
	learned_resources = {}
	learning_hash = 0
	var path := directory.path_join("tutorial.learned")
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path).decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE)
		var data = bytes_to_var(bytes) if not bytes.is_empty() else null
		if data is Dictionary:
			learned_progress = data.get("progress", {})
			learned_resources = data.get("resources", {})
	if not entries.is_empty():
		var data := load_snapshot(entries.size() - 1)
		if not data.is_empty():
			var archived: Dictionary = {}
			for index in TUTORIAL_FIELDS.size():
				if TUTORIAL_FIELDS[index] not in WORLD_TUTORIAL_FIELDS: archived[TUTORIAL_FIELDS[index]] = data[3][index]
			merge_learning(learned_progress, archived)
			learned_resources.merge(data[1][2], true)
			if data[1][1].has("barriers"):
				if not learned_progress.has("ui_revealed"): learned_progress.ui_revealed = {}
				learned_progress.ui_revealed.barrier_building = true
	apply_learning()
func apply_learning() -> void:
	for field in learned_progress:
		if field not in TUTORIAL_FIELDS or field in WORLD_TUTORIAL_FIELDS: continue
		var value = learned_progress[field]
		var current = game.tutorial.get(field)
		if value is Dictionary:
			var merged: Dictionary = current.duplicate(true)
			merge_learning(merged, value)
			game.tutorial.set(field, merged)
		elif value is bool: game.tutorial.set(field, current or value)
		elif value is int or value is float: game.tutorial.set(field, max(current, value))
	game.discovered_resources.merge(learned_resources, true)
	if game.tutorial.ui_revealed.get("barrier_building", false): game.researched.barriers = true
func remember_learning() -> void:
	ensure_learning_loaded()
	var current: Dictionary = {}
	for field in TUTORIAL_FIELDS:
		if field not in WORLD_TUTORIAL_FIELDS: current[field] = game.tutorial.get(field)
	merge_learning(learned_progress, current)
	learned_resources.merge(game.discovered_resources, true)
	var bytes := var_to_bytes({"progress": learned_progress, "resources": learned_resources})
	var next_hash := hash(bytes)
	if next_hash == learning_hash: return
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return
	var path := directory.path_join("tutorial.learned")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_buffer(bytes.compress(FileAccess.COMPRESSION_DEFLATE))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) == OK: learning_hash = next_hash
func _init(owner: Node2D) -> void:
	game = owner
	# Test scripts never read or overwrite player history.
	if OS.get_cmdline_args().has("--script"): directory = "res://.godot/test_wave_saves_" + str(OS.get_process_id()) + "_" + str(owner.get_instance_id()) + "_" + str(Time.get_ticks_usec())
	elif FileAccess.file_exists("user://active_expedition"):
		var active := FileAccess.get_file_as_string("user://active_expedition").strip_edges()
		if active.begins_with("wave_saves") and active.is_valid_filename(): directory = "user://" + active
	read_index()
func read_index() -> void:
	entries.clear()
	var folder := DirAccess.open(directory)
	if folder == null: return
	var files := folder.get_files()
	files.sort()
	for file in files:
		if file.ends_with(".ews"):
			var parts := file.trim_suffix(".ews").split("_")
			if parts.size() == 3: entries.append({"file": file, "wave": int(parts[1]), "time": int(parts[2])})
	current = entries.size() - 1
func snapshot() -> Array:
	remember_learning()
	game.tutorial.shortcut_lines()
	for resource in game.inventory:
		if game.inventory[resource] > 0: game.discovered_resources[resource] = true
	var values: Array = []
	for field in FIELDS:
		if field == "enemies":
			var enemies: Array = game.enemies.duplicate(true)
			for enemy in enemies:
				enemy.erase("navigation")
				enemy.erase("navigation_timer")
			values.append(enemies)
		else: values.append(game.owned_building_counts() if field == "placement_counts" else game.get(field))
	var rows: Array = []
	var cells: Array = game.buildings.keys()
	cells.sort()
	for cell in cells:
		var row: Array = [cell]
		for field in BUILD_FIELDS: row.append(game.buildings[cell].get(field))
		rows.append(row)
	var progress: Array = []
	for field in TUTORIAL_FIELDS: progress.append(game.tutorial.get(field))
	var gates: Array = []
	for gate in game.spawners: gates.append([gate.waves_completed, gate.converted, gate.prepared_color])
	return [VERSION, values, rows, progress, gates, game.scraps.duplicate(true), game.camera.position, game.camera.zoom, game.rng.state, game.wave_rng.state]
func capture() -> bool:
	if pending_branch: return false
	last_error = ""
	var raw := var_to_bytes(snapshot())
	var packed := PackedByteArray()
	var mode := FileAccess.COMPRESSION_ZSTD
	for candidate in [FileAccess.COMPRESSION_ZSTD, FileAccess.COMPRESSION_DEFLATE, FileAccess.COMPRESSION_GZIP]:
		var compressed := raw.compress(candidate)
		if packed.is_empty() or compressed.size() < packed.size():
			packed = compressed
			mode = candidate
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Could not create save directory: " + directory
		return false
	var stamp := int(Time.get_unix_time_from_system())
	var name := "%06d_%03d_%d.ews" % [entries.size(), game.wave, stamp]
	var file := FileAccess.open(directory.path_join(name + ".tmp"), FileAccess.WRITE)
	if file == null:
		last_error = "Could not write wave save."
		return false
	file.store_buffer("EWS1".to_ascii_buffer())
	file.store_8(mode)
	file.store_32(raw.size())
	file.store_buffer(checksum(raw))
	file.store_buffer(packed)
	file.close()
	if DirAccess.rename_absolute(directory.path_join(name + ".tmp"), directory.path_join(name)) != OK:
		last_error = "Could not finish wave save."
		return false
	entries.append({"file": name, "wave": game.wave, "time": stamp})
	current = entries.size() - 1
	capture_preview(name)
	return true

func preview_path(name: String) -> String:
	return directory.path_join(name.trim_suffix(".ews") + ".webp")

func capture_preview(name: String, data: Array = []) -> void:
	var destination := preview_path(name)
	var snapshot_path := directory.path_join(name)
	if DisplayServer.get_name() == "headless":
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		img.fill(Color("182c33"))
		img.save_webp(destination, true, 0.65)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawing := Node2D.new()
	drawing.set_script(load("res://scripts/save_preview.gd"))
	drawing.configure(game, data)
	var view_scale: float = 256.0 / (41.0 * game.TILE)
	drawing.scale = Vector2.ONE * view_scale
	drawing.position = -Vector2((drawing.core - Vector2i(20, 20)) * game.TILE) * view_scale
	viewport.add_child(drawing)
	game.add_child(viewport)
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport) and FileAccess.file_exists(snapshot_path):
		viewport.get_texture().get_image().save_webp(destination, true, 0.65)
	if is_instance_valid(viewport): viewport.queue_free()
func load_snapshot(index: int) -> Array:
	if index < 0 or index >= entries.size(): return []
	var file := FileAccess.open(directory.path_join(entries[index].file), FileAccess.READ)
	if file == null or file.get_length() < 13: return []
	if file.get_buffer(4).get_string_from_ascii() != "EWS1": return []
	var mode := file.get_8()
	if mode not in [FileAccess.COMPRESSION_ZSTD, FileAccess.COMPRESSION_DEFLATE, FileAccess.COMPRESSION_GZIP]: return []
	var size := file.get_32()
	if size <= 0 or size > 64 * 1024 * 1024: return []
	var digest := file.get_buffer(4)
	var raw := file.get_buffer(file.get_length() - file.get_position()).decompress(size, mode)
	if checksum(raw) != digest: return []
	var data = bytes_to_var(raw)
	if not data is Array or data.size() != 10: return []
	if data[0] == 1:
		if data[1].size() != 21 or data[3].size() != 11: return []
		data[1].append(40)
		var progress: Array = data[3]
		progress.append(progress[0] >= 4 and not progress[8])
		progress.append(progress[1] or progress[0] >= 3)
		var damaged := false
		for row in data[2]:
			if row.size() == BUILD_FIELDS.size() + 1 and row[4] < row[5]: damaged = true
		progress.append(damaged)
		progress.append(0.0)
		data[0] = 2
	if data[0] == 2:
		if data[3].size() != 15: return []
		data[3].append(maxi(int(data[1][0].get("scrap", 0)), game.Content.BARRIER_UNLOCK_SCRAP if data[1][1].has("barriers") else 0))
		data[3].append(data[1][1].has("barriers"))
		data[3].append({})
		data[0] = 3
	if data[0] == 3:
		if data[3].size() != 18: return []
		data[3].append(int(data[1][3]) >= 1)
		data[3].append(int(data[1][8]) == 3)
		data[0] = 4
	if data[0] == 4:
		if data[3].size() != 20: return []
		var established: bool = data[3][5] or data[3][0] >= 5
		data[3].append(game.INVALID)
		data[3].append(game.INVALID)
		var path: Array[Vector2i] = []
		data[3].append(path)
		data[3].append({})
		data[3].append(established)
		data[3].append(established)
		data[3].append(established)
		data[3].append({})
		data[0] = 5
	if data[0] == 5:
		if data[3].size() != 28: return []
		data[3].append(bool(data[3][16]) and (float(data[3][14]) >= 2.0 or data[3][17].size() >= 3))
		data[3].append({"LMB": true})
		data[0] = 6
	if data[0] == 6:
		if data[1].size() != 22: return []
		data[1].append_array([[], [], 0, 0.0, false, {}])
		data[0] = 7
	if data[0] == 7:
		data[3].append({"split": data[1][1].has("barriers") or data[3][16], "tech": data[3][6], "pause": data[3][18] or data[3][9], "waves": data[3][5] or data[3][26], "palette": data[3][0] >= 2})
		if data[3][29].has("Q"): data[3][29].E = true
		data[0] = 8
	if data[0] == 8:
		data[3].append_array([game.INVALID, 0])
		data[0] = VERSION
	if data[0] != VERSION: return []
	if data[1].size() != FIELDS.size() or data[3].size() != TUTORIAL_FIELDS.size() or data[4].size() != game.spawners.size(): return []
	for row in data[2]:
		if not row is Array or row.size() != BUILD_FIELDS.size() + 1: return []
		if not (row[1] == "core" or game.BUILDINGS.has(row[1])): return []
	return data
func restore(index: int) -> bool:
	var data := load_snapshot(index)
	if data.is_empty():
		last_error = "This save could not be read."
		return false
	remember_learning()
	var rewind_frame: Dictionary = game.hud.capture_rewind_frame()
	var known_resources: Dictionary = game.discovered_resources.duplicate()
	var learned: Dictionary = {}
	for field in TUTORIAL_FIELDS:
		var value = game.tutorial.get(field)
		learned[field] = value.duplicate(true) if value is Dictionary else value
	game.cancel_build_selection()
	game.buildings.clear()
	game.occupied.clear()
	for i in FIELDS.size(): game.set(FIELDS[i], data[1][i])
	game.discovered_resources.merge(known_resources, true)
	game.placement_counts.clear()
	for row in data[2]:
		var cell: Vector2i = row[0]
		game._add_building(cell, row[1], row[2])
		for i in BUILD_FIELDS.size(): game.buildings[cell][BUILD_FIELDS[i]] = row[i + 1]
	for i in TUTORIAL_FIELDS.size(): game.tutorial.set(TUTORIAL_FIELDS[i], data[3][i])
	# Learning belongs to the player, rather than to a checkpoint's world state.
	for field in TUTORIAL_FIELDS:
		if field in ["designated_extractor", "designated_turret", "designated_path", "misplaced_buildings", "next_core_target"]: continue
		var previous = learned[field]
		var restored = game.tutorial.get(field)
		if previous is bool: game.tutorial.set(field, previous or restored)
		elif previous is int or previous is float: game.tutorial.set(field, max(previous, restored))
		elif previous is Dictionary:
			var merged: Dictionary = restored.duplicate(true)
			merged.merge(previous, true)
			game.tutorial.set(field, merged)
	for i in game.spawners.size():
		var gate = game.spawners[i]
		gate.waves_completed = data[4][i][0]
		gate.converted = data[4][i][1]
		gate.prepared_color = data[4][i][2]
		gate.visible = not gate.converted
	apply_learning()
	game.cancel_wave_warp()
	game.scraps.assign(data[5])
	game.camera.position = data[6]
	game.camera.zoom = data[7]
	game.rng.state = data[8]
	game.wave_rng.state = data[9]
	game.shots.clear()
	game.particles.clear()
	game.demolitions.clear()
	game.notice_time = 0
	game.inspected = game.INVALID
	game.tutorial.guide_dirty = true
	game._activate_spawners()
	game.enemy_navigation.invalidate(game)
	for enemy in game.enemies: game.enemy_info_counter = maxi(game.enemy_info_counter, int(enemy.get("info_id", 0)))
	game.paused = true
	game.hud.modal_was_paused = true
	game.rollback_paused = true
	current = index
	pending_branch = index < entries.size() - 1
	game.hud.research_signature = -1
	game.hud.refresh()
	game.hud.play_rewind_effect(rewind_frame)
	game.queue_redraw()
	return true

func timeline_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var previous_cores := 1
	var previous_research: Dictionary = {}
	for index in entries.size():
		var events := {"cores": 0, "research": [], "summary": {"buildings": 0, "turrets": 0, "techs": 0, "enemies": {}}}
		var data := load_snapshot(index)
		if not data.is_empty():
			events.summary = summary_from_snapshot(data)
			events.cores = maxi(0, data[1][10].size() - previous_cores)
			previous_cores = data[1][10].size()
			var research: Dictionary = data[1][1]
			for id in research:
				if not previous_research.has(id) and game.TECH.has(id) and not game.TECH[id].has("color"):
					events.research.append(game.TECH[id].name)
			previous_research = research
		result.append(events)
	return result
func summary_from_snapshot(data: Array) -> Dictionary:
	var result := {"buildings": 0, "turrets": 0, "techs": data[1][1].size(), "enemies": {}}
	if not data[1][1].has("barriers") and game.tutorial.ui_revealed.get("barrier_building", false): result.techs += 1
	for row in data[2]:
		if game.is_turret(row[1]): result.turrets += 1
		elif row[1] not in ["belt", "wall"]: result.buildings += 1
	var order := 2147483647
	for index in game.spawners.size():
		if not data[4][index][1]: order = mini(order, game.spawners[index].Order)
	var indices: Array = []
	for index in game.spawners.size():
		if not data[4][index][1] and game.spawners[index].Order == order: indices.append(index)
	var forecast: Dictionary = preload("res://scripts/wave_forecast.gd").build(game, int(data[1][3]) + 1, indices, data[4], data[1][27])
	for unit in forecast.units: result.enemies[unit.kind] = result.enemies.get(unit.kind, 0) + 1
	return result
func previous_index() -> int:
	if game.wave_in_progress or (current >= 0 and game.wave > entries[current].wave): return current
	return current - 1
func commit_branch() -> bool:
	if not pending_branch: return true
	for i in range(entries.size() - 1, current, -1):
		if DirAccess.remove_absolute(directory.path_join(entries[i].file)) != OK:
			last_error = "Could not remove a later save."
			return false
		if FileAccess.file_exists(preview_path(entries[i].file)): DirAccess.remove_absolute(preview_path(entries[i].file))
		entries.remove_at(i)
	pending_branch = false
	return true
func checksum(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().slice(0, 4)
func write_active_directory() -> void:
	var file := FileAccess.open("user://active_expedition", FileAccess.WRITE)
	if file != null: file.store_string(directory.get_file())







