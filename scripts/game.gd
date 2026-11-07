extends Node2D
const Content = preload("res://scripts/content.gd")
const ConveyorMotion = preload("res://scripts/conveyor_motion.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const BUILDINGS = Content.BUILDINGS
var TECH: Dictionary = Content.TECH.duplicate(true)
const TILE := 32
const ZOOM_LEVELS := [0.5, 1.0, 2.0]
const WIDTH := 112
const HEIGHT := 80
const CORE := Vector2i(23, 22)
const INVALID := Vector2i(-1000, -1000)
const DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const FLOW_INTERVAL := ConveyorMotion.TRAVEL_SECONDS
const TUNNEL_MAX := 10
const TEAM_COLORS := {"red": Color("f16e64"), "green": Color("83d780"), "blue": Color("7aa7f0")}
const STRONG_AGAINST := {"red": "green", "green": "blue", "blue": "red"}
const COPPER := Color("e7a468")
const TEAL := Color("edb183")
const RED := Color("ed7968")
const RESOURCE_COLORS := {"copper": Color("e7a468"), "iron": Color("b8ced6"), "verdite": Color("8ed878"), "alloy": Color("bb9be8")}
var buildings: Dictionary = {}
var occupied: Dictionary = {}
var ores: Dictionary = {}
var rocks: Dictionary = {}
var inventory := {"copper": 0, "iron": 0, "verdite": 0, "alloy": 0, "scrap": 0}
var researched: Dictionary = {}
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var core_health := 2000.0
var wave := 0
var spawn_remaining := 0
var spawn_timer := 0.0
var kills := 0
var delivered := 0
var elapsed := 0.0
var speed := 1
var paused := false
var lost := false
var won := false
var victory_shown := false
var selected := ""
var active_tool := "build"
var build_direction := 0
var hover_cell := INVALID
var inspected := INVALID
var dragging := false
var middle_blueprint_drag := false
var redirecting_belt := false
var drag_started_on_belt := false
var drag_initial_receiver := INVALID
var demolitions: Array[Dictionary] = []
var right_demolishing := false
var right_last := INVALID
var drag_start := INVALID
var drag_last := INVALID
var drag_first_direction := -1
var drag_placed: Dictionary = {}
var tunnel_pending := INVALID
var pending_crossing: Dictionary = {}
var enemy_navigation = preload("res://scripts/enemy_navigation.gd").new()
var enemy_separation = preload("res://scripts/enemy_separation.gd").new()
var tunnel_pending_direction := -1
var drag_blocked := false
var blueprint: Array[Dictionary] = []
var blueprint_size := Vector2i.ZERO
var blueprint_end := INVALID
var notice := ""
var notice_time := 0.0
var rng := RandomNumberGenerator.new()
var camera: Camera2D
var hud: CanvasLayer
var terrain: Node2D
var textures: Dictionary = {}
var ui_textures: Dictionary = {}
var sprite_raster_sets: Dictionary = {}
var raster_tile_size := 16
var hud_timer := 0.0
var radial_pending := INVALID
var radial_kind := ""
var audio: Node2D
var manual_mining_cell := INVALID
var manual_mining_progress := 0.0
@export var tutorial_enabled := true
@export var core_build_radius := 20.0
@export var separate_build_categories := false
@export var base_copper_capacity := 40
var tutorial: Node2D
var discovered_resources: Dictionary = {}
var debug_unlock_step := 0
var saves: RefCounted
var debug_keys: Dictionary = {}
var debug_resource_capacity := false
var enemy_info_counter := 0
var pause_grid: Node2D
var rollback_paused := false
var capture_effect: Node2D
var wave_warp_active := false
var wave_warp_elapsed := 0.0
var wave_warp_start_timer := 0.0

func _ready() -> void:
	var sprite_material := ShaderMaterial.new()
	sprite_material.shader = preload("res://scripts/crisp_sprite.gdshader")
	material = sprite_material
	_add_color_tech()
	saves = preload("res://scripts/wave_saves.gd").new(self)
	rng.seed = 42017
	audio = Node2D.new()
	audio.set_script(load("res://scripts/game_audio.gd"))
	add_child(audio)
	tutorial = Node2D.new()
	tutorial.set_script(load("res://scripts/tutorial.gd"))
	tutorial.game = self
	add_child(tutorial)
	current_core = Vector2i((get_node("Level/CoreSpawn").position / TILE).floor())
	cores.clear()
	cores.append(current_core)
	wave_timer = initial_wave_delay
	_init_spawners()
	for resolution in [16, 32, 64]: sprite_rasters(resolution)
	ui_textures = sprite_rasters(32)
	textures = sprite_rasters(raster_tile_size)
	_load_level()
	_starter_factory()
	terrain = get_node("Level/Ground")
	fog = Node2D.new()
	fog.set_script(load("res://scripts/fog.gd"))
	fog.game = self
	fog.material = material
	fog.z_index = 200
	add_child(fog)
	camera = Camera2D.new()
	camera.position = cell_center(current_core) + Vector2(170, -35)
	set_camera_zoom(ZOOM_LEVELS[2])
	add_child(camera)
	pause_grid = Node2D.new()
	pause_grid.set_script(load("res://scripts/pause_grid.gd"))
	pause_grid.game = self
	pause_grid.material = null
	pause_grid.z_index = 205
	add_child(pause_grid)
	var outlines := Node2D.new()
	outlines.set_script(preload("res://scripts/tower_outlines.gd"))
	outlines.game = self
	outlines.z_index = 201
	add_child(outlines)
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.game = self
	add_child(hud)
	capture_effect = preload("res://scripts/core_capture.gd").new()
	capture_effect.game = self
	add_child(capture_effect)
	saves.initial_checkpoint = saves.snapshot().duplicate(true)
	if not OS.get_cmdline_args().has("--script") and not saves.entries.is_empty(): hud.save_browser.call_deferred("show_continue")

func sprite_rasters(resolution: int) -> Dictionary:
	if sprite_raster_sets.has(resolution): return sprite_raster_sets[resolution]
	var result: Dictionary = {}
	for kind in ["belt", "splitter", "drill", "solar", "turret", "wall", "core", "barrel", "repeater", "cannon", "healer", "forge", "tunnel_entry", "tunnel_exit", "belt_corner", "belt_dark", "belt_corner_dark", "core_inactive", "wall_iron"]:
		var size: int = roundi(44.0 * resolution / TILE) if kind in ["core", "core_inactive"] else resolution * (BUILDINGS[kind].size if BUILDINGS.has(kind) else 1)
		result[kind] = PixelArt.texture(load("res://assets/buildings/%s.svg" % kind), Vector2i.ONE * size)
	for kind in Content.ENEMY_TYPES:
		for suffix in ["", "_body", "_gun"]: result[kind + suffix] = PixelArt.texture(load("res://assets/units/%s%s.svg" % [kind, suffix]), Vector2i.ONE * resolution)
	for part in ["solar_base", "solar_gun"]: result[part] = PixelArt.texture(load("res://assets/buildings/%s.svg" % part), Vector2i.ONE * resolution)
	for mask in [7, 11, 13, 14, 15]:
		for suffix in ["", "_dark"]:
			var key := "belt_junction_%d%s" % [mask, suffix]
			result[key] = PixelArt.texture(load("res://assets/buildings/%s.svg" % key), Vector2i.ONE * resolution)
	for kind in Content.RESOURCES: result[kind + "_item"] = PixelArt.texture(load("res://assets/items/%s.svg" % kind), Vector2i.ONE * resolution)
	result.speed3 = PixelArt.texture(load("res://assets/ui/speed3.svg"), Vector2i.ONE * resolution)
	for value in [5, 20, 50, 200, 1000]: result["scrap_%d_item" % value] = PixelArt.texture(load("res://assets/items/scrap_%d.svg" % value), Vector2i.ONE * resolution)
	for kind in BUILDINGS:
		if BUILDINGS[kind].has("stores"): result[kind] = PixelArt.texture(load("res://assets/buildings/%s.svg" % kind), Vector2i.ONE * resolution * BUILDINGS[kind].size)
	sprite_raster_sets[resolution] = result
	return result
func configure_tile_rasters(resolution: int) -> void:
	for layer in get_node("Level").get_children():
		if layer is TileMapLayer:
			layer.material = material
			if not layer.has_meta("runtime_rasters"):
				layer.tile_set = layer.tile_set.duplicate(true)
				layer.set_meta("runtime_rasters", true)
			layer.tile_set.tile_size = Vector2i.ONE * resolution
			layer.scale = Vector2.ONE * float(TILE) / resolution
			for id in layer.tile_set.get_source_count():
				var source = layer.tile_set.get_source(layer.tile_set.get_source_id(id))
				if source is TileSetAtlasSource:
					for density in [16, 32, 64]: PixelArt.texture(source.texture, Vector2i.ONE * density)
					var picture := PixelArt.texture(source.texture, Vector2i.ONE * resolution)
					if resolution < source.texture_region_size.x: source.texture_region_size = Vector2i.ONE * resolution
					source.texture = picture
					source.texture_region_size = Vector2i.ONE * resolution
func _load_level() -> void:
	rocks.clear()
	ores.clear()
	configure_tile_rasters(raster_tile_size)
	randomize_rock_tiles()
	var rock_layer: TileMapLayer = get_node("Level/RockWalls")
	var ore_layer: TileMapLayer = get_node("Level/OreDeposits")
	for cell in rock_layer.get_used_cells(): rocks[cell] = true
	for cell in ore_layer.get_used_cells():
		var data := ore_layer.get_cell_tile_data(cell)
		if data != null:
			var resource: String = data.get_custom_data("resource")
			if resource in ["copper", "iron", "verdite"]: ores[cell] = resource
func _starter_factory() -> void:
	_add_building(current_core, "core", 0)
func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2.ONE * TILE / 2.0
func footprint_size(kind: String) -> int:
	return 1 if kind == "core" else int(BUILDINGS[kind].size)
func building_center(cell: Vector2i) -> Vector2:
	if not buildings.has(cell): return cell_center(cell)
	if not building_centers.has(cell): building_centers[cell] = Vector2(cell * TILE) + Vector2.ONE * TILE * footprint_size(buildings[cell].kind) / 2.0
	return building_centers[cell]
func anchor_at(cell: Vector2i) -> Vector2i:
	return occupied.get(cell, INVALID)
func building_at(cell: Vector2i) -> Dictionary:
	return buildings.get(anchor_at(cell), {})
func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT
func is_turret(kind: String) -> bool:
	return kind in ["solar", "turret", "repeater", "cannon"]
func wave_active() -> bool:
	return spawn_remaining > 0 or not enemies.is_empty()
func wave_color(number: int) -> String:
	return current_wave_color if number == wave and wave_active() else next_wave_color
func affinity_multiplier(attacker: String, defender: String) -> float:
	if attacker == defender: return 1.0
	return 2.0 if STRONG_AGAINST.get(attacker) == defender else 0.5
func unlocked(kind: String) -> bool:
	if not BUILDINGS.has(kind): return false
	if kind in ["belt", "drill", "solar"]: return tutorial.starter_unlocked(kind)
	var technology: String = BUILDINGS[kind].tech
	return technology != "" and researched.has(technology)
func affordable(cost: Dictionary) -> bool:
	for resource in cost:
		if inventory.get(resource, 0) < cost[resource]: return false
	return true
func missing_resources(cost: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for resource in Content.RESOURCES:
		if inventory[resource] < cost.get(resource, 0): result.append("Repair alloy" if resource == "alloy" else resource.capitalize())
	return result
func report_shortage(cost: Dictionary, world_cell: Vector2i = INVALID) -> void:
	var missing := missing_resources(cost)
	if not missing.is_empty() and is_instance_valid(hud): hud.show_shortage("Not enough " + ", ".join(missing) + "...", world_cell)
func play_sound(id: String, position_in_world: Vector2 = Vector2.INF) -> void:
	if is_instance_valid(audio): audio.play(id, position_in_world)
func toggle_audio() -> void:
	if is_instance_valid(audio):
		audio.toggle_mute()
		if is_instance_valid(hud): hud.refresh()
func pay(cost: Dictionary) -> void:
	for resource in cost: inventory[resource] -= cost[resource]

func research(id: String, free: bool = false) -> bool:
	if lost or not TECH.has(id) or researched.has(id): return false
	var data: Dictionary = TECH[id]
	if not free and data.parent != "" and not researched.has(data.parent): return false
	if not free and not affordable(data.cost): return false
	if not free: pay(data.cost)
	researched[id] = true
	if id == "weapons": researched.turret_red = true
	if id == "slugger_shield":
		for building in buildings.values():
			if building.kind == "turret": building.shield = true
	if id == "iron_barriers":
		for b in buildings.values():
			if b.kind == "wall":
				b.hp *= 3.0
				b.max_hp *= 3.0
	if id == "armor":
		for b in buildings.values():
			var extra: float = b.max_hp * 0.25
			b.max_hp += extra
			b.hp += extra
		core_health = buildings[current_core].hp
	toast("Research complete: " + data.name)
	if not free: play_sound("research")
	return true

func _add_building(cell: Vector2i, kind: String, direction: int) -> void:
	building_centers.erase(cell)
	if kind == "drill": direction = 0
	var health: float = (2000.0 if kind == "core" else float(BUILDINGS[kind].hp)) * (1.25 if researched.has("armor") else 1.0)
	if kind == "wall" and researched.has("iron_barriers"): health *= 3.0
	buildings[cell] = {"kind": kind, "dir": direction, "input_dir": direction, "hp": health, "max_hp": health, "item": "", "travel": 0.0, "progress": 0.0, "cooldown": 0.0, "ammo": 0, "aim": 0.0, "flash": 0.0, "buffer": {"copper": 0, "iron": 0, "verdite": 0, "alloy": 0}, "paid_cost": {}, "tunnel_role": "", "tunnel_pair": INVALID, "pulse": 0.0}
	buildings[cell].ammo = turret_ammo_capacity(kind) if is_turret(kind) and not BUILDINGS[kind].get("ammo_free", false) else 0
	buildings[cell].next_output = direction
	buildings[cell].shield = kind == "turret" and researched.has("slugger_shield")
	buildings[cell].pending = kind not in ["core", "belt"] and (not enemies.is_empty() or spawn_remaining > 0)
	if buildings[cell].pending: has_pending_construction = true
	buildings[cell].route_dir = -1
	buildings[cell].color = "red"
	if kind != "core": placement_counts[kind] = placement_counts.get(kind, 0) + 1
	for y in footprint_size(kind):
		for x in footprint_size(kind): occupied[cell + Vector2i(x, y)] = cell
	if kind != "core":
		for core in cores:
			if buildings.has(core) and cell.distance_squared_to(core) <= core_build_radius * core_build_radius: buildings[core].progress = 1.0
	if not buildings[cell].pending: enemy_navigation.invalidate(self)

func valid_site(cell: Vector2i, kind: String) -> bool:
	if not unlocked(kind): return false
	for y in footprint_size(kind):
		for x in footprint_size(kind):
			var c := cell + Vector2i(x, y)
			if not in_bounds(c) or not is_cell_visible(c) or not within_build_radius(c) or rocks.has(c): return false
			if occupied.has(c) and not ((is_turret(kind) and building_at(c).kind == "wall") or (kind == "splitter" and building_at(c).kind == "belt")): return false
			for spawner in spawners:
				if not spawner.converted and Vector2i((spawner.position / TILE).floor()) == c: return false
	return kind != "drill" or ores.has(cell)
func can_build(cell: Vector2i, kind: String) -> bool:
	return valid_site(cell, kind) and affordable(building_cost(kind, -1, cell))

func belt_connected(cell: Vector2i, exclude: Vector2i = INVALID) -> bool:
	if not buildings.has(cell) or buildings[cell].kind != "belt": return false
	for offset in DIRS:
		var neighbor: Vector2i = cell + offset
		if neighbor == exclude or not buildings.has(neighbor) or buildings[neighbor].kind != "belt": continue
		if output_target(cell, buildings[cell]) == neighbor or output_target(neighbor, buildings[neighbor]) == cell: return true
	return false

func redirect_belt(cell: Vector2i, direction: int) -> bool:
	if not buildings.has(cell) or buildings[cell].kind != "belt" or buildings[cell].tunnel_role != "": return false
	var neighbor: Vector2i = cell + DIRS[direction]
	var other := building_at(neighbor)
	if not other.is_empty() and other.kind == "belt" and output_target(neighbor, other) == cell: return false
	var source: Dictionary = buildings[cell]
	source.dir = direction
	source.input_dir = direction
	for offset in DIRS:
		var incoming: Vector2i = cell + offset
		if buildings.has(incoming) and buildings[incoming].kind == "belt" and output_target(incoming, buildings[incoming]) == cell:
			source.input_dir = buildings[incoming].dir
			break
	if not other.is_empty() and other.kind == "belt" and drag_placed.has(neighbor): other.input_dir = direction
	refresh_belt_inputs({cell: true})
	tutorial.guide_dirty = true
	tutorial.check_connection()
	return true

func belt_edit_scope(cell: Vector2i = INVALID) -> Dictionary:
	var scope: Dictionary = drag_placed.duplicate() if dragging and selected == "belt" else {}
	if cell != INVALID: scope[cell] = true
	return scope
func auto_connect_belts(cell: Vector2i) -> void:
	var fresh: Dictionary = buildings[cell]
	for offset in DIRS:
		var neighbor: Vector2i = cell + offset
		if not buildings.has(neighbor): continue
		var other: Dictionary = buildings[neighbor]
		if other.kind != "belt" or other.tunnel_role != "": continue
		if output_target(neighbor, other) == cell:
			fresh.input_dir = other.dir
			if output_target(cell, fresh) == neighbor: fresh.dir = other.dir
			return
		if output_target(cell, fresh) == neighbor: return
		if drag_placed.has(neighbor) and dragging and not belt_connected(neighbor, cell):
			other.dir = direction_for(cell - neighbor)
			fresh.input_dir = other.dir
			return
		if not belt_connected(cell):
			fresh.dir = direction_for(neighbor - cell)
			fresh.input_dir = fresh.dir
			return
func refresh_belt_inputs(scope: Dictionary = {}) -> void:
	for cell in buildings:
		if not scope.is_empty() and not scope.has(cell): continue
		var b: Dictionary = buildings[cell]
		if b.kind != "belt" or b.tunnel_role != "": continue
		var incoming: Array[int] = []
		var extractor_dir := -1
		for offset in DIRS:
			var neighbor: Vector2i = cell + offset
			if not buildings.has(neighbor): continue
			var other: Dictionary = buildings[neighbor]
			if other.kind == "belt" and output_target(neighbor, other) == cell: incoming.append(other.dir)
			elif other.kind == "drill": extractor_dir = direction_for(cell - neighbor)
		if incoming.size() == 1: b.input_dir = incoming[0]
		elif incoming.size() > 1: b.input_dir = b.dir
		elif extractor_dir >= 0:
			b.input_dir = extractor_dir
			if int(b.dir) == (extractor_dir + 2) % 4: b.dir = extractor_dir
		else: b.input_dir = b.dir

func belt_port_mask(cell: Vector2i) -> int:
	var b := building_at(cell)
	if b.is_empty() or b.kind != "belt": return 0
	var mask: int = 1 << int(b.dir)
	for side in 4:
		var neighbor: Vector2i = cell + DIRS[side]
		var other := building_at(neighbor)
		if other.is_empty(): continue
		if (other.kind == "belt" and output_target(neighbor, other) == cell) or other.kind in ["drill", "splitter"]:
			mask |= 1 << side
	return mask
func demolition_refund(cell: Vector2i, include_pair: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var anchor := anchor_at(cell)
	if anchor == INVALID or buildings[anchor].kind == "core": return result
	for resource in buildings[anchor].paid_cost:
		var amount := int(buildings[anchor].paid_cost[resource] * (1.0 if resource == "scrap" else 0.1))
		if amount > 0: result[resource] = amount
	if include_pair and buildings[anchor].tunnel_pair != INVALID and buildings.has(buildings[anchor].tunnel_pair):
		var paired := demolition_refund(buildings[anchor].tunnel_pair)
		for resource in paired: result[resource] = result.get(resource, 0) + paired[resource]
	return result

func place_building(cell: Vector2i, kind: String, direction: int, affinity: String = "") -> bool:
	if in_bounds(cell) and placement_too_far(cell, kind):
		hud.show_shortage("Too far away...", cell)
		return false
	if lost or not valid_site(cell, kind): return false
	if not affordable(building_cost(kind, -1, cell)):
		report_shortage(building_cost(kind, -1, cell), cell)
		return false
	if is_turret(kind):
		var colors := unlocked_colors(kind)
		if affinity == "" and colors.size() == 1: affinity = colors[0]
		if not colors.has(affinity): return false
	var cost := building_cost(kind, -1, cell)
	pay(cost)
	for y in footprint_size(kind):
		for x in footprint_size(kind):
			var covered := cell + Vector2i(x, y)
			if occupied.has(covered): remove_building(covered)
	_add_building(cell, kind, 0 if kind == "drill" else direction)
	buildings[cell].paid_cost = cost.duplicate()
	if is_turret(kind): buildings[cell].color = affinity
	if kind == "belt": auto_connect_belts(cell)
	if kind == "belt": refresh_belt_inputs(belt_edit_scope(cell))
	play_sound("build", building_center(cell))
	tutorial.on_building_placed(kind, cell)
	return true
func remove_building(cell: Vector2i, refund: bool = true) -> void:
	var anchor := anchor_at(cell)
	if anchor == INVALID or buildings[anchor].kind == "core": return
	var removal_position := building_center(anchor)
	var removed_turret: bool = is_turret(buildings[anchor].kind) and not buildings[anchor].get("pending", false) and anchor.distance_squared_to(current_core) <= core_build_radius * core_build_radius
	var targets: Array[Vector2i] = [anchor]
	var affected_belts: Dictionary = {}
	var pair: Vector2i = buildings[anchor].tunnel_pair
	if pair != INVALID and buildings.has(pair) and pair != anchor: targets.append(pair)
	for target in targets:
		if not buildings.has(target): continue
		var b: Dictionary = buildings[target]
		if b.kind in ["belt", "drill"]:
			for offset in DIRS:
				var neighbor: Vector2i = target + offset
				if buildings.has(neighbor) and buildings[neighbor].kind == "belt": affected_belts[neighbor] = true
		if refund:
			demolitions.append({"pos": building_center(target), "kind": b.kind, "dir": b.dir, "life": 0.3, "size": footprint_size(b.kind) * TILE})
		if refund:
			var returned := demolition_refund(target)
			for resource in returned: add_resource(resource, returned[resource])
			if not returned.is_empty(): hud.floating_refund(returned, get_canvas_transform() * building_center(target))
		for y in footprint_size(b.kind):
			for x in footprint_size(b.kind): occupied.erase(target + Vector2i(x, y))
		buildings.erase(target)
		building_centers.erase(target)
		placement_counts[b.kind] = maxi(0, placement_counts.get(b.kind, 0) - 1)
		tutorial.on_building_removed(target)
	for resource in inventory: inventory[resource] = mini(inventory[resource], material_capacity(resource))
	if inspected in targets: inspected = INVALID
	play_sound("demolish" if refund else "explosion", removal_position)
	tutorial.guide_dirty = true
	if not affected_belts.is_empty(): refresh_belt_inputs(affected_belts)
	enemy_navigation.invalidate(self)
	if removed_turret:
		var any_turrets := false
		for other_cell in buildings:
			if is_turret(buildings[other_cell].kind) and not buildings[other_cell].get("pending", false) and other_cell.distance_squared_to(current_core) <= core_build_radius * core_build_radius:
				any_turrets = true
				break
		if not any_turrets: tutorial.on_all_turrets_lost()

func select_building(kind: String) -> void:
	if not unlocked(kind):
		toast("Unlock this building in the tech tree")
		return
	demolish_selection.clear()
	selected = kind
	active_tool = "build"
	tutorial.on_tool_changed()
	inspected = INVALID
	tutorial.on_building_selected(kind)
	hud.refresh()
var demolish_selection: Dictionary = {}
func restore_demolish_selection() -> void:
	if demolish_selection.is_empty(): return
	selected = demolish_selection.selected
	active_tool = demolish_selection.tool
	build_direction = demolish_selection.direction
	blueprint.assign(demolish_selection.blueprint)
	blueprint_size = demolish_selection.size
	demolish_selection.clear()
func select_tool(tool: String) -> void:
	if active_tool == "abolish" and tool == "abolish":
		active_tool = "build"
		restore_demolish_selection()
		dragging = false
		tutorial.on_tool_changed()
		hud.refresh()
		return
	if tool == "abolish":
		demolish_selection = {"selected": selected, "tool": active_tool, "direction": build_direction, "blueprint": blueprint.duplicate(true), "size": blueprint_size}
	else: demolish_selection.clear()
	active_tool = "build" if active_tool == tool else tool
	if active_tool == "abolish":
		hud.category = ""
		hud.hide_tray()
		hud.preview_kind = ""
		radial_pending = INVALID
		hud.dismiss_picker()
	tutorial.on_tool_changed()
	selected = ""
	dragging = false
	if tool == "blueprint_select": blueprint.clear()
	hud.refresh()
func toast(message: String) -> void:
	notice = message
	notice_time = 5.0
func direction_for(offset: Vector2i) -> int:
	if abs(offset.x) >= abs(offset.y): return 0 if offset.x >= 0 else 2
	return 1 if offset.y >= 0 else 3
func grid_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cursor := start
	while cursor != target and result.size() < WIDTH + HEIGHT:
		cursor += DIRS[direction_for(target - cursor)]
		result.append(cursor)
	return result
func begin_drag(cell: Vector2i) -> void:
	pending_crossing.clear()
	redirecting_belt = false
	drag_initial_receiver = INVALID
	var starting := building_at(cell)
	drag_started_on_belt = active_tool == "build" and not starting.is_empty() and starting.kind == "belt" and starting.tunnel_role == ""
	dragging = true
	drag_start = cell
	drag_last = cell
	blueprint_end = cell
	drag_first_direction = -1
	drag_placed.clear()
	tunnel_pending = INVALID
	drag_blocked = false
	if active_tool == "blueprint_select": return
	if active_tool == "blueprint_stamp":
		stamp_blueprint(cell)
		return
	if active_tool == "clear": clear_cargo(cell)
	elif active_tool == "abolish": remove_building(cell)
	elif selected.is_empty():
		var existing := building_at(cell)
		redirecting_belt = not existing.is_empty() and existing.kind == "belt" and existing.tunnel_role == ""
		if not existing.is_empty(): inspected = anchor_at(cell)
	elif not selected.is_empty():
		if placement_too_far(cell, selected):
			hud.show_shortage("Too far away...", cell)
			return
		if is_turret(selected) and valid_site(cell, selected) and not affordable(building_cost(selected, -1, cell)):
			report_shortage(building_cost(selected, -1, cell), cell)
			return
		if is_turret(selected) and can_build(cell, selected):
			var colors := unlocked_colors(selected)
			if colors.size() == 1:
				place_building(cell, selected, build_direction, colors[0])
				dragging = false
				return
			radial_pending = cell
			radial_kind = selected
			dragging = false
			hud.show_affinity_picker(hud.root.get_global_mouse_position())
			return
		if occupied.has(cell) and not (selected == "splitter" and building_at(cell).kind == "belt"): inspected = anchor_at(cell)
		elif place_building(cell, selected, build_direction):
			drag_placed[cell] = true
		elif affordable(building_cost(selected, -1, cell)) and not placement_too_far(cell, selected): toast("Invalid placement")
	if selected == "belt" and drag_started_on_belt: drag_placed[cell] = true
	if selected == "belt" and buildings.has(cell) and buildings[cell].kind == "belt":
		var target := output_target(cell, buildings[cell])
		if buildings.has(target) and buildings[target].kind == "belt" and output_target(target, buildings[target]) != cell: drag_initial_receiver = target
func extend_drag(target: Vector2i, straight: bool = false) -> void:
	if redirecting_belt:
		if target != drag_start: redirect_belt(drag_start, direction_for(target - drag_start))
		return
	if active_tool == "blueprint_select":
		blueprint_end = target
		return
	if active_tool == "blueprint_stamp" or drag_blocked or target == drag_last: return
	if active_tool == "build" and selected == "belt":
		if drag_first_direction < 0: drag_first_direction = direction_for(target - drag_start)
		if straight:
			var d: Vector2i = DIRS[drag_first_direction]
			var distance := maxi(0, (target.x - drag_start.x) * d.x + (target.y - drag_start.y) * d.y)
			target = drag_start + d * distance
	for cell in grid_path(drag_last, target):
		if active_tool == "clear": clear_cargo(cell)
		elif active_tool == "abolish": remove_building(cell)
		elif selected == "belt": _drag_belt_step(drag_last, cell)
		elif not selected.is_empty() and not is_turret(selected): place_building(cell, selected, build_direction)
		drag_last = cell
		if drag_blocked: break
	if selected == "belt" and not drag_placed.is_empty(): refresh_belt_inputs(drag_placed)
func _drag_belt_step(previous: Vector2i, cell: Vector2i) -> void:
	var direction := direction_for(cell - previous)
	if not pending_crossing.is_empty():
		var crossing: Dictionary = pending_crossing.duplicate()
		pending_crossing.clear()
		if direction == crossing.direction and previous == crossing.cell:
			var crossed := building_at(previous)
			if not crossed.is_empty():
				crossed.dir = crossing.original_dir
				crossed.input_dir = crossing.original_input
			drag_placed.erase(previous)
			tunnel_pending = crossing.entry
			tunnel_pending_direction = direction
	if tunnel_pending != INVALID:
		if direction != tunnel_pending_direction or tunnel_pending.distance_to(cell) > TUNNEL_MAX:
			drag_blocked = true
			toast("Tunnel must be straight and no longer than 10 tiles")
			return
		if occupied.has(cell): return
		if not buildings.has(tunnel_pending) or not place_building(cell, "belt", direction):
			drag_blocked = true
			return
		var entry: Dictionary = buildings[tunnel_pending]
		entry.dir = direction
		entry.tunnel_role = "entry"
		entry.tunnel_pair = cell
		buildings[cell].tunnel_role = "exit"
		buildings[cell].tunnel_pair = tunnel_pending
		drag_placed[cell] = true
		tunnel_pending = INVALID
		return
	# The belt being left turns even when the next tile cannot be built on.
	var leaving := building_at(previous)
	if not leaving.is_empty() and leaving.kind == "belt" and leaving.tunnel_role != "entry" and drag_placed.has(previous): leaving.dir = direction
	var b := building_at(cell)
	if not b.is_empty():
		if b.kind == "belt" and b.tunnel_role == "":
			var previous_b := building_at(previous)
			if int(b.dir) % 2 != direction % 2 and not drag_placed.has(cell) and not previous_b.is_empty() and previous_b.kind == "belt" and previous_b.tunnel_role == "":
				pending_crossing = {"cell": cell, "entry": previous, "direction": direction, "original_dir": b.dir, "original_input": b.input_dir}
			b.dir = direction
			b.input_dir = direction
			drag_placed[cell] = true
		return
	if not place_building(cell, "belt", direction):
		drag_blocked = true
		return
	buildings[cell].input_dir = direction
	drag_placed[cell] = true
	var previous_b := building_at(previous)
	if not previous_b.is_empty() and previous_b.kind == "belt" and previous_b.tunnel_role != "entry" and drag_placed.has(previous): previous_b.dir = direction
	if previous == drag_start and drag_initial_receiver != INVALID and drag_initial_receiver != cell and drag_placed.has(drag_initial_receiver):
		var receiver := building_at(drag_initial_receiver)
		if not receiver.is_empty() and receiver.kind == "belt" and receiver.tunnel_role == "": receiver.dir = direction_for(previous - drag_initial_receiver)
		drag_initial_receiver = INVALID
	if not drag_placed.is_empty(): refresh_belt_inputs(drag_placed)
func finish_drag() -> void:
	pending_crossing.clear()
	redirecting_belt = false
	if dragging and middle_blueprint_drag and blueprint_end == drag_start and anchor_at(drag_start) != INVALID:
		var kind: String = buildings[anchor_at(drag_start)].kind
		if kind != "core" and unlocked(kind):
			select_building(kind)
			for group in hud.category_buttons:
				if hud.category_buttons[group].visible and hud.unlocked_in_category(group).has(kind):
					hud.category = group
					hud._rebuild_cards()
					hud.animate_tray()
					break
	elif dragging and active_tool == "blueprint_select": capture_blueprint(drag_start, blueprint_end)
	dragging = false
	middle_blueprint_drag = false
	tunnel_pending = INVALID
	if not drag_placed.is_empty(): refresh_belt_inputs(drag_placed)
func begin_middle_blueprint(cell: Vector2i) -> void:
	selected = ""
	active_tool = "blueprint_select"
	blueprint.clear()
	hud.preview_kind = ""
	hud.category = ""
	hud.hide_tray()
	begin_drag(cell)
	middle_blueprint_drag = true
	hud.refresh()
func clear_cargo(cell: Vector2i) -> void:
	var b := building_at(cell)
	if not b.is_empty() and b.kind == "belt":
		b.item = ""
		b.travel = 0.0
func cancel_build_selection(resume_demolish_selection: bool = true) -> void:
	var should_resume := resume_demolish_selection and active_tool == "abolish"
	pending_crossing.clear()
	redirecting_belt = false
	if radial_pending != INVALID: finish_affinity("")
	selected = ""
	active_tool = "build"
	tutorial.on_tool_changed()
	dragging = false
	middle_blueprint_drag = false
	right_demolishing = false
	tunnel_pending = INVALID
	inspected = INVALID
	manual_mining_cell = INVALID
	manual_mining_progress = 0.0
	if should_resume: restore_demolish_selection()
	else: demolish_selection.clear()
	if is_instance_valid(hud):
		hud.preview_kind = ""
		hud.category = ""
		hud.hide_tray()
		hud.refresh()
func update_manual_mining(dt: float, cell: Vector2i, held: bool) -> void:
	var eligible := held and selected == "" and active_tool == "build" and ores.has(cell) and not occupied.has(cell) and not rocks.has(cell) and is_cell_visible(cell)
	if eligible and not within_build_radius(cell):
		hud.show_shortage("Too far away...", cell)
		eligible = false
	if not eligible or lost:
		manual_mining_cell = INVALID
		manual_mining_progress = 0.0
		return
	if cell != manual_mining_cell:
		manual_mining_cell = cell
		manual_mining_progress = 0.0
	if paused: return
	var resource: String = ores[cell]
	if inventory[resource] >= material_capacity(resource):
		manual_mining_progress = 0.0
		return
	manual_mining_progress += dt * wave_warp_speed()
	var interval := manual_mining_interval(resource)
	while manual_mining_progress >= interval and inventory[resource] < material_capacity(resource):
		manual_mining_progress -= interval
		add_resource(resource, 1)
		play_sound("collect", cell_center(cell))
		_sparks(cell_center(cell), RESOURCE_COLORS.get(resource, COPPER), 4)

func capture_blueprint(first: Vector2i, last: Vector2i) -> bool:
	var low := Vector2i(mini(first.x, last.x), mini(first.y, last.y))
	var high := Vector2i(maxi(first.x, last.x), maxi(first.y, last.y))
	blueprint.clear()
	var included: Dictionary = {}
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		var end: Vector2i = cell + Vector2i.ONE * (footprint_size(b.kind) - 1)
		if b.kind != "core" and cell.x >= low.x and cell.y >= low.y and end.x <= high.x and end.y <= high.y: included[cell] = true
	for cell in included:
		var b: Dictionary = buildings[cell]
		var paired: bool = included.has(b.tunnel_pair)
		blueprint.append({"offset": cell - low, "kind": b.kind, "dir": b.dir, "input_dir": b.input_dir, "color": b.color, "tunnel_role": b.tunnel_role if paired else "", "pair_offset": b.tunnel_pair - low if paired else INVALID})
	blueprint_size = high - low + Vector2i.ONE
	if blueprint.is_empty():
		toast("No complete buildings selected")
		return false
	active_tool = "blueprint_stamp"
	toast("Blueprint captured")
	return true
func blueprint_cost(origin: Vector2i = INVALID) -> Dictionary:
	var cost: Dictionary = {}
	var global_counts := owned_building_counts()
	var counts: Dictionary = {}
	for core in cores: counts[core] = counts_in_core(core)
	if origin == INVALID: origin = pricing_context_cell()
	for config in blueprint:
		var cell: Vector2i = origin + config.offset
		if is_turret(config.kind) and not building_at(cell).is_empty() and building_at(cell).kind == "wall":
			global_counts.wall = maxi(0, int(global_counts.get("wall", 0)) - 1)
			for base in counts:
				if cell.distance_squared_to(base) <= core_build_radius * core_build_radius:
					counts[base].wall = maxi(0, int(counts[base].get("wall", 0)) - 1)
		var core := pricing_core_for(cell)
		if core == INVALID: core = current_core
		var price := building_cost(config.kind, counts.get(core, {}).get(config.kind, 0), cell, global_counts.get(config.kind, 0))
		global_counts[config.kind] = global_counts.get(config.kind, 0) + 1
		for resource in price: cost[resource] = cost.get(resource, 0) + price[resource]
		for base in counts:
			if cell.distance_squared_to(base) <= core_build_radius * core_build_radius:
				counts[base][config.kind] = counts[base].get(config.kind, 0) + 1
	return cost
func can_stamp_blueprint(origin: Vector2i) -> bool:
	if blueprint.is_empty() or not affordable(blueprint_cost(origin)): return false
	var reserved: Dictionary = {}
	for config in blueprint:
		var cell: Vector2i = origin + config.offset
		if not valid_site(cell, config.kind): return false
		if is_turret(config.kind) and not unlocked_colors(config.kind).has(config.color): return false
		for y in footprint_size(config.kind):
			for x in footprint_size(config.kind):
				var tile := cell + Vector2i(x, y)
				if reserved.has(tile): return false
				reserved[tile] = true
	return true
func stamp_blueprint(origin: Vector2i) -> bool:
	if lost: return false
	for config in blueprint:
		if placement_too_far(origin + config.offset, config.kind):
			hud.show_shortage("Too far away...", origin)
			return false
	if not affordable(blueprint_cost(origin)):
		report_shortage(blueprint_cost(origin), origin)
		return false
	if not can_stamp_blueprint(origin):
		toast("Invalid placement")
		return false
	pay(blueprint_cost(origin))
	for config in blueprint:
		var cell: Vector2i = origin + config.offset
		var paid_cost := building_cost(config.kind, -1, cell)
		for y in footprint_size(config.kind):
			for x in footprint_size(config.kind):
				var covered := cell + Vector2i(x, y)
				if occupied.has(covered): remove_building(covered)
		_add_building(cell, config.kind, config.dir)
		var b: Dictionary = buildings[cell]
		b.paid_cost = paid_cost
		b.input_dir = config.input_dir
		b.color = config.color
		b.tunnel_role = config.tunnel_role
		b.tunnel_pair = origin + config.pair_offset if config.pair_offset != INVALID else INVALID
		tutorial.on_building_placed(config.kind, cell)
	play_sound("build", cell_center(origin))
	return true
var camera_right_held := false
var camera_right_dragged := false
var camera_right_origin := Vector2.ZERO
func _input(event: InputEvent) -> void:
	if handle_savestate_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(hud.modal) and hud.modal.visible: camera_right_held = false
	if handle_debug_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed and middle_blueprint_drag:
		blueprint_end = Vector2i(((get_canvas_transform().affine_inverse() * event.position) / TILE).floor())
		finish_drag()
		get_viewport().set_input_as_handled()
	# A click deselects; a drag moves the view without changing selection.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if is_instance_valid(hud.modal) and hud.modal.visible: return
		if event.pressed:
			camera_right_held = true
			camera_right_dragged = false
			camera_right_origin = event.position
		else:
			if camera_right_held and not camera_right_dragged: cancel_build_selection()
			camera_right_held = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and camera_right_held:
		if event.position.distance_to(camera_right_origin) >= 6: camera_right_dragged = true
		if camera_right_dragged:
			capture_effect.cancel_pan()
			camera.position -= event.relative / camera.zoom
			camera.position = camera.position.clamp(Vector2(180, 100), Vector2(WIDTH * TILE - 180, HEIGHT * TILE - 100))
			camera.force_update_scroll()
		get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if handle_savestate_shortcut(event): return
	if handle_debug_shortcut(event): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_audio()
		return
	if radial_pending != INVALID:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: finish_affinity(hud.radial.selected_at(hud.radial.get_local_mouse_position()))
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: cancel_build_selection()
		return
	if is_instance_valid(hud.modal) and hud.modal.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not lost: hud.close_modal()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			hud.handle_number_hotkey(event.keycode - KEY_1)
			return
		match event.keycode:
			KEY_Q: request_next_wave()
			KEY_R:
				if selected != "drill": build_direction = (build_direction + 1) % 4
			KEY_X: select_tool("abolish")
			KEY_Z:
				if not event.shift_pressed: clear_cargo(hover_cell)
			KEY_C: select_tool("blueprint_select")
			KEY_DELETE:
				if active_tool == "abolish": remove_building(hover_cell)
			KEY_SPACE:
				if tutorial.pause_available(): toggle_pause()
			KEY_ESCAPE: cancel_build_selection()
			KEY_E:
				if not tutorial_enabled or tutorial.stage >= tutorial.Stage.READY: cycle_speed()
			KEY_F: camera.position = cell_center(current_core) + Vector2(170, -35)
			KEY_T: hud.show_tech_tree()
			KEY_M: toggle_audio()
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed: step_camera_zoom(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed: begin_middle_blueprint(Vector2i(((get_canvas_transform().affine_inverse() * event.position) / TILE).floor()))
			elif middle_blueprint_drag: finish_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				cancel_build_selection()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: begin_drag(Vector2i((get_global_mouse_position() / TILE).floor()))
			else: finish_drag()
func load_ammo(cell: Vector2i) -> void:
	if lost: return
	var b := building_at(cell)
	if b.is_empty(): return
	if b.kind == "healer":
		if not wave_active():
			toast("Healing beacons load during active waves")
			return
		for resource in ["verdite", "alloy"]:
			var amount := mini(30 - int(b.buffer[resource]), inventory[resource])
			b.buffer[resource] += amount
			inventory[resource] -= amount
func toggle_pause() -> void:
	if is_instance_valid(hud.modal) and hud.modal.visible: return
	if lost or not tutorial.pause_available(): return
	if paused:
		if not saves.commit_branch():
			toast(saves.last_error)
			return
		paused = false
		rollback_paused = false
		tutorial.on_game_resumed()
	else:
		paused = true
		tutorial.paused_once = true
		if tutorial.collected_tutorial_scrap >= Content.BARRIER_UNLOCK_SCRAP: tutorial.tech_available = true
	hud.refresh()
func cycle_speed() -> void:
	if lost or not researched.has("time_speed"): return
	speed = 3 if speed == 1 else 1
	tutorial.speed_toggled = true
	hud.refresh()
func launch_wave() -> void:
	if not tutorial.start_controls_available(): return
	if lost or paused or spawn_remaining > 0 or active_spawners.is_empty(): return
	# A manual start can arrive in the frame after the last enemy was removed.
	if wave_in_progress and not wave_active(): _complete_wave()
	if paused or active_spawners.is_empty(): return
	if last_round_active(): return
	var checkpoint: Array = saves.snapshot().duplicate(true)
	# Loading a pre-launch checkpoint gives the player the inter-wave build period.
	checkpoint[1][saves.FIELDS.find("wave_timer")] = inter_wave_delay
	if not saves.capture(checkpoint, wave + 1):
		toast(saves.last_error)
		return
	_prepare_colors(wave + 1)
	wave += 1
	tutorial.on_wave_started()
	_plan_wave()
	var gates: Array = []
	for gate in active_spawners: gates.append(spawners.find(gate))
	pending_waves[wave] = gates
	wave_in_progress = true
	wave_timer = inter_wave_delay
	spawn_timer = 0.0
	hud.announce_wave(wave)
	play_sound("wave")
func request_next_wave() -> void:
	if wave_warp_active or lost or spawn_remaining > 0 or active_spawners.is_empty() or last_round_active() or not tutorial.start_controls_available(): return
	if paused:
		if not saves.commit_branch():
			toast(saves.last_error)
			return
		paused = false
		rollback_paused = false
		tutorial.on_game_resumed()
	wave_warp_active = true
	tutorial.ui_revealed.start_called = true
	wave_warp_elapsed = 0.0
	wave_warp_start_timer = wave_timer
	hud.refresh()
func wave_warp_speed() -> float:
	if not wave_warp_active: return float(speed)
	var blend := 1.0 - absf(wave_warp_elapsed - 1.0)
	return lerpf(float(speed), 10.0, clampf(blend, 0.0, 1.0))
func advance_wave_warp(dt: float) -> void:
	if not wave_warp_active or paused or lost: return
	var previous_timer := wave_timer
	wave_warp_elapsed = minf(2.0, wave_warp_elapsed + dt)
	wave_timer = lerpf(wave_warp_start_timer, 0.0, wave_warp_elapsed / 2.0)
	advance_logistics(maxf(0, previous_timer - wave_timer))
	if wave_warp_elapsed >= 2.0:
		wave_warp_active = false
		launch_wave()
func cancel_wave_warp() -> void:
	wave_warp_active = false
	wave_warp_elapsed = 0.0
func _process(delta: float) -> void:
	activate_pending_buildings()
	update_enemy_visual_offsets(delta)
	update_demolition_effects(delta)
	if radial_pending != INVALID and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): finish_affinity(hud.radial.selected_at(hud.radial.get_local_mouse_position()))
	var modal_open: bool = is_instance_valid(hud.modal) and hud.modal.visible
	if not modal_open and not hud.save_browser.dragging:
		var move := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1
		if move != Vector2.ZERO: capture_effect.cancel_pan()
		var before_move: Vector2 = camera.position
		camera.position += move.normalized() * delta * 600.0 / camera.zoom.x
		camera.position = camera.position.clamp(Vector2(180, 100), Vector2(WIDTH * TILE - 180, HEIGHT * TILE - 100))
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D): tutorial.record_wasd_movement(camera.position.distance_to(before_move))
	camera.position = camera.position.clamp(Vector2(180, 100), Vector2(WIDTH * TILE - 180, HEIGHT * TILE - 100))
	camera.position = (camera.position * camera.zoom).round() / camera.zoom
	hover_cell = Vector2i((get_global_mouse_position() / TILE).floor())
	var drag_button := MOUSE_BUTTON_MIDDLE if middle_blueprint_drag else MOUSE_BUTTON_LEFT
	if not Input.is_mouse_button_pressed(drag_button) and dragging: finish_drag()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): right_demolishing = false
	if not modal_open and not hud.is_pointer_over_ui():
		if Input.is_physical_key_pressed(KEY_Z) and not Input.is_physical_key_pressed(KEY_SHIFT): clear_cargo(hover_cell)
		if dragging: extend_drag(hover_cell, Input.is_physical_key_pressed(KEY_SHIFT))
	if not lost: collect_scrap(delta, get_global_mouse_position(), researched.has("auto_scrap") or (not modal_open and not hud.is_pointer_over_ui()))
	update_manual_mining(delta, hover_cell, dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not modal_open and not hud.is_pointer_over_ui())
	advance_wave_warp(delta)
	enemy_navigation.begin_frame()
	if not paused and not lost:
		var remaining := minf(delta, 0.05) * wave_warp_speed()
		while remaining > 0.00001 and not paused and not lost:
			var step := minf(remaining, 0.05)
			simulate(step)
			remaining -= step
	enemy_navigation.end_frame()
	notice_time = maxf(0, notice_time - delta)
	hud_timer += delta
	if hud_timer >= 0.1:
		hud_timer = 0
		hud.refresh()
	queue_redraw()

func simulate(dt: float) -> void:
	if paused or lost: return
	if not pending_waves.is_empty():
		for number in pending_waves.keys():
			var alive := false
			for enemy in enemies:
				if enemy.get("wave_id", wave) == number: alive = true
			for planned in spawn_queue:
				if planned.get("wave_id", wave) == number: alive = true
			if not alive: _complete_wave(number)
	elif wave_in_progress and not wave_active(): _complete_wave()
	if paused or lost: return
	if tutorial.waves_started and spawn_remaining == 0 and not active_spawners.is_empty() and not paused and not wave_warp_active and not last_round_active():
		wave_timer = maxf(0, wave_timer - dt)
		if wave_timer <= 0: launch_wave()
	if spawn_remaining > 0:
		spawn_timer -= dt
		if spawn_timer <= 0:
			_spawn_enemy()
			spawn_remaining -= 1
			spawn_timer = maxf(0.3, 0.85 - wave * 0.035)
	for cell in buildings.keys():
		var b: Dictionary = buildings[cell]
		b.flash = maxf(0, b.flash - dt * 5)
		b.pulse = maxf(0, b.pulse - dt)
		if b.get("pending", false): continue
		if is_turret(b.kind): _update_turret(cell, b, dt)
		elif b.kind == "forge": _update_forge(b, dt)
		elif b.kind == "healer": _update_healer(cell, b, dt)
	if not wave_warp_active: advance_logistics(dt)
	_update_enemies(dt)
	for i in range(shots.size() - 1, -1, -1):
		shots[i].life -= dt
		if shots[i].get("projectile", false):
			for enemy in enemies:
				if enemy.info_id != shots[i].target: continue
				shots[i].to = enemy.pos
				if shots[i].life <= 0:
					enemy.hp -= shots[i].damage
					enemy.flash = 1.0
					_sparks(enemy.pos, RESOURCE_COLORS.iron, 4)
				break
		if shots[i].life <= 0: shots.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= dt
		particles[i].pos += particles[i].velocity * dt
		if particles[i].life <= 0: particles.remove_at(i)
func output_target(cell: Vector2i, b: Dictionary) -> Vector2i:
	if b.kind in ["splitter", "drill"]: return cell + DIRS[b.route_dir] if b.route_dir >= 0 else INVALID
	if b.tunnel_role == "entry": return b.tunnel_pair
	var offset: Vector2i = DIRS[b.dir]
	if b.kind == "forge" and b.dir in [0, 1]: offset *= 2
	return cell + offset
func can_receive(target: Vector2i, item: String, source: Vector2i = INVALID) -> bool:
	var anchor := anchor_at(target)
	if anchor == INVALID or anchor == source: return false
	var b: Dictionary = buildings[anchor]
	if b.get("pending", false): return false
	if b.kind == "core": return inventory.has(item) and inventory[item] < material_capacity(item)
	if b.kind in ["belt", "splitter"]: return b.item == ""
	if is_turret(b.kind): return not BUILDINGS[b.kind].get("ammo_free", false) and BUILDINGS[b.kind].ammo == item and b.ammo < turret_ammo_capacity(b.kind)
	if b.kind == "healer": return wave_active() and item in ["verdite", "alloy"] and b.buffer[item] < 30
	if b.kind == "forge": return item in ["copper", "iron"] and b.buffer[item] < 10
	return false
func _update_items(dt: float) -> void:
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		if b.get("pending", false): continue
		if b.item == "": continue
		if b.kind in ["splitter", "drill"]: update_splitter_route(cell, b)
		var target := output_target(cell, b)
		if target == INVALID:
			b.travel = 0.0
			continue
		# Items travel to the handoff point even while the next slot is moving.
		# Simultaneous departures below free a whole moving line together.
		var receiver := building_at(target)
		var moving_slot: bool = not receiver.is_empty() and receiver.kind in ["belt", "splitter"]
		var limit: float = 1.0 if moving_slot or can_receive(target, b.item, cell) else maxf(0.43, b.travel)
		b.travel = minf(limit, b.travel + dt * conveyor_items_per_second(b.kind) / FLOW_INTERVAL)
	_move_items()
func _move_items() -> void:
	var transfers: Array[Dictionary] = []
	var reserved: Dictionary = {}
	var departing: Dictionary = {}
	# Resolve from sinks upstream, independently of building insertion order.
	for pass_index in buildings.size():
		var changed := false
		for cell in buildings:
			var b: Dictionary = buildings[cell]
			if b.get("pending", false): continue
			if b.item == "" or b.travel < 0.99999 or departing.has(cell): continue
			var target := output_target(cell, b)
			var anchor := anchor_at(target)
			if reserved.has(anchor): continue
			if can_receive(target, b.item, cell) or (anchor != cell and departing.has(anchor)):
				departing[cell] = true
				reserved[anchor] = true
				transfers.append({"from": cell, "to": anchor, "item": b.item})
				changed = true
		if not changed: break
	for transfer in transfers:
		var sender: Dictionary = buildings[transfer.from]
		if sender.kind in ["splitter", "drill"]:
			sender.next_output = (sender.route_dir + 1) % 4
			sender.route_dir = -1
		buildings[transfer.from].item = ""
		buildings[transfer.from].travel = 0.0
	for transfer in transfers:
		var receiver: Dictionary = buildings[transfer.to]
		if receiver.kind == "core":
			add_resource(transfer.item, 1)

			delivered += 1
			receiver.flash = 0.35
		elif is_turret(receiver.kind): receiver.ammo += 1
		elif receiver.kind in ["forge", "healer"]: receiver.buffer[transfer.item] += 1
		else:
			receiver.item = transfer.item
			receiver.travel = 0.0
			if receiver.kind == "splitter": receiver.route_dir = -1
func _update_forge(b: Dictionary, dt: float) -> void:
	if b.buffer.copper < 2 or b.buffer.iron < 2 or b.item != "": return
	b.progress += dt
	if b.progress >= 3.0:
		b.buffer.copper -= 2
		b.buffer.iron -= 2
		b.item = "alloy"
		b.travel = 0.0
		b.progress = 0.0
		b.flash = 0.8
func _update_healer(cell: Vector2i, b: Dictionary, dt: float) -> void:
	b.cooldown = minf(1.0, b.cooldown + dt)
	if b.cooldown < 1 or b.buffer.verdite < 1 or b.buffer.alloy < 1: return
	var targets: Array[Dictionary] = []
	var origin := building_center(cell)
	for other in buildings:
		var target: Dictionary = buildings[other]
		if target.hp < target.max_hp and origin.distance_to(building_center(other)) <= TILE * 2 + 0.01: targets.append(target)
	if targets.is_empty(): return
	b.buffer.verdite -= 1
	b.buffer.alloy -= 1
	b.cooldown -= 1.0
	b.pulse = 0.65
	play_sound("heal", origin)
	for target in targets: target.hp = minf(target.max_hp, target.hp + target.max_hp * 0.01)
	core_health = buildings[current_core].hp
func create_enemy(kind: String, pos: Vector2, affinity: String) -> Dictionary:
	enemy_info_counter += 1
	var health := enemy_health(kind, wave)
	var data: Dictionary = Content.ENEMY_TYPES[kind]
	return {"kind": kind, "color": affinity, "pos": pos, "hp": health, "max_hp": health, "speed": data.speed, "cooldown": 0.7, "angle": PI, "aim": PI, "flash": 0.0, "velocity": Vector2.ZERO, "windup": 0.35, "info_id": enemy_info_counter}
func enemy_health(kind: String, number: int) -> float:
	if kind in ["siege", "scout", "heavy", "bulwark"]: return float(Content.ENEMY_TYPES[kind].hp)
	var data: Dictionary = Content.ENEMY_TYPES[kind]
	var health: float = data.hp + (maxi(0, number - 1) * (3.0 if kind == "scout" else 1.0) if kind in ["scout", "runner"] else number * (12.0 if kind in ["heavy", "bulwark", "siege"] else 7.0))
	return floorf(health / 10.0) * 3.0
func _spawn_enemy() -> void:
	if spawn_queue.is_empty(): return
	var planned: Dictionary = spawn_queue.pop_front()
	var enemy := create_enemy(planned.kind, planned.pos, planned.color)
	enemy.wave_id = planned.get("wave_id", wave)
	enemies.append(enemy)
func _update_turret(cell: Vector2i, b: Dictionary, dt: float) -> void:
	if b.get("pending", false): return
	b.cooldown = maxf(0, b.cooldown) - dt
	var data: Dictionary = BUILDINGS[b.kind]
	var origin := building_center(cell)
	var target_index := -1
	var nearest: float = turret_range(b.kind)
	for i in enemies.size():
		if enemies[i].hp <= 0: continue
		var distance := origin.distance_to(enemies[i].pos)
		if distance < nearest:
			nearest = distance
			target_index = i
	if target_index < 0:
		if b.kind == "turret": b.progress = 0.0
		return
	var enemy: Dictionary = enemies[target_index]
	b.aim = lerp_angle(b.aim, (enemy.pos - origin).angle(), 1.0 - exp(-16.0 * dt))
	if b.kind == "turret": b.progress = minf(float(data.reload), b.progress + dt) if b.ammo > 0 else 0.0
	while (data.get("ammo_free", false) or b.ammo > 0) and b.cooldown <= 0 and enemy.hp > 0 and (b.kind != "turret" or b.progress >= float(data.reload) - 0.00001):
		if b.kind == "turret": b.progress = 0.0
		if not data.get("ammo_free", false): b.ammo -= 1
		play_sound("cannon" if b.kind == "cannon" else "shot", origin)
		b.cooldown += data.reload
		b.flash = 1.0
		var damage: float = data.damage * (1.25 if researched.has("damage") else 1.0) * affinity_multiplier(b.color, enemy.color)
		if b.kind != "turret": enemy.hp -= damage
		if b.kind != "turret": enemy.flash = 1.0
		var color: Color = Color("69cbff") if b.kind == "solar" else TEAM_COLORS[b.color]
		var duration := clampf(origin.distance_to(enemy.pos) / 420.0, 0.12, 0.65) if b.kind == "turret" else 0.11
		shots.append({"from": origin + Vector2.from_angle(b.aim) * 15, "to": enemy.pos, "life": duration, "duration": duration, "color": color, "projectile": b.kind == "turret", "target": enemy.info_id, "damage": damage})
		if b.kind != "turret": _sparks(enemy.pos, color, 3)
		else: _sparks(origin + Vector2.from_angle(b.aim) * 15, Color("ffd49a"), 10)
func _update_enemies(dt: float) -> void:
	if enemy_navigation.signature == -1: enemy_navigation.refresh_grid(self)
	enemy_separation.begin(self)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy.hp <= 0:
			_sparks(enemy.pos, RED, 12)
			play_sound("explosion", enemy.pos)
			enemies.remove_at(i)
			kills += 1
			_drop_scrap(enemy)
			continue
		enemy.flash = maxf(0, enemy.flash - dt * 5)
		enemy.recoil = maxf(0, float(enemy.get("recoil", 0.0)) - dt * 5)
		enemy.cooldown = maxf(0, enemy.cooldown) - dt
		enemy.windup = maxf(0, float(enemy.get("windup", 0.0)) - dt)
		enemy.navigation_timer = float(enemy.get("navigation_timer", 0.0)) - dt
		enemy.separation_cooldown = maxf(0, float(enemy.get("separation_cooldown", 0.0)) - dt)
		var separation_point = enemy_separation.waypoint(self, enemy)
		var separating: bool = separation_point != null
		var navigation: Dictionary = enemy.get("navigation", {})
		if not navigation.is_empty() and not buildings.has(navigation.target):
			navigation = {}
			enemy.navigation = {}
			enemy.erase("intended_pos")
		if not separating and navigation.has("path"):
			var route_path: Array = navigation.path
			var path_index: int = navigation.get("path_index", 0)
			while path_index + 1 < route_path.size() and enemy.pos.distance_to(navigation.waypoint) < 4:
				path_index += 1
				navigation.waypoint = navigation.destination if path_index == route_path.size() - 1 else cell_center(route_path[path_index])
			navigation.path_index = path_index
		var destination_conflict: bool = enemy.has("intended_pos") and not navigation.get("shared_barrier", false) and not enemy_goal_available(enemy.intended_pos, enemy)
		var nearby_turret: Vector2i = enemy_navigation.priority_turret(self, enemy.pos, enemy.kind == "runner")
		var current_priority: bool = not navigation.is_empty() and is_turret(buildings[navigation.target].kind) and enemy.pos.distance_squared_to(building_center(navigation.target)) <= TILE * TILE * enemy_navigation.TURRET_PRIORITY_TILES * enemy_navigation.TURRET_PRIORITY_TILES
		var priority_override: bool = nearby_turret != INVALID and not current_priority
		var needs_route: bool = navigation.is_empty() and (enemy.navigation_timer <= 0 or enemy.get("route_revision", -1) != enemy_navigation.signature)
		if not needs_route and not separating and not navigation.is_empty():
			needs_route = destination_conflict or not buildings.has(navigation.target) or navigation.get("revision", -1) != enemy_navigation.signature or enemy.get("navigation_resume", false)
			if priority_override and navigation.get("priority_checked", INVALID) != nearby_turret: needs_route = true
			if not navigation.has("path"): needs_route = needs_route or enemy.navigation_timer <= 0
			if enemy.pos.distance_to(navigation.destination) < 1 and visible_enemy_objective(enemy) == INVALID: needs_route = true
		if needs_route:
			if enemy_navigation.can_route():
				var resumed: Dictionary = enemy_navigation.resume_destination(self, enemy, navigation) if enemy.get("navigation_resume", false) and not priority_override else {}
				navigation = resumed if not resumed.is_empty() else enemy_navigation.route(self, enemy.pos, enemy.kind == "runner", Content.ENEMY_TYPES[enemy.kind].reach, enemy).duplicate(true)
				enemy.erase("navigation_resume")
				if not navigation.is_empty(): navigation.priority_checked = nearby_turret
				enemy.navigation = navigation
				if not navigation.is_empty(): enemy.intended_pos = navigation.destination
				else: enemy.erase("intended_pos")
				enemy.route_revision = enemy_navigation.signature
				enemy.navigation_timer = (1.0 + fmod(float(enemy.info_id), 17) * 0.02 if enemy_navigation.components_ready else 0.0) if navigation.is_empty() else 0.25
			elif not navigation.is_empty() and not buildings.has(navigation.target):
				navigation = {}
		if navigation.is_empty() and not separating: continue
		var target: Vector2i = navigation.target if not navigation.is_empty() else current_core
		if not buildings.has(target): continue
		var toward: Vector2 = separation_point - enemy.pos if separating else navigation.waypoint - enemy.pos
		var stats: Dictionary = Content.ENEMY_TYPES[enemy.kind]
		var reach: float = stats.reach
		var desired := Vector2.ZERO
		if enemy.kind == "mender":
			for ally in enemies:
				if ally.pos.distance_to(enemy.pos) <= TILE * 3: ally.hp = minf(ally.max_hp, ally.hp + dt * 3.0)
		if (separating or visible_enemy_objective(enemy) == INVALID) and enemy.windup <= 0:
			var direction := toward.normalized()
			var approach := clampf(toward.length() / 16.0, 0.1, 1.0)
			if not separating and navigation.get("path_index", 0) + 1 < navigation.get("path", []).size(): approach = 1.0
			desired = direction * enemy.speed * approach
		var velocity: Vector2 = enemy.get("velocity", Vector2.ZERO)
		velocity = velocity.move_toward(desired, (2000.0 if desired != Vector2.ZERO else 3500.0) * dt)
		var next_position: Vector2 = enemy.pos + velocity * dt
		if toward.length() <= velocity.length() * dt and toward.dot(velocity) > 0: next_position = enemy.pos + toward
		var origin_cell := Vector2i((enemy.pos / TILE).floor())
		var step := Vector2i((next_position / TILE).floor()) - origin_cell
		if step != Vector2i.ZERO and not enemy_separation.can_step(enemy_navigation.runner_grid, origin_cell, step):
			velocity = Vector2.ZERO
			next_position = enemy.pos
			if not separating: enemy.navigation_resume = true
		enemy.velocity = velocity
		enemy.pos = next_position
		var facing: float = velocity.angle() if velocity.length() > 2 else (building_center(target) - enemy.pos).angle()
		enemy.angle = lerp_angle(enemy.angle, facing, 1.0 - exp(-5.5 * dt))
		var shot_target := INVALID
		var shot_distance := reach + 2.0
		var priority_target := -1
		for cell in buildings:
			if buildings[cell].get("pending", false): continue
			if buildings[cell].kind == "core" and cell != current_core: continue
			if enemy.kind == "runner" and is_turret(buildings[cell].kind): continue
			var distance: float = enemy.pos.distance_to(building_center(cell))
			var priority: int = 2 if is_turret(buildings[cell].kind) else (1 if buildings[cell].kind not in ["wall", "belt"] else 0)
			if distance > reach + 2.0 or priority < priority_target: continue
			if not enemy_has_line_of_sight(enemy.pos, cell): continue
			if priority > priority_target or distance <= shot_distance:
				shot_distance = distance
				shot_target = cell
				priority_target = priority
		var aim_target: Vector2 = building_center(shot_target if shot_target != INVALID else target)
		enemy.aim = lerp_angle(float(enemy.get("aim", enemy.angle)), (aim_target - enemy.pos).angle(), 1.0 - exp(-9.0 * dt))
		if enemy.kind in ["bulwark", "siege"]:
			enemy.charge = minf(1.0, float(enemy.get("charge", 0.0)) + dt / stats.reload) if shot_target != INVALID else 0.0
		while shot_target != INVALID and buildings.has(shot_target) and enemy.cooldown <= 0 and (enemy.kind not in ["bulwark", "siege"] or enemy.get("charge", 0.0) >= 0.99999):
			if enemy.kind in ["bulwark", "siege"]: enemy.charge = 0.0
			enemy.recoil = 1.0
			enemy.cooldown += stats.reload
			shots.append({"from": enemy.pos + Vector2.from_angle(enemy.aim) * stats.size * 0.4, "to": building_center(shot_target), "life": 0.16, "color": TEAM_COLORS[enemy.color]})
			_damage_building(shot_target, stats.damage)
			if lost: return
func enemy_has_line_of_sight(origin: Vector2, target: Vector2i) -> bool:
	var destination := building_center(target)
	var direction := destination - origin
	var cell := Vector2i((origin / TILE).floor())
	var end := Vector2i((destination / TILE).floor())
	var step := Vector2i(signi(int(signf(direction.x))), signi(int(signf(direction.y))))
	var delta := Vector2(INF if step.x == 0 else TILE / absf(direction.x), INF if step.y == 0 else TILE / absf(direction.y))
	var next := Vector2(INF, INF)
	if step.x != 0: next.x = ((cell.x + (1 if step.x > 0 else 0)) * TILE - origin.x) / direction.x
	if step.y != 0: next.y = ((cell.y + (1 if step.y > 0 else 0)) * TILE - origin.y) / direction.y
	for iteration in WIDTH + HEIGHT + 4:
		if shot_cell_blocked(cell, target): return false
		if cell == end: return true
		if absf(next.x - next.y) < 0.000001:
			if shot_cell_blocked(cell + Vector2i(step.x, 0), target) or shot_cell_blocked(cell + Vector2i(0, step.y), target): return false
			cell += step
			next += delta
		elif next.x < next.y:
			cell.x += step.x
			next.x += delta.x
		else:
			cell.y += step.y
			next.y += delta.y
	return false
func enemy_goal_available(point: Vector2, actor: Dictionary) -> bool:
	if actor.is_empty(): return true
	for other in enemies:
		if other.info_id == actor.info_id or other.hp <= 0: continue
		var spacing: float = (Content.ENEMY_TYPES[actor.kind].size + Content.ENEMY_TYPES[other.kind].size) / 2.0
		if other.has("intended_pos") and point.distance_squared_to(other.intended_pos) < spacing * spacing: return false
	return true
func shot_cell_blocked(cell: Vector2i, target: Vector2i) -> bool:
	if rocks.has(cell): return true
	var anchor := anchor_at(cell)
	return anchor != INVALID and anchor != target and buildings[anchor].kind == "wall" and not buildings[anchor].get("pending", false)
func visible_enemy_objective(enemy: Dictionary) -> Vector2i:
	var nearest: float = Content.ENEMY_TYPES[enemy.kind].reach + 2.0
	var navigation: Dictionary = enemy.get("navigation", {})
	if not navigation.is_empty() and buildings.has(navigation.target) and buildings[navigation.target].kind == "wall":
		if enemy.pos.distance_to(building_center(navigation.target)) <= nearest and enemy_has_line_of_sight(enemy.pos, navigation.target): return navigation.target
	if not navigation.is_empty() and buildings.has(navigation.target) and is_turret(buildings[navigation.target].kind) and enemy.kind != "runner":
		var distance: float = enemy.pos.distance_to(building_center(navigation.target))
		if distance <= TILE * enemy_navigation.TURRET_PRIORITY_TILES:
			return navigation.target if distance <= nearest and enemy_has_line_of_sight(enemy.pos, navigation.target) else INVALID
	var target := INVALID
	for cell in buildings:
		if buildings[cell].get("pending", false): continue
		var kind: String = buildings[cell].kind
		if kind in ["belt", "wall"] or (kind == "core" and cell != current_core) or (enemy.kind == "runner" and is_turret(kind)): continue
		var distance: float = enemy.pos.distance_to(building_center(cell))
		if distance <= nearest and enemy_has_line_of_sight(enemy.pos, cell):
			nearest = distance
			target = cell
	return target
func _damage_building(cell: Vector2i, amount: float) -> void:
	var anchor := anchor_at(cell)
	if anchor == INVALID: return
	var b: Dictionary = buildings[anchor]
	if b.get("pending", false): return
	if amount > 0 and b.get("shield", false):
		b.shield = false
		b.pulse = 0.65
		_sparks(building_center(anchor), Color("79caff"), 20)
		play_sound("gate", building_center(anchor))
		return
	if amount > 0:
		tutorial.first_damage_taken = true
		hud_timer = 0.1
	b.hp -= amount
	b.flash = 1.0
	if b.kind == "core" and anchor == current_core: core_health = maxf(0, b.hp)
	if b.hp <= 0:
		if b.kind == "drill": tutorial.on_extractor_destroyed()
		_sparks(building_center(anchor), COPPER, 18)
		if b.kind == "core":
			lost = true
			play_sound("defeat")
			if saves.entries.is_empty() and not saves.initial_checkpoint.is_empty(): saves.capture(saves.initial_checkpoint)
			hud.save_browser.show_browser(true)
		else:
			remove_building(anchor, false)
func _sparks(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"pos": pos, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 100), "life": rng.randf_range(0.15, 0.5), "color": color})

