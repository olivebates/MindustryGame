extends RefCounted
## Compact wave checkpoints; future history is removed only on resume.
const VERSION := 19
const SaveState = preload("res://scripts/save_state.gd")
const FIELDS := ["inventory", "researched", "discovered_resources", "wave", "wave_timer", "kills", "delivered", "elapsed", "speed", "current_core", "cores", "placement_counts", "base_material_capacity", "core_health", "won", "lost", "victory_shown", "current_wave_color", "next_wave_color", "debug_unlock_step", "debug_resource_capacity", "base_copper_capacity", "enemies", "spawn_queue", "spawn_remaining", "spawn_timer", "wave_in_progress", "pending_waves"]
const TUTORIAL_FIELDS := ["stage", "menu_clicked", "building_clicked", "extractors_ever_built", "turrets_ever_built", "waves_started", "tech_available", "tech_opened", "skipped", "paused_once", "second_wave_elapsed", "extractor_connected_once", "structures_opened_once", "first_damage_taken", "info_hover_time", "collected_tutorial_scrap", "barrier_tree_closed", "inspected_things", "first_wave_completed", "speed_toggled", "designated_extractor", "designated_turret", "designated_path", "misplaced_buildings", "demolish_entered", "demolish_completed", "onboarding_completed", "category_visits", "pause_exit_completed", "introduced_shortcuts", "ui_revealed", "next_core_target", "next_core_stage", "ammo_tutorial_target", "ammo_tutorial_stage", "pink_lesson_source", "pink_lesson_target", "pink_lesson_kind"]
const BUILD_FIELDS := ["kind", "dir", "input_dir", "hp", "max_hp", "item", "travel", "progress", "cooldown", "ammo", "aim", "flash", "buffer", "paid_cost", "tunnel_role", "tunnel_pair", "pulse", "next_output", "route_dir", "color", "shield", "pending", "booster_type", "booster_count", "booster_used", "booster_fire_remaining", "nuclear"]
var game: Node2D
var directory := "user://wave_saves"
var entries: Array[Dictionary] = []
var current := -1
var initial_checkpoint: Array = []
var pending_branch := false
var last_error := ""
var quick_slots_directory := ""
func ensure_learning_loaded() -> void:
	# Tutorial and discovery state now come from the retained world state.
	# Legacy tutorial.learned files are intentionally ignored.
	pass
func apply_learning() -> void:
	pass
func remember_learning() -> void:
	game.tutorial.ui_revealed.max_core_count = maxi(int(game.tutorial.ui_revealed.get("max_core_count", 1)), game.cores.size())
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
	return SaveState.expand(game, SaveState.capture(game))
func capture(checkpoint: Array = [], checkpoint_wave: int = -1) -> bool:
	if pending_branch: return false
	last_error = ""
	var data: Array = snapshot() if checkpoint.is_empty() else checkpoint
	var saved_wave: int = maxi(1, int(data[1][3]) if checkpoint_wave < 0 else checkpoint_wave)
	var stamp := int(Time.get_unix_time_from_system())
	var name := "%06d_%03d_%d.ews" % [entries.size(), saved_wave, stamp]
	if not write_snapshot(directory.path_join(name), data): return false
	entries.append({"file": name, "wave": saved_wave, "time": stamp})
	current = entries.size() - 1
	capture_preview(name, data)
	return true

func write_snapshot(path: String, data: Array) -> bool:
	var saved := SaveState.from_legacy(game, data)
	if saved.is_empty(): return false
	var raw := var_to_bytes(saved)
	var packed := PackedByteArray()
	var mode := FileAccess.COMPRESSION_ZSTD
	for candidate in [FileAccess.COMPRESSION_ZSTD, FileAccess.COMPRESSION_DEFLATE, FileAccess.COMPRESSION_GZIP]:
		var compressed := raw.compress(candidate)
		if packed.is_empty() or compressed.size() < packed.size():
			packed = compressed
			mode = candidate
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		last_error = "Could not create save directory: " + path.get_base_dir()
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not write wave save."
		return false
	file.store_buffer("EWS1".to_ascii_buffer())
	file.store_8(mode)
	file.store_32(raw.size())
	file.store_buffer(checksum(raw))
	file.store_buffer(packed)
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Could not finish wave save."
		return false
	return true

