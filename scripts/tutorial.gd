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
var introduced_shortcuts: Dictionary = {"LMB": true}
func _ready() -> void:
	z_index = 210
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
				next_stage = Stage.READY if turret_present() else Stage.SOLAR
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
	var lines: Array[String] = ["Left click — Mine / Build"]
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
	if demolition_lesson_active():
		if game.active_tool == "abolish":
			return "Presss X to leave demolish mode." if misplaced_buildings.is_empty() else "Press on buildings to demolish them."
		return "Press X to enter demolish mode"
	if not pause_exit_completed and first_wave_completed and not ready_to_unpause() and not game.paused:
		return "Press space to pause and build." if not paused_once else "Press space to pause"
	if ready_to_unpause() and not pause_exit_completed and game.paused: return "Press space to unpause"
	if stage < Stage.EXTRACTOR: return "Press and hold on an ore deposit."
	if prewave_recovery_needed(): return "Right click to deselect" if game.selected != "" else "Mine some more ore."
	if game.wave >= 5 and not game.paused and not speed_toggled: return "Press E to speed up time."
	if not pause_exit_completed and paused_once and first_wave_completed:
		if collected_tutorial_scrap < game.Content.BARRIER_UNLOCK_SCRAP and not game.scraps.is_empty(): return "Mouse over the scraps to collect."
		if barrier_tree_closed and info_hover_time < 2.0 and inspected_things.size() < 3:
			return "Hold alt while mousing over something for info."
	if waiting_for_copper(): return "Wait for enough copper extraction."
	return ""

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
func menu_should_glow() -> bool:
	if stage == Stage.BELTS and game.inventory.copper < connection_cost_remaining(): return false
	return game.tutorial_enabled and stage in [Stage.EXTRACTOR, Stage.BELTS, Stage.SOLAR] and not menu_clicked
func building_should_glow(kind: String) -> bool:
	if kind == "belt" and game.inventory.copper < connection_cost_remaining(): return false
	return game.tutorial_enabled and expected_building() == kind and not building_clicked
func skip_to_ready() -> void:
	skipped = true
	next_core_stage = 3
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
	var search := AStarGrid2D.new()
	search.region = Rect2i(0, 0, game.WIDTH, game.HEIGHT)
	search.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	search.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	search.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	search.update()
	for y in game.HEIGHT:
		for x in game.WIDTH:
			var cell := Vector2i(x, y)
			var occupied: Dictionary = game.building_at(cell)
			var blocked: bool = game.rocks.has(cell) or not game.within_build_radius(cell) or not game.is_cell_visible(cell)
			if not occupied.is_empty() and occupied.kind not in ["belt", "core"]: blocked = true
			search.set_point_solid(cell, blocked)
			search.set_point_weight_scale(cell, 4.0 if game.ores.has(cell) else 1.0)
	search.set_point_solid(goal, false)
	if search.is_point_solid(start): return []
	return search.get_id_path(start, goal)
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
	poll_clock += dt
	if poll_clock >= 0.12:
		poll_clock = 0
		resource_received()
		check_connection()
	if guide_dirty and stage == Stage.BELTS and game.selected == "belt": refresh_guide()
	queue_redraw()
func _draw() -> void:
	if not game.tutorial_enabled or skipped: return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	if game.selected == "drill" and stage == Stage.EXTRACTOR:
		for cell in game.ores:
			if designated_extractor != game.INVALID and cell != designated_extractor: continue
			if game.ores[cell] not in ["copper", "iron"] or not game.is_cell_visible(cell) or game.occupied.has(cell) or game.rocks.has(cell): continue
			glowing_tile(cell, game.RESOURCE_COLORS[game.ores[cell]], pulse)
	if stage == Stage.BELTS and game.selected == "belt":
		for cell in guide_path: glowing_tile(cell, Color("f3ded5"), pulse)
		if not guide_path.is_empty():
			draw_string(ThemeDB.fallback_font, game.cell_center(guide_path[0]) + Vector2(-14, 5), "Drag", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0df"))
	if stage == Stage.SOLAR and game.selected == "solar":
		glowing_tile(turret_target(), Color("f3ded5"), pulse)
	if not onboarding_completed:
		for cell in misplaced_buildings:
			if game.buildings.has(cell): glowing_tile(cell, Color("ff4444"), pulse)
func glowing_tile(cell: Vector2i, color: Color, pulse: float) -> void:
	var rect := Rect2(Vector2(cell * game.TILE) + Vector2.ONE, Vector2.ONE * (game.TILE - 2))
	draw_rect(rect.grow(3), Color(color, 0.025 + pulse * 0.045))
	draw_rect(rect, Color(color, 0.04 + pulse * 0.10))
	draw_rect(rect, Color(color, 0.45 + pulse * 0.5), false, 1.5)



