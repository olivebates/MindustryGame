extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var pink = preload("res://scripts/pink_production.gd")
	var cell := Vector2i(20, 25)
	game._add_building(cell, "turret", 0)
	var tower: Dictionary = game.buildings[cell]
	tower.booster_type = "pink"
	tower.booster_count = 2
	pink.advance_firing(tower, 100)
	check(tower.booster_count == 2 and tower.booster_used == 0, "Idle time never consumes boosters")
	tower.booster_fire_remaining = 0.12
	pink.advance_firing(tower, 4)
	check(is_equal_approx(tower.booster_used, 0.12), "Only muzzle activity counts, not following reload")
	tower.booster_used = 29.95
	tower.booster_fire_remaining = 0.12
	pink.advance_firing(tower, 0.1)
	check(tower.booster_count == 1 and is_equal_approx(tower.booster_used, 0.05), "Thirty firing seconds consume one booster and preserve remainder")
	tower.booster_used = 12.5
	game.saves.capture()
	tower.booster_used = 0
	check(game.saves.restore(game.saves.current) and is_equal_approx(game.buildings[cell].booster_used, 12.5), "Partial booster lifetime survives saves")
	tower = game.buildings[cell]
	tower.booster_used = 29.99
	tower.booster_fire_remaining = 0.1
	pink.advance_firing(tower, 0.1)
	check(tower.booster_count == 0 and tower.booster_type == "" and tower.booster_used == 0, "Exhausted booster clears type and timer")
	var visual = preload("res://scripts/tower_outlines.gd").new()
	visual.game = game
	game.selected = "belt"
	game.hover_cell = Vector2i(24, 25)
	game._add_building(Vector2i(23, 25), "belt", 0)
	game.buildings[Vector2i(23, 25)].item = "pink"
	check(visual.detects_pink_supply(), "Pink conveyor placement highlights compatible inputs")
	game.selected = "wall"
	check(not visual.detects_pink_supply(), "Other building tools do not show pink placement highlights")
	game.hover_cell = Vector2i(23, 25)
	check(visual.detect_supply_materials().has("pink"), "Hovering material works without conveyor selection")
	check(visual.needs_material(tower, "pink"), "Empty booster slot highlights")
	tower.booster_count = 1
	check(not visual.needs_material(tower, "pink"), "One booster suppresses highlight")
	tower.ammo = 0
	check(visual.needs_material(tower, "iron"), "Empty iron ammunition highlights")
	check(visual.missing_ammo(tower) == "iron", "Empty turret signals ammo without a hovered supply")
	tower.ammo = 1
	check(not visual.needs_material(tower, "iron"), "One round suppresses iron highlight")
	check(visual.missing_ammo(tower) == "", "One round removes persistent ammo highlight")
	game._add_building(Vector2i(18, 25), "solar", 0)
	check(visual.missing_ammo(game.buildings[Vector2i(18, 25)]) == "", "Ammo-free Solar never signals missing ammo")
	game._add_building(Vector2i(26, 25), "refinery", 0)
	var refinery: Dictionary = game.buildings[Vector2i(26, 25)]
	refinery.buffer.copper = 1
	check(not visual.needs_material(refinery, "copper") and visual.needs_material(refinery, "iron"), "Refinery highlights only missing resource")
	visual.free()
	print("BOOSTER SOCKET CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