func _draw() -> void:
	if camera == null: return
	var scrap_glow: bool = tutorial.scraps_should_glow()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	for scrap in scraps:
		if scrap_glow:
			draw_circle(scrap.pos, 22, Color(1.0, 0.76, 0.25, 0.04 + pulse * 0.04))
			draw_circle(scrap.pos, 14, Color(1.0, 0.82, 0.4, 0.08 + pulse * 0.1))
			draw_arc(scrap.pos, 8 + pulse * 2, 0, TAU, 32, Color(1.0, 0.85, 0.4, 0.5 + pulse * 0.4), line_width())
		var value: int = scrap.get("value", 1)
		var texture: Texture2D = textures.scrap_item if value == 1 else textures["scrap_%d_item" % value]
		draw_texture_rect(texture, Rect2(scrap.pos - Vector2.ONE * 5, Vector2.ONE * 10), false)
	for cell in buildings: _draw_building(cell, buildings[cell])
	for effect in demolitions:
		var age: float = 1.0 - effect.life / 0.3
		var dimension: float = effect.size * (1.0 - age * 0.65)
		draw_set_transform(effect.pos + Vector2(0, age * 9), effect.dir * PI / 2.0 if effect.kind == "belt" else age * 0.12)
		draw_texture_rect(textures[effect.kind], Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension), false, Color(1, 1, 1, 1.0 - age))
		draw_set_transform(Vector2.ZERO)
		for piece in 10:
			var axis := Vector2.from_angle(piece * TAU / 10.0)
			var pos: Vector2 = effect.pos + axis * age * (16 + piece % 3 * 8) + Vector2(0, age * age * 14)
			draw_rect(Rect2(pos, Vector2.ONE * (3 - age)), Color(0.73, 0.6, 0.46, 1.0 - age))
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		if b.item == "": continue
		var origin := building_center(cell)
		var target := output_target(cell, b)
		var destination := origin if target == INVALID else cell_center(target)
		if b.tunnel_role == "entry": destination = origin + Vector2(DIRS[b.dir]) * 10
		var pos := origin.lerp(destination, b.travel)
		var alpha: float = 1.0 - b.travel * 0.75 if b.tunnel_role == "entry" else 1.0
		draw_texture_rect(textures[b.item + "_item"], Rect2(pos - Vector2.ONE * 4, Vector2.ONE * 8), false, Color(1, 1, 1, alpha))
	for enemy in enemies: _draw_enemy(enemy)
	if hud.hovered_core != INVALID and buildings.has(hud.hovered_core) and Input.is_key_pressed(KEY_ALT):
		_draw_range(building_center(hud.hovered_core), core_build_radius * TILE, TEAL if hud.hovered_core == current_core else RED)
	if not hud.hovered_enemy.is_empty() and hud.hovered_enemy.hp > 0 and Input.is_key_pressed(KEY_ALT):
		_draw_range(hud.hovered_enemy.pos, Content.ENEMY_TYPES[hud.hovered_enemy.kind].reach, TEAM_COLORS[hud.hovered_enemy.color])
	for shot in shots:
		if shot.get("projectile", false):
			var point: Vector2 = shot.from.lerp(shot.to, clampf(1.0 - shot.life / shot.duration, 0, 1))
			draw_texture_rect(textures.iron_item, Rect2(point - Vector2(5, 5), Vector2(10, 10)), false)
		else: draw_line(shot.from, shot.to, Color(shot.color, clampf(shot.life * 10, 0, 1)), line_width())
	for particle in particles: draw_rect(Rect2(particle.pos, Vector2(3, 3)), Color(particle.color, minf(1, particle.life * 3)))
	if not hud.is_pointer_over_ui(): _draw_cursor()
