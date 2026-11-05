extends Node2D
## Event-driven onboarding. Rendering uses authored tiles and never writes the level.
enum Stage { MINE, FUNDS, EXTRACTOR, BELTS, SOLAR, READY }
var game: Node2D
var stage := Stage.MINE
var menu_clicked := false
var building_clicked := false
var extractors_ever_built := 0
var turrets_ever_built := 0
var waves_started := false
var tech_available := false
var tech_opened := false
var skipped := false
var guide_path: Array[Vector2i] = []
var guide_dirty := true
var poll_clock := 0.0
var paused_once := false
var second_wave_elapsed := 0.0
var extractor_connected_once := false
var structures_opened_once := false
var first_damage_taken := false
var info_hover_time := 0.0
var collected_tutorial_scrap := 0
var barrier_tree_closed := false
var inspected_things: Dictionary = {}
var first_wave_completed := false
var speed_toggled := false
var designated_extractor := Vector2i(-1000, -1000)
var designated_turret := Vector2i(-1000, -1000)
var designated_path: Array[Vector2i] = []
var misplaced_buildings: Dictionary = {}
var demolish_entered := false
var demolish_completed := false
var onboarding_completed := false
var category_visits: Dictionary = {}
var pause_exit_completed := false
var ui_revealed: Dictionary = {}
var next_core_target := Vector2i(-1000, -1000)
var next_core_stage := 0
var ammo_tutorial_target := Vector2i(-1000, -1000)
var ammo_tutorial_stage := 0
var ammo_guide_path: Array[Vector2i] = []
var ammo_guide_clock := 0.0
var ammo_guide_extractor := Vector2i(-1000, -1000)
var ammo_guide_signature := -1
var guide_grid_signature := -1
var guide_grid := AStarGrid2D.new()
var guide_grid_builds := 0
var ammo_path_queries := 0
var drag_label: Label
var introduced_shortcuts: Dictionary = {"LMB": true}
func _ready() -> void:
	z_index = 210
	material = game.material
	drag_label = Label.new()
	drag_label.text = "Drag"
	drag_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	drag_label.add_theme_font_override("font", preload("res://PixelifySans.ttf"))
	drag_label.add_theme_font_size_override("font_size", 14)
	drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_label.hide()
	add_child(drag_label)
	if not game.tutorial_enabled:
		stage = Stage.READY
func expected_building() -> String:
	match stage:
		Stage.EXTRACTOR: return "drill"
		Stage.BELTS: return "belt"
		Stage.SOLAR: return "solar"
	return ""
func starter_unlocked(kind: String) -> bool:
	if not game.tutorial_enabled: return true
	match kind:
		"drill": return stage >= Stage.EXTRACTOR
		"belt": return stage >= Stage.BELTS
		"solar": return stage >= Stage.SOLAR
	return false
func _advance(next_stage: int) -> void:
	if next_stage <= stage: return
	stage = next_stage
	if stage >= Stage.SOLAR: ui_revealed.solar_unlocked = true
	menu_clicked = false
	building_clicked = false
	guide_dirty = true
	if stage >= Stage.EXTRACTOR and stage != Stage.BELTS and is_instance_valid(game.hud):
		game.selected = ""
		game.dragging = false
		game.hud.category = ""
		game.hud.hide_tray()
	if stage == Stage.READY: game._reveal_map()
	if is_instance_valid(game.hud): game.hud.refresh()
func resource_received() -> void:
	if not game.tutorial_enabled: return
	if stage == Stage.MINE and not game.discovered_resources.is_empty(): _advance(Stage.FUNDS)
	if stage == Stage.FUNDS and game.inventory.copper >= 5: _advance(Stage.EXTRACTOR)
	if stage == Stage.BELTS and extractor_connected_once: validate_designated()
func on_menu_clicked(group: String = "Structures") -> void:
	menu_clicked = true
	structures_opened_once = true
	if barrier_tree_closed and group in ["Infrastructure", "Defence"]: category_visits[group] = true
	if ready_to_unpause() and not game.paused: pause_exit_completed = true
func on_building_selected(kind: String) -> void:
	if kind == expected_building(): building_clicked = true
	if kind == "belt": guide_dirty = true
