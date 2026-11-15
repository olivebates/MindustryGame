extends SceneTree
const Outline = preload("res://scripts/tower_outlines.gd")
const Status = preload("res://scripts/building_status.gd")
const Info = preload("res://scripts/structure_info.gd")
var failures := 0
var checks := 0
class DrawGame extends "res://scripts/game.gd":
	var exercise_hover := false
	var cursor_draws := 0
	func _draw() -> void:
		super._draw()
		if not exercise_hover: return
		var previous := hover_cell
		for cell in buildings:
			hover_cell = cell
			_draw_cursor()
			cursor_draws += 1
		hover_cell = previous
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(DrawGame)
	game.tutorial_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.paused = true
	game.fog_disabled = true
	game.audio.muted = true
	game.rocks.clear()
	game.buildings.clear()
	game.occupied.clear()
	game.building_centers.clear()
	game.current_core = Vector2i(5, 5)
	game.cores.assign([game.current_core])
	game._add_building(game.current_core, "core", 0)
	var index := 0
	for kind in game.BUILDINGS:
		game._add_building(Vector2i(12 + index % 8 * 9, 5 + index / 8 * 9), kind, 0)
		index += 1
	var outline: Node2D
	for child in game.get_children():
		if child.get_script() == Outline: outline = child
	outline.set_process(false)
	outline.supply_materials.assign(game.Content.RESOURCES)
	outline.supply_materials.append("coolant")
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		check(Info.description(game, b.kind) is String and Info.stats(game, b.kind, b) is String, b.kind + " provides hover information")
		if game.Content.NUCLEAR_KINDS.has(b.kind):
			var description: String = Info.description(game, b.kind)
			check(not description.contains("\n") and description.count(".") == 1, b.kind + " has one description sentence")
			for stats in [Info.stats(game, b.kind, b), Info.stats(game, b.kind, {})]:
				check(stats.split("\n").size() <= 10, b.kind + " has compact stat rows")
				var decorated: String = game.hud.decorated_stats(stats, {})
				check(Array(decorated.split("\n")).all(func(line): return line.begins_with("[img=14x14]")), b.kind + " gives every stat an icon")
		check(Status.missing_inputs(game, b) is Array, b.kind + " provides input status")
		for material in outline.supply_materials:
			check(outline.needs_material(b, material) is bool, b.kind + " handles material highlights for " + material)
			check(game.can_receive(cell, material) is bool, b.kind + " handles resource acceptance for " + material)
		game.hover_cell = cell
		game.hud.show_structure_info(b.kind, b, Vector2(500, 300))
	var core: Dictionary = game.buildings[game.current_core]
	game.inventory.copper = 0
	check(outline.needs_material(core, "copper"), "Core highlights a supplied material when storage has room")
	game.inventory.copper = game.material_capacity("copper")
	check(not outline.needs_material(core, "copper"), "Full core storage does not request more material")
	check(not outline.needs_material(core, "coolant") and outline.missing_ammo(core) == "", "Core ignores non-storable coolant and never requests ammunition")
	game.exercise_hover = true
	game.queue_redraw()
	outline.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	check(game.cursor_draws >= game.buildings.size(), "Actual cursor drawing runs across every structure, including the core")
	print("BUILDING PRESENTATION: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(1 if failures else 0)