func _draw_cursor() -> void:
	if not in_bounds(hover_cell) or not is_cell_visible(hover_cell): return
	if active_tool == "abolish":
		var rect := Rect2(Vector2(hover_cell * TILE), Vector2.ONE * TILE)
		draw_rect(rect, Color(1.0, 0.08, 0.07, 0.28))
		draw_rect(rect, Color(1.0, 0.12, 0.1, 1.0), false, line_width())
		return
	if manual_mining_cell == hover_cell and manual_mining_progress > 0:
		var color: Color = RESOURCE_COLORS.get(ores.get(hover_cell, "copper"), COPPER)
		var progress := manual_mining_progress / manual_mining_interval(ores.get(hover_cell, "copper"))
		draw_texture_rect(PixelArt.mining_ring(progress, color, raster_tile_size), Rect2(Vector2(hover_cell * TILE), Vector2(TILE, TILE)), false)
	if active_tool == "blueprint_select" and dragging:
		var low := Vector2i(mini(drag_start.x, blueprint_end.x), mini(drag_start.y, blueprint_end.y))
		var high := Vector2i(maxi(drag_start.x, blueprint_end.x), maxi(drag_start.y, blueprint_end.y))
		var area := Rect2(Vector2(low * TILE), Vector2((high - low + Vector2i.ONE) * TILE))
		draw_rect(area, Color(1, 1, 1, 0.08))
		draw_rect(area, TEAL, false, line_width())
		return
	if active_tool == "blueprint_stamp":
		var tint := Color(1, 1, 1, 0.45) if can_stamp_blueprint(hover_cell) else Color(1, 0.35, 0.3, 0.45)
		for config in blueprint:
			var size_px: float = footprint_size(config.kind) * TILE
			var rect := Rect2(Vector2((hover_cell + config.offset) * TILE), Vector2.ONE * size_px)
			var texture: Texture2D = textures[config.kind if config.tunnel_role == "" else "tunnel_" + config.tunnel_role]
			draw_set_transform(rect.get_center(), config.dir * PI / 2.0 if config.kind == "belt" else 0.0)
			draw_texture_rect(texture, Rect2(-rect.size / 2, rect.size), false, tint)
			draw_set_transform(Vector2.ZERO)
			draw_rect(rect, Color(tint, 0.75), false, line_width())
			if is_turret(config.kind): draw_rect(rect.grow(line_width() / 2), Color(TEAM_COLORS[config.color], 0.65), false, line_width())
		return
	var anchor := anchor_at(hover_cell)
	if anchor != INVALID and not (active_tool == "build" and is_turret(selected) and buildings[anchor].kind == "wall"):
		var b: Dictionary = buildings[anchor]
		var rect := Rect2(Vector2(anchor * TILE), Vector2.ONE * footprint_size(b.kind) * TILE)
		draw_rect(rect, Color(TEAL, 0.7), false, line_width())
		if b.tunnel_pair != INVALID and buildings.has(b.tunnel_pair):
			var start := building_center(anchor)
			var end := building_center(b.tunnel_pair)
			var length := start.distance_to(end)
			for i in range(0, int(length), 7): draw_circle(start.lerp(end, float(i) / length), line_width() / 2, Color(1, 1, 1, 0.38))
		if is_turret(b.kind): _draw_range(building_center(anchor), turret_range(b.kind), TEAL)
		elif b.kind == "healer": _draw_range(building_center(anchor), TILE * 2, RESOURCE_COLORS.verdite)
	elif active_tool == "build" and not selected.is_empty():
		var color := TEAL if can_build(hover_cell, selected) else RED
		var dim: float = TILE * footprint_size(selected)
		var rect := Rect2(Vector2(hover_cell * TILE), Vector2.ONE * dim)
		draw_set_transform(rect.get_center(), build_direction * PI / 2.0 if selected == "belt" else 0.0)
		var ghost_texture: Texture2D = textures.wall_iron if selected == "wall" and researched.has("iron_barriers") else (textures.belt_dark if selected == "belt" and not researched.has("conveyor_speed") else textures[selected])
		draw_texture_rect(ghost_texture, Rect2(-rect.size / 2, rect.size), false, Color(color, 0.45))
		draw_set_transform(Vector2.ZERO)
		draw_rect(rect, color, false, line_width())
		if is_turret(selected): _draw_range(rect.get_center(), turret_range(selected), color)
		elif selected == "healer": _draw_range(rect.get_center(), TILE * 2, color)
	else: draw_rect(Rect2(Vector2(hover_cell * TILE), Vector2.ONE * TILE), Color(RED if active_tool == "abolish" else TEAL, 0.15))