func extractor_field(cell: Vector2i) -> bool:
	return game.ores.get(cell, "") in ["copper", "iron"] and game.is_cell_visible(cell) and game.within_build_radius(cell)
func turret_target() -> Vector2i:
	return game.current_core + Vector2i(8, 0) if designated_turret == game.INVALID else designated_turret
func on_building_placed(kind: String, cell: Vector2i) -> void:
	if game.tutorial_enabled and not skipped and kind == "turret" and ammo_tutorial_stage < 3 and (ammo_tutorial_target == game.INVALID or not game.buildings.has(ammo_tutorial_target)):
		ammo_tutorial_target = cell
		ammo_tutorial_stage = maxi(1, ammo_tutorial_stage)
		refresh_ammo_guide()
	if next_core_stage in [1, 2] and next_core_target != game.INVALID and cell.distance_squared_to(next_core_target) <= game.core_build_radius * game.core_build_radius:
		next_core_stage = 3
	if kind == "drill": extractors_ever_built += 1
	if game.is_turret(kind): turrets_ever_built += 1
	guide_dirty = true
	if not game.tutorial_enabled or skipped:
		check_connection()
		return
	if onboarding_completed: return
	var correct := false
	if kind == "drill":
		if designated_extractor == game.INVALID and extractor_field(cell): designated_extractor = cell
		correct = cell == designated_extractor
	elif kind == "belt": correct = designated_path.has(cell) and cell != game.current_core
	elif game.is_turret(kind):
		correct = true
		if not turret_present(): designated_turret = cell
	if not correct: misplaced_buildings[cell] = true
	validate_designated()
func on_building_removed(cell: Vector2i) -> void:
	misplaced_buildings.erase(cell)
	guide_dirty = true
	validate_designated()
func turret_present() -> bool:
	if game.buildings.has(designated_turret) and game.is_turret(game.buildings[designated_turret].kind): return true
	for cell in game.buildings:
		if game.is_turret(game.buildings[cell].kind):
			designated_turret = cell
			misplaced_buildings.erase(cell)
			return true
	return false
func designated_structure(cell: Vector2i, kind: String) -> bool:
	return game.buildings.has(cell) and game.buildings[cell].kind == kind
func required_structures_built() -> bool:
	if designated_extractor == game.INVALID or not designated_structure(designated_extractor, "drill"): return false
	if designated_path.is_empty(): return false
	for cell in designated_path:
		if cell != game.current_core and not designated_structure(cell, "belt"): return false
	return has_extractor_connection() and turret_present()
func validate_designated() -> void:
	if not game.tutorial_enabled or skipped or onboarding_completed or stage < Stage.EXTRACTOR: return
	var next_stage := Stage.EXTRACTOR
	if designated_structure(designated_extractor, "drill"):
		next_stage = Stage.BELTS
		if not designated_path.is_empty() and has_extractor_connection():
			extractor_connected_once = true
			var belts_present := true
			for cell in designated_path:
				if cell != game.current_core and not designated_structure(cell, "belt"): belts_present = false
			if belts_present:
				if turret_present(): next_stage = Stage.READY
				elif ui_revealed.get("solar_unlocked", false) or game.affordable(game.building_cost("solar", -1, turret_target())): next_stage = Stage.SOLAR
	if next_stage > stage: _advance(next_stage)
	elif next_stage < stage:
		stage = next_stage
		menu_clicked = false
		building_clicked = false
		if game.selected != "" and not game.unlocked(game.selected): game.selected = ""
		game._reveal_map()
	if is_instance_valid(game.hud): game.hud.refresh()
func check_connection() -> void:
	if not extractor_connected_once and has_extractor_connection(): extractor_connected_once = true
	if game.tutorial_enabled and not skipped: validate_designated()
func demolition_lesson_active() -> bool:
	return not skipped and not waves_started and (not misplaced_buildings.is_empty() or (game.active_tool == "abolish" and demolish_entered))
func on_tool_changed() -> void:
	if not game.tutorial_enabled or skipped or stage < Stage.EXTRACTOR: return
	if game.active_tool == "abolish": demolish_entered = true
	elif demolish_entered:
		demolish_completed = true
		game._reveal_map()
	if is_instance_valid(game.hud): game.hud.refresh()