func preview_path(name: String) -> String:
	return directory.path_join(name.trim_suffix(".ews") + ".framed.webp")

func slot_path(slot: int) -> String:
	# Numbered slots survive starting a new expedition. Test histories stay isolated.
	var root := directory.path_join("slots") if directory.begins_with("res://") else "user://quick_slots"
	if quick_slots_directory != "": root = quick_slots_directory
	return root.path_join("%d.ews" % slot)

func find_slot(slot: int) -> String:
	var path := slot_path(slot)
	if FileAccess.file_exists(path): return path
	var legacy := directory.path_join("slots/%d.ews" % slot)
	if FileAccess.file_exists(legacy): return legacy
	if directory.begins_with("res://"): return path
	var latest := 0
	for folder in DirAccess.get_directories_at("user://"):
		if not folder.begins_with("wave_saves"): continue
		var candidate := "user://".path_join(folder).path_join("slots/%d.ews" % slot)
		if FileAccess.file_exists(candidate) and FileAccess.get_modified_time(candidate) >= latest:
			latest = FileAccess.get_modified_time(candidate)
			path = candidate
	return path

func save_slot(slot: int) -> bool:
	if slot < 1 or slot > 9 or game.lost: return false
	var path := slot_path(slot)
	if not write_snapshot(path, snapshot()): return false
	var reference := FileAccess.open(path + ".checkpoint", FileAccess.WRITE)
	if reference != null:
		reference.store_string(JSON.stringify([directory, entries[current].file if current >= 0 and current < entries.size() else ""]))
	game.toast("Saved slot %d" % slot)
	return true

func load_slot(slot: int) -> bool:
	if slot < 1 or slot > 9: return false
	var path := find_slot(slot)
	var data := read_snapshot(path)
	if data.is_empty():
		game.toast("No valid save in slot %d" % slot)
		return false
	var checkpoint := FileAccess.get_file_as_string(path + ".checkpoint") if FileAccess.file_exists(path + ".checkpoint") else ""
	var metadata = JSON.parse_string(checkpoint) if checkpoint.begins_with("[") else null
	var source := directory
	if metadata is Array and metadata.size() == 2:
		source = str(metadata[0])
		checkpoint = str(metadata[1])
	elif path.contains("/slots/"):
		source = path.get_base_dir().get_base_dir()
	if source != directory:
		directory = source
		read_index()
		if directory.begins_with("user://"): write_active_directory()
	var index := -1
	for i in entries.size():
		if entries[i].file == checkpoint: index = i
	if not restore_snapshot(data, index): return false
	if is_instance_valid(game.hud.modal):
		game.hud.modal_was_paused = true
		game.hud.close_modal()
	game.toast("Loaded slot %d" % slot)
	return true

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
	drawing.material = game.material
	drawing.configure(game, data)
	var bounds: Rect2 = drawing.capture_bounds(game)
	var view_scale: float = 256.0 / bounds.size.x
	drawing.scale = Vector2.ONE * view_scale
	drawing.position = -bounds.position * view_scale
	viewport.add_child(drawing)
	game.add_child(viewport)
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport) and FileAccess.file_exists(snapshot_path):
		viewport.get_texture().get_image().save_webp(destination, true, 0.65)
	if is_instance_valid(viewport): viewport.queue_free()
func load_snapshot(index: int) -> Array:
	if index < 0 or index >= entries.size(): return []
	return read_snapshot(directory.path_join(entries[index].file))