func _draw_range(origin: Vector2, radius: float, color: Color) -> void:
	draw_circle(origin, radius, Color(color, 0.025))
	draw_arc(origin, radius, 0, TAU, 80, Color(color, 0.25), line_width())
func set_camera_zoom(value: float) -> void:
	if is_instance_valid(camera_zoom_tween): camera_zoom_tween.kill()
	var index := 0
	for candidate in ZOOM_LEVELS.size():
		if absf(ZOOM_LEVELS[candidate] - value) < absf(ZOOM_LEVELS[index] - value): index = candidate
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[index]
	camera_zoom_target = ZOOM_LEVELS[index]
	camera.position = (camera.position * camera.zoom).round() / camera.zoom
	var resolution: int = roundi(TILE * ZOOM_LEVELS[index])
	if resolution != raster_tile_size:
		raster_tile_size = resolution
		textures = sprite_rasters(resolution)
		configure_tile_rasters(resolution)
	queue_redraw()
func step_camera_zoom(direction: int) -> void:
	capture_effect.cancel_pan()
	var index := maxi(0, ZOOM_LEVELS.find(camera_zoom_target))
	animate_camera_zoom(ZOOM_LEVELS[clampi(index + direction, 0, ZOOM_LEVELS.size() - 1)], 0.2)