func start_controls_available() -> bool:
	return not game.tutorial_enabled or skipped or onboarding_completed or required_structures_built()
func pause_available() -> bool:
	return not game.tutorial_enabled or skipped or first_wave_completed or game.rollback_paused or ui_revealed.get("pause", false)
func category_should_glow(group: String) -> bool:
	return barrier_tree_closed and group in ["Infrastructure", "Defence"] and not category_visits.has(group)
func update_info_hover(dt: float, showing_info: bool, identity: String = "") -> void:
	if not barrier_tree_closed or not showing_info: return
	if info_finished():
		if ready_to_unpause() and not game.paused: pause_exit_completed = true
		return
	if first_wave_completed and not game.paused: return
	info_hover_time = minf(2.0, info_hover_time + dt)
	if identity != "": inspected_things[identity] = true
	if ready_to_unpause() and not game.paused: pause_exit_completed = true

func info_finished() -> bool:
	return barrier_tree_closed and (info_hover_time >= 2.0 or inspected_things.size() >= 3)

func ready_to_unpause() -> bool:
	return info_finished() and not category_should_glow("Infrastructure") and not category_should_glow("Defence")

func on_game_resumed() -> void:
	if ready_to_unpause(): pause_exit_completed = true

func prewave_recovery_needed() -> bool:
	if waves_started or skipped or not game.tutorial_enabled or stage < Stage.EXTRACTOR or has_extractor_connection(): return false
	if not designated_structure(designated_extractor, "drill"): return not game.affordable(game.building_cost("drill"))
	if guide_dirty: refresh_guide()
	var owned: int = game.owned_building_counts().get("belt", 0)
	var cost := 0
	var missing := 0
	for cell in guide_path:
		if cell == game.current_core or designated_structure(cell, "belt"): continue
		cost += int(game.building_cost("belt", owned + missing).get("copper", 0))
		missing += 1
	return game.inventory.copper < cost

func shortcut_lines() -> Array[String]:
	if stage >= Stage.EXTRACTOR: introduced_shortcuts.RMB = true
	if demolish_entered or demolish_completed or demolition_lesson_active(): introduced_shortcuts.X = true
	if waves_started:
		introduced_shortcuts.Z = true
		introduced_shortcuts.Q = true
		introduced_shortcuts.X = true
	if first_wave_completed: introduced_shortcuts.Space = true
	if central_message() == "Press E to speed up time." or speed_toggled: introduced_shortcuts.E = true
	if barrier_tree_closed: introduced_shortcuts.Alt = true
	var lines: Array[String] = ["Left click — Mine / Build", "Middle Drag - Copy Paste"]
	if introduced_shortcuts.has("RMB"): lines.append("Right click — Deselect")
	if introduced_shortcuts.has("X"): lines.append("X — Demolish")
	if introduced_shortcuts.has("Z"): lines.append("Z — Clear conveyor")
	if introduced_shortcuts.has("Q"): lines.append("Q — Start wave early")
	if introduced_shortcuts.has("Space"): lines.append("Space — Pause / Resume")
	if introduced_shortcuts.has("E"): lines.append("E — Speed")
	if introduced_shortcuts.has("Alt"): lines.append("Alt - Mouseover for info")
	return lines

func scraps_should_glow() -> bool:
	return central_message() == "Mouse over the scraps to collect."

func bottom_message() -> String:
	return ""

func connection_cost_remaining() -> int:
	if stage != Stage.BELTS: return 0
	if guide_dirty: refresh_guide()
	var needed := 0
	for cell in guide_path:
		if cell != game.current_core and not designated_structure(cell, "belt"): needed += 1
	return needed