func read_snapshot(snapshot_path: String) -> Array:
	var file := FileAccess.open(snapshot_path, FileAccess.READ)
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
	if data is Dictionary: return SaveState.expand(game, data)
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
		data[0] = 9
	if data[0] == 9:
		data[3].append_array([game.INVALID, 0])
		var piles: Array = []
		for scrap in data[5]:
			for value in preload("res://scripts/scrap_tiers.gd").split(scrap.amount):
				var piece: Dictionary = scrap.duplicate(true)
				piece.amount = value
				piece.value = value
				piece.origin = piece.pos
				piece.velocity = Vector2.ZERO
				piles.append(piece)
		data[5] = piles
		data[0] = 10
	if data[0] == 10: migrate_fast_balance(data)
	if data[0] == 11:
		for row in data[2]:
			if row.size() == 21: row.append(false)
		data[0] = 12
	if data[0] == 12:
		for row in data[2]:
			if row.size() == 22: row.append(false)
		data[0] = 13
	if data[0] == 13:
		data[1][0].pink = 0
		data[3].append_array([game.INVALID, game.INVALID, ""])
		for row in data[2]:
			if row.size() == 23: row.append_array(["", 0])
			row[BUILD_FIELDS.find("buffer") + 1].pink = 0
		data[0] = 14
	if data[0] == 14:
		for row in data[2]: row.append_array([0.0, 0.0])
		data[0] = 15
	if data[0] == 15:
		if data[1][21] == 40: data[1][21] = 100
		for row in data[2]:
			if row[1] == "solar":
				var health: float = 30.0 * (1.25 if data[1][1].has("armor") else 1.0) + (10.0 if data[1][1].has("solar_health") else 0.0)
				row[4] = health * clampf(float(row[4]) / maxf(1, float(row[5])), 0, 1)
				row[5] = health
			if row[1] == "refinery": row[8] = minf(10, float(row[8]) * 10.0 / 3.0)
		data[0] = 16
	if data[0] == 16:
		for row in data[2]:
			if row[1] == "core":
				var health := 200.0 * (1.25 if data[1][1].has("armor") else 1.0)
				row[4] = health * clampf(float(row[4]) / maxf(1, float(row[5])), 0, 1)
				row[5] = health
				if row[0] == data[1][9]: data[1][13] = row[4]
		data[0] = 17
	if data[0] == 17:
		for row in data[2]: row.append({})
		data[0] = 18
	if data[0] == 18: data[0] = 19
	if data[0] != VERSION: return []
	if data[1].size() != FIELDS.size() or data[3].size() != TUTORIAL_FIELDS.size() or data[4].size() != game.spawners.size(): return []
	for row in data[2]:
		if not row is Array or row.size() != BUILD_FIELDS.size() + 1: return []
		if not (row[1] == "core" or game.BUILDINGS.has(row[1]) or game.Content.REMOVED_BUILDINGS.has(row[1])): return []
	return SaveState.expand(game, SaveState.from_legacy(game, data))
func restore(index: int) -> bool:
	var data := load_snapshot(index)
	return restore_snapshot(data, index)