var camera_zoom_target := 2.0
var camera_zoom_tween: Tween
func animate_camera_zoom(value: float, duration: float = 0.2) -> void:
	var from := camera.zoom
	set_camera_zoom(value)
	camera.zoom = from
	camera_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_zoom_tween.tween_property(camera, "zoom", Vector2.ONE * camera_zoom_target, duration)
func _draw_building(cell: Vector2i, b: Dictionary) -> void:
	if b.get("pending", false):
		draw_pending_building(cell, b)
		return
	var p := building_center(cell).round()
	var dimension: float = 44.0 if b.kind == "core" else TILE * footprint_size(b.kind)
	var rect := Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension)
	var texture: Texture2D = textures.belt_dark if b.kind == "belt" and not researched.has("conveyor_speed") else textures[b.kind]
	if b.kind == "wall" and researched.has("iron_barriers"): texture = textures.wall_iron
	if b.kind == "solar": texture = textures.solar_base
	if b.kind == "core" and cell != current_core: texture = textures.core_inactive
	var angle: float = b.dir * PI / 2.0 if b.kind == "belt" else 0.0
	var flip := Vector2.ONE
	if b.tunnel_role != "": texture = textures["tunnel_" + b.tunnel_role]
	elif b.kind == "belt" and b.input_dir != b.dir and (int(b.dir) - int(b.input_dir) + 4) % 2 == 1:
		texture = textures.belt_corner if researched.has("conveyor_speed") else textures.belt_corner_dark
		angle = b.input_dir * PI / 2.0
		if (int(b.dir) - int(b.input_dir) + 4) % 4 == 3: flip.y = -1
	if b.kind == "belt" and b.tunnel_role == "":
		var mask := belt_port_mask(cell)
		if mask in [7, 11, 13, 14, 15]:
			texture = textures["belt_junction_%d%s" % [mask, "" if researched.has("conveyor_speed") else "_dark"]]
			angle = 0.0
			flip = Vector2.ONE
	draw_set_transform(p, angle, flip)
	draw_texture_rect(texture, rect, false)
	draw_set_transform(Vector2.ZERO)
	if core_should_glow(cell):
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
		draw_texture_rect(texture, Rect2(p - Vector2.ONE * dimension / 2, Vector2.ONE * dimension), false, Color(1.0, 0.85, 0.35, pulse * 0.5))
		for ring in 3: draw_circle(p, dimension * 0.65 + ring * 4, Color(1.0, 0.83, 0.3, (0.05 + pulse * 0.07) / (ring + 1)))

	if b.kind == "belt" and b.tunnel_role == "":
		draw_set_transform(p)
		draw_texture_rect(ConveyorMotion.arrow_texture(b.dir, b.input_dir, elapsed * conveyor_items_per_second("belt"), raster_tile_size), Rect2(-16, -16, 32, 32), false)
		draw_set_transform(Vector2.ZERO)
	elif b.kind == "drill":
		var rotor: Vector2 = [Vector2(-2, -5), Vector2(3, -2), Vector2(0, 3), Vector2(-5, 0)][floori(elapsed * 4) % 4]
		draw_rect(Rect2(p + rotor, Vector2(2, 2)), RESOURCE_COLORS[ores.get(cell, "copper")])
	elif b.kind == "splitter":
		var direction: int = b.route_dir
		if direction < 0:
			var outputs := extractor_outputs(cell, b) if b.kind == "drill" else splitter_outputs(cell)
			for offset in 4:
				var candidate: int = (int(b.next_output) + offset) % 4
				if outputs.has(candidate):
					direction = candidate
					break
		if direction >= 0:
			var axis := Vector2(DIRS[direction])
			var side := Vector2(-axis.y, axis.x)
			draw_polygon(PackedVector2Array([p + axis * 6, p - axis * 3 + side * 3, p - axis * 3 - side * 3]), PackedColorArray([TEAL]))
	elif is_turret(b.kind):
		var gun_position := p + Vector2(0, 2) if b.kind == "solar" else p
		if b.kind == "turret":
			var loading: float = clampf(b.progress / BUILDINGS.turret.reload, 0, 1)
			gun_position -= Vector2.from_angle(b.aim) * (pow(loading, 3) * 4 + b.flash * 6)
		draw_set_transform(gun_position.round(), b.aim)
		if b.kind == "solar": draw_texture_rect(textures.solar_gun, Rect2(-16, -16, 32, 32), false)
		else: draw_texture_rect(textures.barrel, Rect2(-16, -16, 32, 32), false, Color("c1cdd0") if b.kind in ["cannon", "turret"] else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		if b.kind == "turret" and b.progress > 0:
			var charge: float = clampf(b.progress / BUILDINGS.turret.reload, 0, 1)
			var axis := Vector2.from_angle(b.aim)
			var side := axis.orthogonal()
			var muzzle := (p + axis * 15).round()
			var tint := Color("ffd49a").lerp(Color.WHITE, charge)
			for spark in 5:
				var phase := fposmod(charge * 3 + spark / 5.0, 1.0)
				var spark_angle := spark * TAU / 5 + charge * 2
				var point := muzzle + Vector2.from_angle(spark_angle) * (5 + (1 - phase) * 18)
				draw_rect(Rect2(point.round(), Vector2.ONE * (1 + charge * 2)), Color(tint, phase * charge))
			for rail in [-1, 1]:
				var start: Vector2 = (p - axis * 8 + side * rail * (10 - charge * 5)).round()
				var end: Vector2 = (p + axis * (2 + charge * 13) + side * rail * 5).round()
				draw_line(start, end, Color(tint, 0.3 + charge * 0.7), line_width())
			draw_circle(muzzle, 2 + charge * 5, Color(tint, charge * 0.3))
			draw_rect(Rect2(muzzle - Vector2.ONE * (1 + charge * 2), Vector2.ONE * (2 + charge * 4)), tint)
		if b.flash > 0.6: draw_circle(p + Vector2.from_angle(b.aim) * 18, 4 * b.flash, TEAM_COLORS[b.color])
		if b.kind == "turret" and b.flash > 0:
			draw_arc(p + Vector2.from_angle(b.aim) * 18, 3 + (1 - b.flash) * 18, 0, TAU, 24, Color("ffd49a", b.flash * 0.7), line_width())
		if b.kind == "turret" and (b.get("shield", false) or b.pulse > 0):
			var alpha: float = 1.0 if b.get("shield", false) else clampf(b.pulse / 0.65, 0, 1)
			var shield_rect := Rect2(p - Vector2.ONE * (dimension / 2 + 3), Vector2.ONE * (dimension + 6))
			preload("res://scripts/drawing_style.gd").draw_shield(self, shield_rect, alpha, line_width())
		if not BUILDINGS[b.kind].get("ammo_free", false):
			var ammo_rect := ammo_bar_rect(cell)
			draw_rect(ammo_rect, Color("0b0809"))
			draw_rect(Rect2(ammo_rect.position, Vector2(ammo_rect.size.x * clampf(float(b.ammo) / turret_ammo_capacity(b.kind), 0, 1), 3)), RESOURCE_COLORS[BUILDINGS[b.kind].ammo])
	elif b.kind == "healer" and b.pulse > 0:
		draw_arc(p, TILE * 2 * (1 - b.pulse / 0.65), 0, TAU, 48, Color(RESOURCE_COLORS.verdite, b.pulse), line_width())
	elif b.kind == "forge":
		draw_rect(Rect2(p + Vector2(-21, 23), Vector2(42 * b.progress / 3.0, 3)), RESOURCE_COLORS.alloy)
		var out := cell_center(output_target(cell, b))
		draw_line(p, p.lerp(out, 0.65), Color(TEAL, 0.4), line_width())
	if b.kind == "wall" or b.hp < b.max_hp:
		draw_rect(Rect2(p + Vector2(-13, -dimension / 2 - 5), Vector2(26, 3)), Color("25191a"))
		draw_rect(Rect2(p + Vector2(-13, -dimension / 2 - 5), Vector2(26 * maxf(0, b.hp) / b.max_hp, 3)), TEAL if b.hp / b.max_hp > 0.4 else RED)
	if b.flash > 0 and not is_turret(b.kind): draw_rect(Rect2(p + rect.position, rect.size), Color(TEAL if b.kind == "core" else RED, b.flash * 0.3))
func _draw_enemy(enemy: Dictionary) -> void:
	var p := enemy_visual_position(enemy)
	var dimension: float = Content.ENEMY_TYPES[enemy.kind].size
	draw_set_transform(p, enemy.angle)
	draw_texture_rect(textures[enemy.kind + "_body"], Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension), false, TEAM_COLORS[enemy.color])
	var aim: float = enemy.get("aim", enemy.angle)
	var recoil: float = enemy.get("recoil", 0.0)
	draw_set_transform(p - Vector2.from_angle(aim) * recoil * (4.0 if enemy.kind == "siege" else (3.0 if enemy.kind == "bulwark" else 1.5)), aim)
	draw_texture_rect(textures[enemy.kind + "_gun"], Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension), false, TEAM_COLORS[enemy.color])
	draw_set_transform(Vector2.ZERO)
	if enemy.kind in ["bulwark", "siege"] and enemy.get("charge", 0.0) > 0:
		var charge: float = enemy.charge
		var muzzle := (p + Vector2.from_angle(aim) * dimension * 0.4).round()
		var tint: Color = TEAM_COLORS[enemy.color].lightened(0.5)
		if enemy.kind == "siege":
			var axis := Vector2.from_angle(aim)
			var side := axis.orthogonal()
			for rail in [-1, 1]:
				var rail_start: Vector2 = (p - axis * 8 + side * rail * 8).round()
				var rail_end: Vector2 = (p + axis * dimension * 0.4 + side * rail * (8 - charge * 4)).round()
				draw_line(rail_start, rail_end, Color(tint, charge), line_width())
		var pulse := 0.7 + 0.3 * sin(charge * TAU * 8)
		draw_circle(muzzle, 3 + charge * 8, Color(tint, charge * 0.18))
		draw_circle(muzzle, 1 + charge * 4, tint.lerp(Color.WHITE, charge * pulse))
		for segment in ceili(charge * 8):
			var angle := segment * TAU / 8 + charge * TAU
			var point := (muzzle + Vector2.from_angle(angle) * (12 - charge * 5)).round()
			draw_rect(Rect2(point - Vector2.ONE, Vector2.ONE * 2), Color(tint, 0.4 + charge * 0.6))
	if recoil > 0.7:
		draw_circle(p + Vector2.from_angle(aim) * dimension * 0.4, (4.5 if enemy.kind == "siege" else (3.5 if enemy.kind == "bulwark" else 2.0)) * recoil, TEAM_COLORS[enemy.color].lightened(0.65))
	if enemy.hp < enemy.max_hp:
		draw_rect(Rect2(p + Vector2(-12, -23), Vector2(24, 3)), Color("231f23"))
		draw_rect(Rect2(p + Vector2(-12, -23), Vector2(24 * maxf(0, enemy.hp) / enemy.max_hp, 3)), RED)