func central_message() -> String:
	var frontier_message := next_core_message()
	if frontier_message != "": return frontier_message
	if ammo_tutorial_stage in [1, 2] and game.buildings.has(ammo_tutorial_target): return "Some turrets require ammo.\nHold Alt over a turret to see its ammo type"
	if demolition_lesson_active():
		if game.active_tool == "abolish":
			return "Presss X to leave demolish mode." if misplaced_buildings.is_empty() else "Press on buildings to demolish them."
		return "Press X to enter demolish mode"
	if not tech_opened and not pause_exit_completed and first_wave_completed and not ready_to_unpause() and not game.paused:
		return "Press space to pause and build." if not paused_once else "Press space to pause"
	if ready_to_unpause() and not pause_exit_completed and game.paused: return "Press space to unpause"
	if stage < Stage.EXTRACTOR: return "Press and hold on an ore deposit."
	if prewave_recovery_needed(): return "Right click to deselect" if game.selected != "" else "Mine some more ore."
	if stage == Stage.BELTS and extractor_connected_once and has_extractor_connection() and not ui_revealed.get("solar_unlocked", false): return "Mine some more ore."
	if game.wave >= 5 and not game.paused and not speed_toggled: return "Press E to speed up time."
	if not pause_exit_completed and paused_once and first_wave_completed:
		if collected_tutorial_scrap < game.Content.BARRIER_UNLOCK_SCRAP and not game.scraps.is_empty(): return "Mouse over the scraps to collect."
		if barrier_tree_closed and info_hover_time < 2.0 and inspected_things.size() < 3:
			return "Hold alt while mousing over something for info."
	if waiting_for_copper(): return "Wait for enough copper extraction."
	return ""
func on_ammo_inspected() -> void:
	if ammo_tutorial_stage == 1:
		ammo_tutorial_stage = 2
		game.saves.remember_learning()
func refresh_ammo_guide() -> void:
	ammo_guide_extractor = game.INVALID
	if ammo_tutorial_stage not in [1, 2] or not game.buildings.has(ammo_tutorial_target):
		ammo_guide_path.clear()
		ammo_guide_signature = -1
		return
	var drill: Vector2i = game.INVALID
	var nearest := INF
	for cell in game.buildings:
		if game.buildings[cell].kind != "drill" or game.ores.get(cell) != "iron": continue
		if slugger_supply_connected(cell):
			ammo_tutorial_stage = 3
			game.saves.remember_learning()
			ammo_guide_path.clear()
			return
		var distance: float = cell.distance_squared_to(ammo_tutorial_target)
		if distance < nearest:
			nearest = distance
			drill = cell
	if drill == game.INVALID:
		for cell in game.ores:
			if game.ores[cell] != "iron" or not game.within_build_radius(cell) or not game.is_cell_visible(cell): continue
			if game.occupied.has(cell) or game.rocks.has(cell): continue
			var distance: float = cell.distance_squared_to(ammo_tutorial_target)
			if distance < nearest:
				nearest = distance
				drill = cell
		ammo_guide_extractor = drill
	if drill == game.INVALID:
		ammo_guide_path.clear()
		ammo_guide_signature = -1
		return
	var layout := guide_layout_signature()
	var next_signature := hash([layout, drill, ammo_tutorial_target])
	if next_signature == ammo_guide_signature: return
	ammo_guide_signature = next_signature
	ammo_guide_path.clear()
	prepare_guide_grid(layout)
	var temporary: Dictionary = {drill: guide_grid.is_point_solid(drill)}
	guide_grid.set_point_solid(drill, false)
	for y in game.footprint_size("turret"):
		for x in game.footprint_size("turret"):
			var cell := ammo_tutorial_target + Vector2i(x, y)
			temporary[cell] = guide_grid.is_point_solid(cell)
			guide_grid.set_point_solid(cell, false)
	# Search once from the extractor, then stop at the first turret footprint tile.
	ammo_path_queries += 1
	var path := guide_grid.get_id_path(drill, ammo_tutorial_target)
	# An adjacent extractor still needs a visible belt route for this lesson.
	if path.size() > 1 and game.anchor_at(path[1]) == ammo_tutorial_target:
		guide_grid.set_point_solid(drill, true)
		var best: Array[Vector2i] = []
		for direction in game.DIRS:
			var neighbor: Vector2i = drill + direction
			if not guide_grid.region.has_point(neighbor) or game.anchor_at(neighbor) == ammo_tutorial_target: continue
			if guide_grid.is_point_solid(neighbor): continue
			ammo_path_queries += 1
			var candidate := guide_grid.get_id_path(neighbor, ammo_tutorial_target)
			if candidate.size() > 1 and (best.is_empty() or candidate.size() < best.size()): best.assign(candidate)
		path.clear()
		if not best.is_empty():
			path.append(drill)
			path.append_array(best)
	for index in range(1, path.size()):
		ammo_guide_path.append(path[index])
		if game.anchor_at(path[index]) == ammo_tutorial_target: break
	for cell in temporary: guide_grid.set_point_solid(cell, temporary[cell])