func restore_snapshot(data: Array, index: int) -> bool:
	if not data.is_empty(): data = SaveState.expand(game, SaveState.from_legacy(game, data))
	if data.is_empty():
		last_error = "This save could not be read."
		return false
	remember_learning()
	var rewind_frame: Dictionary = game.hud.capture_rewind_frame()
	game.cancel_final_wave_completion()
	game.core_under_attack = false
	if is_instance_valid(game.capture_effect): game.capture_effect.cancel()
	game.cancel_build_selection(false)
	game.enemy_visual_offsets.clear()
	game.buildings.clear()
	game.occupied.clear()
	for i in FIELDS.size(): game.set(FIELDS[i], data[1][i])
	game.inventory.erase("scrap")
	game.discovered_resources.erase("scrap")
	game.researched.erase("auto_scrap")
	game.speed = game.SPEEDUP_MULTIPLIER if game.speed > 1 and game.researched.has("time_speed") else 1
	game.placement_counts.clear()
	for row in data[2]:
		var cell: Vector2i = row[0]
		if row[1] == "scrap_store": continue
		game._add_building(cell, row[1], row[2])
		for i in BUILD_FIELDS.size(): game.buildings[cell][BUILD_FIELDS[i]] = row[i + 1]
		if row[1] == "wall":
			var wall: Dictionary = game.buildings[cell]
			var health: float = game.BUILDINGS.wall.hp * (1.25 if game.researched.has("armor") else 1.0)
			wall.hp = health * clampf(wall.hp / maxf(1.0, wall.max_hp), 0.0, 1.0)
			wall.max_hp = health
		if game.is_turret(game.buildings[cell].kind):
			game.buildings[cell].ammo = mini(int(game.buildings[cell].ammo), game.turret_ammo_capacity(game.buildings[cell].kind))
		if game.buildings[cell].kind == "belt": game.buildings[cell].pending = false
		if game.buildings[cell].get("pending", false): game.has_pending_construction = true
	for i in TUTORIAL_FIELDS.size(): game.tutorial.set(TUTORIAL_FIELDS[i], data[3][i])
	for i in game.spawners.size():
		var gate = game.spawners[i]
		gate.waves_completed = data[4][i][0]
		gate.converted = data[4][i][1]
		gate.prepared_color = data[4][i][2]
		gate.visible = not gate.converted
	apply_learning()
	game.cancel_wave_warp()
	game.scraps.clear()
	game.camera.position = data[6]
	game.set_camera_zoom(float(data[7].x))
	game.rng.state = data[8]
	game.wave_rng.state = data[9]
	game.shots.clear()
	game.particles.clear()
	game.demolitions.clear()
	game.notice_time = 0
	game.inspected = game.INVALID
	game.tutorial.guide_dirty = true
	game.tutorial.refresh_ammo_guide()
	game.tutorial.pink_guide_signature = -1
	preload("res://scripts/pink_tutorial.gd").update(game.tutorial)
	game._activate_spawners()
	game.enemy_navigation.invalidate(game)
	for enemy in game.enemies: game.enemy_info_counter = maxi(game.enemy_info_counter, int(enemy.get("info_id", 0)))
	game.paused = true
	game.hud.modal_was_paused = true
	game.rollback_paused = true
	current = index
	mark_played(index)
	pending_branch = index < entries.size() - 1
	if game.cores.size() == 2: game.tutorial.ui_revealed.slugger_rewind_hint = true
	game.hud.research_signature = -1
	game.hud.refresh()
	game.hud.play_rewind_effect(rewind_frame)
	game.queue_redraw()
	return true

func mark_played(index: int) -> void:
	if index < 0 or index >= entries.size(): return
	var file := FileAccess.open(directory.path_join(entries[index].file + ".played"), FileAccess.WRITE)
	if file != null: file.store_64(int(Time.get_unix_time_from_system()))

func last_played(index: int) -> int:
	var file := FileAccess.open(directory.path_join(entries[index].file + ".played"), FileAccess.READ)
	return int(file.get_64()) if file != null and file.get_length() == 8 else int(entries[index].time)

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
		var played_path: String = directory.path_join(entries[i].file + ".played")
		if FileAccess.file_exists(played_path): DirAccess.remove_absolute(played_path)
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











func migrate_fast_balance(data: Array) -> void:
	for row in data[2]:
		var kind: String = row[1]
		if kind == "drill": row[BUILD_FIELDS.find("progress") + 1] /= 5.0
		if game.is_turret(kind): row[BUILD_FIELDS.find("cooldown") + 1] /= 5.0
		if kind == "wall" and row[BUILD_FIELDS.find("max_hp") + 1] > game.BUILDINGS.wall.hp * 2:
			row[BUILD_FIELDS.find("hp") + 1] /= 20.0
			row[BUILD_FIELDS.find("max_hp") + 1] /= 20.0
	for enemy in data[1][FIELDS.find("enemies")]:
		enemy.speed = game.Content.ENEMY_TYPES[enemy.kind].speed
		enemy.cooldown /= 5.0
	data[1][FIELDS.find("wave_timer")] *= 0.4
	data[1][FIELDS.find("speed")] = 1
	data[0] = 11