func finish_affinity(affinity: String) -> bool:
	var cell := radial_pending
	var kind := radial_kind
	radial_pending = INVALID
	radial_kind = ""
	hud.dismiss_picker()
	if cell == INVALID or not TEAM_COLORS.has(affinity): return false
	return place_building(cell, kind, build_direction, affinity)

# Expedition configuration and logistics limits.
@export var base_material_capacity: int = 500
@export var initial_wave_delay: float = 180.0
@export var inter_wave_delay: float = 180.0
var wave_timer := 65.0
var current_core := CORE
var cores: Array[Vector2i] = [CORE]
var spawners: Array[Node2D] = []
var active_spawners: Array[Node2D] = []
var spawn_queue: Array[Dictionary] = []
var current_wave_color := "red"
var next_wave_color := "red"
var wave_rng := RandomNumberGenerator.new()
var wave_in_progress := false
var pending_waves: Dictionary = {}
var last_wave_budget := 0
var placement_counts: Dictionary = {}
var visible_cells: Dictionary = {}
var fog: Node2D
var fog_disabled := false
var scraps: Array[Dictionary] = []

func building_cost(kind: String, count: int = -1, cell: Vector2i = INVALID, global_count: int = -1) -> Dictionary:
	var core := pricing_core_for(pricing_context_cell() if cell == INVALID else cell)
	if core == INVALID: core = current_core
	var n: int = counts_in_core(core).get(kind, 0) if count < 0 else count
	if kind == "belt" and not tutorial.extractor_connected_once: return {"copper": maxi(1, roundi(core_resource_multiplier(core, "copper")))}
	var rate := 1.10 if is_turret(kind) else (1.01 if kind == "belt" else (1.05 if kind == "wall" else 1.10))
	var multiplier := pow(rate, n)
	var result: Dictionary = {}
	for resource in BUILDINGS[kind].cost:
		var factor: float = pow(rate, owned_building_counts().get(kind, 0) if global_count < 0 else global_count) if resource == "scrap" else multiplier
		result[resource] = maxi(1, roundi(BUILDINGS[kind].cost[resource] * core_resource_multiplier(core, resource) * factor))
	return result