func supply_connected(drill: Vector2i, target: Vector2i, require_conveyor: bool = false) -> bool:
	var pending: Array[Vector2i] = []
	for direction in 4:
		var neighbor: Vector2i = drill + game.DIRS[direction]
		if not require_conveyor and game.anchor_at(neighbor) == target: return true
	for direction in game.splitter_outputs(drill): pending.append(drill + game.DIRS[direction])
	var seen: Dictionary = {}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if game.anchor_at(cell) == target: return true
		if seen.has(cell): continue
		seen[cell] = true
		var b: Dictionary = game.building_at(cell)
		if b.is_empty(): continue
		if b.kind == "belt": pending.append(game.output_target(cell, b))
		elif b.kind == "splitter":
			for direction in game.splitter_outputs(cell): pending.append(cell + game.DIRS[direction])
	return false

func on_new_core(cell: Vector2i) -> void:
	if not game.tutorial_enabled or skipped or game.cores.size() != 2 or next_core_stage >= 3: return
	next_core_target = cell
	next_core_stage = maxi(1, next_core_stage)
func next_core_message() -> String:
	if skipped or next_core_stage not in [1, 2] or not game.buildings.has(next_core_target): return ""
	var point: Vector2 = game.get_canvas_transform() * game.cell_center(next_core_target)
	var dimensions: Vector2 = game.get_viewport_rect().size
	var visible := Rect2(Vector2.ZERO, dimensions - Vector2(0, 72)).has_point(point)
	var inset := minf(game.TILE * game.camera.zoom.x * 7, dimensions.x * 0.4)
	var comfortably_visible: bool = visible and point.x >= inset and point.x <= dimensions.x - inset
	if next_core_stage == 1:
		if comfortably_visible: next_core_stage = 2
		else: return "WASD to move camera.\nMove Right."
	return "This is your next core to defend." if comfortably_visible else "Find your next core."

func on_scrap_collected(amount: int) -> void:
	collected_tutorial_scrap += amount
	if paused_once and collected_tutorial_scrap >= game.Content.BARRIER_UNLOCK_SCRAP: tech_available = true
	if is_instance_valid(game.hud): game.hud.refresh()

func on_tree_closed() -> void:
	if game.researched.has("barriers"): barrier_tree_closed = true

func waiting_for_copper() -> bool:
	if stage != Stage.SOLAR or game.selected != "solar": return false
	var kind := expected_building()
	return kind != "" and game.inventory.copper < game.building_cost(kind).get("copper", 0)
func has_extractor_connection() -> bool:
	for cell in game.buildings:
		if designated_extractor != game.INVALID and cell != designated_extractor and not skipped: continue
		if game.buildings[cell].kind != "drill": continue
		for direction in game.splitter_outputs(cell):
			var cursor: Vector2i = cell + game.DIRS[direction]
			var seen: Dictionary = {}
			while game.occupied.has(cursor) and not seen.has(cursor):
				seen[cursor] = true
				var anchor: Vector2i = game.anchor_at(cursor)
				var b: Dictionary = game.buildings[anchor]
				if b.kind == "core": return true
				if b.kind != "belt": break
				cursor = game.output_target(anchor, b)
	return false
func on_wave_started() -> void:
	waves_started = true
	onboarding_completed = true
func on_wave_completed(number: int) -> void:
	if number >= 1: first_wave_completed = true
	if not game.tutorial_enabled and number >= 4: tech_available = true
func on_tech_opened() -> void:
	tech_opened = true
func storage_hint_active() -> bool:
	if game.wave >= 4 and game.inventory.copper >= game.material_capacity("copper") and not game.researched.has("copper_storage"):
		ui_revealed.copper_storage_hint = true
	return ui_revealed.get("copper_storage_hint", false) and not game.researched.has("copper_storage")