func core_resource_multiplier(core: Vector2i, resource: String) -> float:
	for spawner in spawners:
		if spawner.converted and spawner.turns_into_core and Vector2i((spawner.position / TILE).floor()) == core:
			return 1.0 + maxf(0.0, spawner.core_resource_price_increase.get(resource, 0.0)) / 100.0
	return 1.0
func core_should_glow(cell: Vector2i) -> bool:
	return not cores.is_empty() and cell != cores[0] and buildings.has(cell) and buildings[cell].kind == "core" and buildings[cell].progress < 1.0
func pricing_context_cell() -> Vector2i:
	return Vector2i((camera.position / TILE).floor()) if is_instance_valid(camera) else current_core
func pricing_core_for(cell: Vector2i) -> Vector2i:
	for index in range(cores.size() - 1, -1, -1):
		if cell.distance_squared_to(cores[index]) <= core_build_radius * core_build_radius: return cores[index]
	return INVALID
func counts_in_core(core: Vector2i) -> Dictionary:
	var counts: Dictionary = {}
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		if b.kind != "core" and cell.distance_squared_to(core) <= core_build_radius * core_build_radius:
			counts[b.kind] = counts.get(b.kind, 0) + 1
	return counts
func placement_too_far(cell: Vector2i, kind: String) -> bool:
	for y in footprint_size(kind):
		for x in footprint_size(kind):
			if not within_build_radius(cell + Vector2i(x, y)): return true
	return false
func material_capacity(resource: String) -> int:
	if resource == "scrap": return 9223372036854775807
	if debug_resource_capacity: return 10000
	var capacity := base_copper_capacity if resource == "copper" else (40 if resource == "iron" else base_material_capacity)
	for b in buildings.values():
		if not b.get("pending", false) and b.kind != "core" and BUILDINGS[b.kind].get("stores", "") == resource: capacity += 50 if resource == "copper" else 500
	return capacity
func add_resource(resource: String, amount: int) -> int:
	var accepted := amount if resource == "scrap" else mini(amount, maxi(0, material_capacity(resource) - int(inventory[resource])))
	inventory[resource] += accepted
	if accepted > 0:
		discovered_resources[resource] = true
		if is_instance_valid(tutorial): tutorial.resource_received()
	return accepted
func is_cell_visible(cell: Vector2i) -> bool:
	return fog_disabled or (visible_cells.has(cell) and (not is_instance_valid(capture_effect) or capture_effect.cell_revealed(cell)))
func _init_spawners() -> void:
	for node in get_node("EnemySpawns").get_children():
		node.material = material
		spawners.append(node)
	spawners.sort_custom(func(a, b): return a.Order < b.Order if a.Order != b.Order else str(a.name) < str(b.name))
	_activate_spawners()
func _activate_spawners() -> void:
	active_spawners.clear()
	var next_order := 2147483647
	for spawner in spawners:
		spawner.active = false
		if not spawner.converted: next_order = mini(next_order, spawner.Order)
	for spawner in spawners:
		if not spawner.converted and spawner.Order == next_order:
			spawner.active = true
			active_spawners.append(spawner)
		spawner.queue_redraw()
	_prepare_colors(wave + 1)
	_reveal_map()
func _prepare_colors(number: int) -> void:
	var preview_rng := RandomNumberGenerator.new()
	preview_rng.seed = number
	var valid := ["red", "green", "blue"]
	# The wave uses a shared color from the intersection of active spawner palettes.
	for spawner in active_spawners:
		valid = valid.filter(func(color): return spawner.colors_for_wave(pending_gate_waves(spawner, number)).has(color))
	if valid.is_empty():
		valid = []
		for spawner in active_spawners:
			for color in spawner.colors_for_wave(pending_gate_waves(spawner, number)):
				if TEAM_COLORS.has(color) and not valid.has(color): valid.append(color)
	if valid.is_empty(): valid = ["red"]
	next_wave_color = valid[preview_rng.randi_range(0, valid.size() - 1)]
func pending_gate_waves(spawner: Node2D, planning_wave: int = -1) -> int:
	var index := spawners.find(spawner)
	var count := 0
	for number in pending_waves:
		if number != planning_wave and pending_waves[number].has(index): count += 1
	return count
func next_wave_budget() -> int:
	var total := 0
	for spawner in active_spawners: total += spawner.budget(pending_gate_waves(spawner))
	return total
func next_wave_forecast(indices: Array = []) -> Dictionary:
	if indices.is_empty():
		for gate in active_spawners: indices.append(spawners.find(gate))
	return preload("res://scripts/wave_forecast.gd").build(self, wave + 1, indices, [], pending_waves)
func _plan_wave() -> void:
	var indices: Array = []
	for gate in active_spawners: indices.append(spawners.find(gate))
	var forecast: Dictionary = preload("res://scripts/wave_forecast.gd").build(self, wave, indices, [], pending_waves)
	spawn_queue.assign(forecast.units)
	last_wave_budget = forecast.budget
	current_wave_color = forecast.color
	wave_rng.state = forecast.rng_state
	spawn_remaining = spawn_queue.size()
func _complete_wave(number: int = -1) -> void:
	activate_pending_buildings()
	if number < 0: number = wave
	var completed_gates: Array = pending_waves.get(number, [])
	pending_waves.erase(number)
	wave_in_progress = wave_active()
	tutorial.on_wave_completed(number)
	if researched.has("slugger_shield"):
		for building in buildings.values():
			if building.kind == "turret":
				building.shield = true
				building.pulse = 0.0
	var advanced := false
	var gates: Array = active_spawners.duplicate() if completed_gates.is_empty() else []
	for index in completed_gates: gates.append(spawners[index])
	for spawner in gates:
		if spawner.converted: continue
		spawner.waves_completed += 1
	for spawner in active_spawners:
		if spawner.waves_completed >= spawner.waves_before_conversion and pending_waves.is_empty() and not wave_active():
			var cell := Vector2i((spawner.position / TILE).floor())
			if spawner.turns_into_core:
				capture_effect.begin(cell)
				if occupied.has(cell): remove_building(cell, false)
				_add_building(cell, "core", 0)
				cores.erase(cell)
				cores.append(cell)
				current_core = cell
				wave = 0
				wave_timer = 360.0
				core_health = buildings[cell].hp
				tutorial.on_new_core(cell)
				paused = true
				cancel_wave_warp()
			spawner.converted = true
			spawner.hide()
			if not spawner.turns_into_core: play_sound("gate")
			advanced = true
	_activate_spawners()
	if advanced: enemy_navigation.invalidate(self)
	if active_spawners.is_empty() and not wave_active() and not victory_shown:
		won = true
		victory_shown = true
		paused = true
		hud.show_outcome(true)