func storage_hint_tech() -> String:
	if not storage_hint_active(): return ""
	return "turret_range" if not game.researched.has("turret_range") else "copper_storage"
func slugger_rewind_hint_active() -> bool:
	return ui_revealed.get("slugger_rewind_hint", false) and game.cores.size() == 2 and not game.researched.has("weapons") and game.researched.has(game.TECH.weapons.parent) and game.affordable(game.TECH.weapons.cost)
func menu_should_glow() -> bool:
	if stage == Stage.BELTS and extractor_connected_once and has_extractor_connection(): return false
	if stage == Stage.BELTS and game.inventory.copper < connection_cost_remaining(): return false
	return game.tutorial_enabled and stage in [Stage.EXTRACTOR, Stage.BELTS, Stage.SOLAR] and not menu_clicked
func building_should_glow(kind: String) -> bool:
	if kind == "belt" and extractor_connected_once and has_extractor_connection(): return false
	if kind == "belt" and game.inventory.copper < connection_cost_remaining(): return false
	return game.tutorial_enabled and expected_building() == kind and not building_clicked
func skip_to_ready() -> void:
	skipped = true
	next_core_stage = 3
	ammo_tutorial_stage = 3
	stage = Stage.READY
	menu_clicked = true
	building_clicked = true
	guide_path.clear()
	queue_redraw()
	game.selected = ""
	game.dragging = false
	game._reveal_map()
	if is_instance_valid(game.hud):
		game.hud.category = ""
		game.hud.hide_tray()
		game.hud.refresh()
func find_guide_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not game.in_bounds(start) or not game.in_bounds(goal): return []
	prepare_guide_grid(guide_layout_signature())
	if guide_grid.is_point_solid(start): return []
	var solid := guide_grid.is_point_solid(goal)
	guide_grid.set_point_solid(goal, false)
	var path := guide_grid.get_id_path(start, goal)
	guide_grid.set_point_solid(goal, solid)
	return path
func guide_layout_signature() -> int:
	return hash([game.enemy_navigation.signature, game.rocks, game.ores, game.cores, game.visible_cells, game.fog_disabled, game.core_build_radius])
func prepare_guide_grid(layout: int) -> void:
	if guide_grid_signature == layout: return
	guide_grid_signature = layout
	guide_grid_builds += 1
	guide_grid.clear()
	guide_grid.region = Rect2i(0, 0, game.WIDTH, game.HEIGHT)
	guide_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	guide_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	guide_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	guide_grid.update()
	guide_grid.fill_solid_region(guide_grid.region, true)
	var radius := ceili(game.core_build_radius)
	for core in game.cores:
		for y in range(maxi(0, core.y - radius), mini(game.HEIGHT, core.y + radius + 1)):
			for x in range(maxi(0, core.x - radius), mini(game.WIDTH, core.x + radius + 1)):
				var cell := Vector2i(x, y)
				if cell.distance_squared_to(core) > game.core_build_radius * game.core_build_radius: continue
				var blocked: bool = game.rocks.has(cell) or (not game.fog_disabled and not game.visible_cells.has(cell))
				var anchor: Vector2i = game.occupied.get(cell, game.INVALID)
				if anchor != game.INVALID and game.buildings[anchor].kind != "belt": blocked = true
				guide_grid.set_point_solid(cell, blocked)
				guide_grid.set_point_weight_scale(cell, 4.0 if game.ores.has(cell) else 1.0)
func refresh_guide() -> void:
	guide_dirty = false
	guide_path.clear()
	if stage != Stage.BELTS: return
	if not designated_path.is_empty():
		guide_path.assign(designated_path)
		return
	var closest := INF
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.kind != "drill": continue
		var distance: float = cell.distance_to(game.current_core)
		if distance < closest:
			var best: Array[Vector2i] = []
			var best_cost := INF
			for direction in 4:
				var candidate := find_guide_path(cell + game.DIRS[direction], game.current_core)
				var cost := 0.0
				for tile in candidate: cost += 4 if game.ores.has(tile) else 1
				if not candidate.is_empty() and cost < best_cost:
					best = candidate
					best_cost = cost
			if not best.is_empty():
				closest = distance
				guide_path = best
				if game.tutorial_enabled and not skipped: designated_path.assign(best)