func turret_ammo_capacity(kind: String) -> int:
	return 8 if kind == "turret" else 80
func last_round_active() -> bool:
	for spawner in active_spawners:
		var scheduled: int = spawner.waves_completed
		var index: int = spawners.find(spawner)
		for number in pending_waves:
			if pending_waves[number].has(index): scheduled += 1
		if scheduled >= spawner.waves_before_conversion: return true
	return false
func _reveal_map() -> void:
	visible_cells.clear()
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var point := cell_center(cell)
			var visible := false
			for base in cores:
				if point.distance_to(cell_center(base)) <= TILE * 20: visible = true
			if not visible and tutorial.start_controls_available():
				for spawner in active_spawners:
					var closest := Geometry2D.get_closest_point_to_segment(point, cell_center(current_core), spawner.position)
					if point.distance_to(closest) <= TILE * 10: visible = true
			if visible: visible_cells[cell] = true
	if is_instance_valid(fog): fog.queue_redraw()
	if is_instance_valid(capture_effect): capture_effect.update_reveal_extent()
func _drop_scrap(enemy: Dictionary) -> void:
	spawn_scrap(Content.enemy_scrap(enemy.kind), enemy.pos)
func spawn_scrap(amount: int, position: Vector2, burst: bool = true) -> void:
	for value in preload("res://scripts/scrap_tiers.gd").split(amount):
		var velocity := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80, 450) if burst else Vector2.ZERO
		scraps.append({"pos": position, "origin": position, "velocity": velocity, "amount": value, "value": value, "magnetized": false, "age": 0.0 if burst else 2.0})
func move_scrap(scrap: Dictionary, dt: float) -> void:
	if scrap.magnetized or not scrap.has("velocity"): return
	var velocity: Vector2 = scrap.velocity
	var decay := exp(-8.0 * dt)
	var next: Vector2 = scrap.pos + velocity * (1.0 - decay) / 8.0
	var origin: Vector2 = scrap.get("origin", scrap.pos)
	scrap.pos = origin + (next - origin).limit_length(TILE * 2.0)
	scrap.velocity = velocity * decay if velocity.length() * decay >= 3 else Vector2.ZERO
func collect_scrap(dt: float, pointer: Vector2, allow_pickup: bool = true) -> void:
	for i in range(scraps.size() - 1, -1, -1):
		var scrap: Dictionary = scraps[i]
		move_scrap(scrap, dt)
		scrap.age = float(scrap.get("age", 2.0)) + dt
		if not allow_pickup: continue
		if not is_cell_visible(Vector2i((scrap.pos / TILE).floor())): continue
		var hovered: bool = pointer.distance_to(scrap.pos) <= TILE * 2
		var was_magnetized: bool = scrap.magnetized
		if hovered or (researched.has("auto_scrap") and scrap.age >= 2.0): scrap.magnetized = true
		if not scrap.magnetized: continue
		var pickup_dt := dt if hovered or was_magnetized else minf(dt, scrap.age - 2.0)
		scrap.pos = scrap.pos.move_toward(pointer, (140.0 + scrap.pos.distance_to(pointer) * 8) * pickup_dt)
		if scrap.pos.distance_to(pointer) <= 9:
			var accepted := add_resource("scrap", scrap.amount)
			scrap.amount -= accepted
			if accepted > 0:
				play_sound("collect", scrap.pos)
				tutorial.on_scrap_collected(accepted)
			
			if scrap.amount == 0: scraps.remove_at(i)
			else:
				var remainder: int = scrap.amount
				scraps.remove_at(i)
				spawn_scrap(remainder, pointer, false)

func ammo_bar_rect(cell: Vector2i) -> Rect2:
	var width: float = TILE * footprint_size(buildings[cell].kind)
	return Rect2(building_center(cell) + Vector2(-width / 2.0, width / 2.0 - 3), Vector2(width, 3))

func update_demolition_effects(dt: float) -> void:
	for i in range(demolitions.size() - 1, -1, -1):
		demolitions[i].life -= dt
		if demolitions[i].life <= 0: demolitions.remove_at(i)
func splitter_outputs(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for direction in 4:
		var neighbor: Vector2i = cell + DIRS[direction]
		var belt := building_at(neighbor)
		if not belt.is_empty() and belt.kind == "belt" and output_target(neighbor, belt) != cell:
			result.append(direction)
	return result
func update_splitter_route(cell: Vector2i, b: Dictionary) -> void:
	var outputs := extractor_outputs(cell, b) if b.kind == "drill" else splitter_outputs(cell)
	if outputs.has(b.route_dir) and can_receive(cell + DIRS[b.route_dir], b.item, cell): return
	b.route_dir = -1
	b.travel = 0.0
	for offset in 4:
		var direction: int = (int(b.next_output) + offset) % 4
		if outputs.has(direction) and can_receive(cell + DIRS[direction], b.item, cell):
			b.route_dir = direction
			return

func within_build_radius(cell: Vector2i) -> bool:
	for core in cores:
		if cell.distance_squared_to(core) <= core_build_radius * core_build_radius: return true
	return false
static func debug_features_allowed(features: PackedStringArray) -> bool:
	for feature in ["web", "HTML5", "wasm32", "wasm64"]:
		if features.has(feature): return false
	return true
func handle_debug_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey): return false
	if event.pressed: debug_keys[event.keycode] = true
	else: debug_keys.erase(event.keycode)
	if not event.pressed or event.echo or not event.shift_pressed: return false
	var platform_features := platform_debug_features()
	if not debug_features_allowed(platform_features): return false
	if event.keycode in [KEY_Z, KEY_L] and debug_keys.has(KEY_Z) and debug_keys.has(KEY_L):
		base_material_capacity = 10000
		debug_resource_capacity = true
		for resource in inventory:
			inventory[resource] = 10000
			discovered_resources[resource] = true
		tutorial.resource_received()
		hud.refresh()
		return true
	if event.keycode != KEY_P: return false
	debug_unlock_step = mini(2, debug_unlock_step + 1)
	tutorial.skip_to_ready()
	if debug_unlock_step == 2:
		for id in TECH: research(id, true)
		tutorial.tech_available = true
	if is_instance_valid(hud): hud.refresh()
	return true
func platform_debug_features() -> PackedStringArray:
	var features := PackedStringArray()
	for feature in ["web", "HTML5", "wasm32", "wasm64"]:
		if OS.has_feature(feature): features.append(feature)
	return features

func unlocked_colors(kind: String) -> Array[String]:
	var colors: Array[String] = []
	for color in TEAM_COLORS:
		if researched.has(kind + "_" + color): colors.append(color)
	if kind == "turret" and researched.has("weapons") and not colors.has("red"): colors.push_front("red")
	return colors

func _add_color_tech() -> void:
	for id in TECH:
		if id not in ["barriers", "conveyor_speed", "turret_range", "copper_storage", "auto_scrap", "build_hotkeys", "time_speed"]: TECH[id].pos.y += 310
	var row := 0
	for kind in ["solar", "turret", "repeater", "cannon"]:
		var parent: String = "conveyor_speed" if kind == "solar" else BUILDINGS[kind].tech
		var column := 0
		for color in TEAM_COLORS:
			TECH[kind + "_" + color] = {"name": BUILDINGS[kind].name + ": " + color.capitalize(), "parent": parent, "cost": {"copper": 15 + row * 10, "iron": 5 + row * 5}, "icon": kind, "pos": Vector2(24 + column * 228, 1160 + row * 155), "color": color}
			if kind == "solar" and color == "red":
				TECH.solar_red.starter_color = true
				TECH.solar_red.cost = {}
				researched.solar_red = true
			column += 1
		row += 1
func owned_building_counts() -> Dictionary:
	var counts: Dictionary = {}
	for b in buildings.values():
		if b.kind != "core": counts[b.kind] = counts.get(b.kind, 0) + 1
	return counts
func conveyor_items_per_second(kind: String = "belt") -> float:
	return 1.0 if kind in ["belt", "splitter"] and researched.has("conveyor_speed") else 0.5
func turret_range(kind: String) -> float:
	return float(BUILDINGS[kind].range) + (TILE * 2 if kind == "solar" and researched.has("turret_range") else 0)










func line_width() -> float:
	return preload("res://scripts/drawing_style.gd").stroke(self)


func tower_outline_width() -> float:
	return 1.0 / get_screen_transform().x.length()



func extractor_outputs(cell: Vector2i, b: Dictionary) -> Array[int]:
	var result := splitter_outputs(cell)
	for direction in 4:
		if not result.has(direction) and can_receive(cell + DIRS[direction], b.item, cell): result.append(direction)
	return result

func randomize_rock_tiles() -> void:
	var layer: TileMapLayer = get_node("Level/RockWalls")
	if layer.has_meta("rock_variants"): return
	layer.set_meta("rock_variants", true)
	var ids: Array[int] = [layer.tile_set.get_source_id(0)]
	for variant in range(1, 4):
		var source := TileSetAtlasSource.new()
		source.texture = PixelArt.texture(load("res://assets/terrain/rock_%d.svg" % variant), Vector2i.ONE * raster_tile_size)
		source.texture_region_size = Vector2i.ONE * raster_tile_size
		source.create_tile(Vector2i.ZERO)
		ids.append(layer.tile_set.add_source(source))
	for cell in layer.get_used_cells():
		# Coordinate hashing keeps the same painted layout and variants across runs.
		var value := absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ 42017)
		layer.set_cell(cell, ids[value % 4], Vector2i.ZERO)
func advance_logistics(duration: float) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var step := minf(0.05, remaining)
		elapsed += step
		for cell in buildings:
			var building: Dictionary = buildings[cell]
			if building.get("pending", false): continue
			if building.kind != "drill": continue
			building.progress = minf(5.0, building.progress + step * (1.3 if researched.has("mining") else 1.0))
			if building.progress >= 4.99999 and building.item == "":
				building.item = ores.get(cell, "copper")
				building.travel = 0.0
				building.progress = 0.0
		_update_items(step)
		remaining -= step

func manual_mining_interval(_resource: String) -> float:
	return 1.0
var building_centers: Dictionary = {}
var enemy_visual_offsets: Dictionary = {}
func enemy_visual_position(enemy: Dictionary) -> Vector2:
	return enemy.pos + enemy_visual_offsets.get(enemy.info_id, Vector2.ZERO)
func update_enemy_visual_offsets(dt: float) -> void:
	var groups: Dictionary = {}
	var live: Dictionary = {}
	var blend := 1.0 - exp(-10.0 * maxf(0, dt))
	for enemy in enemies:
		if enemy.hp <= 0: continue
		live[enemy.info_id] = true
		var velocity: Vector2 = enemy.get("velocity", Vector2.ZERO)
		if velocity.length_squared() > 0.25:
			var offset: Vector2 = enemy_visual_offsets.get(enemy.info_id, Vector2.ZERO)
			enemy_visual_offsets[enemy.info_id] = offset.lerp(Vector2.ZERO, blend)
			continue
		var tile := Vector2i((enemy.pos / TILE).floor())
		if not groups.has(tile): groups[tile] = []
		groups[tile].append(enemy)
	for tile in groups:
		var group: Array = groups[tile]
		group.sort_custom(func(a: Dictionary, b: Dictionary): return a.info_id < b.info_id)
		var center := Vector2.ZERO
		for enemy in group: center += enemy.pos
		center /= group.size()
		for index in group.size():
			var enemy: Dictionary = group[index]
			var target := Vector2.ZERO
			if group.size() > 1:
				target = center + Vector2.from_angle(-PI / 2 + TAU * index / group.size()) * 16.0 - enemy.pos
			var previous: Vector2 = enemy_visual_offsets.get(enemy.info_id, Vector2.ZERO)
			enemy_visual_offsets[enemy.info_id] = previous.lerp(target, blend)
	for id in enemy_visual_offsets.keys():
		if not live.has(id): enemy_visual_offsets.erase(id)
var has_pending_construction := false
func activate_pending_buildings() -> void:
	if not has_pending_construction or not enemies.is_empty() or spawn_remaining > 0 or not spawn_queue.is_empty(): return
	for building in buildings.values(): building.pending = false
	has_pending_construction = false
	enemy_navigation.invalidate(self)
	queue_redraw()
func draw_pending_building(cell: Vector2i, building: Dictionary) -> void:
	var dimension: float = TILE * footprint_size(building.kind)
	var center := building_center(cell).round()
	var texture: Texture2D = textures.solar_base if building.kind == "solar" else textures[building.kind]
	if building.kind == "belt" and not researched.has("conveyor_speed"): texture = textures.belt_dark
	if building.get("tunnel_role", "") != "": texture = textures["tunnel_" + building.tunnel_role]
	draw_set_transform(center, building.dir * PI / 2.0 if building.kind == "belt" else 0.0)
	preload("res://scripts/drawing_style.gd").draw_construction(self, texture, Rect2(-Vector2.ONE * dimension / 2, Vector2.ONE * dimension))
	draw_set_transform(Vector2.ZERO)
	if is_turret(building.kind):
		draw_set_transform(center, building.aim)
		draw_texture_rect(textures.solar_gun if building.kind == "solar" else textures.barrel, Rect2(-16, -16, 32, 32), false, Color(1, 1, 1, 0.33))
		draw_set_transform(Vector2.ZERO)

func handle_savestate_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode < KEY_1 or event.keycode > KEY_9 or event.alt_pressed: return false
	var slot: int = event.keycode - KEY_1 + 1
	if event.ctrl_pressed and not event.shift_pressed:
		saves.load_slot(slot)
		return true
	if event.shift_pressed and not event.ctrl_pressed:
		if not saves.save_slot(slot): toast("Could not save slot %d" % slot)
		return true
	return false