func _process(dt: float) -> void:
	if not game.tutorial_enabled or skipped: return
	ammo_guide_clock += dt
	if ammo_guide_clock >= 0.4:
		ammo_guide_clock = 0.0
		refresh_ammo_guide()
	poll_clock += dt
	if poll_clock >= 0.12:
		poll_clock = 0
		resource_received()
		check_connection()
	if guide_dirty and stage == Stage.BELTS and game.selected == "belt": refresh_guide()
	queue_redraw()
func _draw() -> void:
	drag_label.hide()
	if not game.tutorial_enabled or skipped: return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	if ammo_guide_extractor != game.INVALID and not game.occupied.has(ammo_guide_extractor):
		draw_texture_rect(game.textures.drill, Rect2(Vector2(ammo_guide_extractor * game.TILE), Vector2.ONE * game.TILE), false, Color(1, 0.9, 0.6, 0.35 + pulse * 0.2))
		glowing_tile(ammo_guide_extractor, Color("ffe494"), pulse)
	for index in ammo_guide_path.size():
		var cell: Vector2i = ammo_guide_path[index]
		if cell == ammo_tutorial_target or game.occupied.has(cell): continue
		var direction: int = game.direction_for(ammo_guide_path[mini(index + 1, ammo_guide_path.size() - 1)] - cell)
		draw_set_transform(game.cell_center(cell), direction * PI / 2)
		draw_texture_rect(game.textures.belt, Rect2(-16, -16, 32, 32), false, Color(1, 0.9, 0.6, 0.35 + pulse * 0.2))
		draw_set_transform(Vector2.ZERO)
		glowing_tile(cell, Color("ffe494"), pulse)
	if game.selected == "drill" and stage == Stage.EXTRACTOR:
		for cell in game.ores:
			if designated_extractor != game.INVALID and cell != designated_extractor: continue
			if game.ores[cell] not in ["copper", "iron"] or not game.is_cell_visible(cell) or game.occupied.has(cell) or game.rocks.has(cell): continue
			glowing_tile(cell, game.RESOURCE_COLORS[game.ores[cell]], pulse)
	if stage == Stage.BELTS and game.selected == "belt" and not has_extractor_connection():
		for cell in guide_path: glowing_tile(cell, Color("f3ded5"), pulse)
		if not guide_path.is_empty():
			drag_label.position = game.cell_center(guide_path[0]) + Vector2(-14, -12)
			drag_label.show()
	if stage == Stage.SOLAR and game.selected == "solar":
		glowing_tile(turret_target(), Color("f3ded5"), pulse)
	if not onboarding_completed:
		for cell in misplaced_buildings:
			if game.buildings.has(cell): glowing_tile(cell, Color("ff4444"), pulse)
func glowing_tile(cell: Vector2i, color: Color, pulse: float) -> void:
	var rect := Rect2(Vector2(cell * game.TILE) + Vector2.ONE, Vector2.ONE * (game.TILE - 2))
	draw_rect(rect.grow(3), Color(color, 0.025 + pulse * 0.045))
	draw_rect(rect, Color(color, 0.04 + pulse * 0.10))
	draw_rect(rect, Color(color, 0.45 + pulse * 0.5), false, line_width())








func line_width() -> float:
	return preload("res://scripts/drawing_style.gd").stroke(self)


func slugger_supply_connected(drill: Vector2i) -> bool:
	var pending: Array[Vector2i] = []
	for direction in game.splitter_outputs(drill): pending.append(drill + game.DIRS[direction])
	var seen: Dictionary = {}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if seen.has(cell): continue
		seen[cell] = true
		var building: Dictionary = game.building_at(cell)
		if building.is_empty(): continue
		if building.kind == "turret": return true
		if building.kind == "belt": pending.append(game.output_target(cell, building))
		elif building.kind == "splitter":
			for direction in game.splitter_outputs(cell): pending.append(cell + game.DIRS[direction])
	return false


