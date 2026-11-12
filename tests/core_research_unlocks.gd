extends "res://tests/iron_supply_zoom.gd"
func add_core(cell: Vector2i) -> void:
	game._add_building(cell, "core", 0)
	game.cores.append(cell)
	game.current_core = cell
	game.tutorial.on_new_core(cell)
func run() -> void:
	fresh()
	game.research("barriers", true)
	game.research("turret_range", true)
	game.research("copper_storage", true)
	check(not game.tech_core_unlocked("weapons") and not game.hud.visible_tech_ids().has("weapons") and not game.research("weapons"), "Slugger is hidden and cannot be researched before core two")
	var second := Vector2i(45, 25)
	game.capture_effect.begin(second)
	check(game.capture_effect.new_tech_label.visible and game.capture_effect.banner.text == "Core successfully defended!", "Core two capture announces a new tech")
	add_core(second)
	check(game.hud.visible_tech_ids().has("weapons") and game.research("weapons"), "Core two makes Slugger research available")
	check(not game.hud.visible_tech_ids().has("refining") and not game.research("refining"), "Pink Refining stays gated until core three")
	var third := Vector2i(65, 25)
	game.capture_effect.begin(third)
	check(game.capture_effect.new_tech_label.visible, "Core three capture announces Pink Refining")
	add_core(third)
	check(game.hud.visible_tech_ids().has("refining") and game.research("refining"), "Core three unlocks Pink Refining research")
	game.capture_effect.advance(2)
	check(game.capture_effect.banner.visible and game.capture_effect.pan_started, "Victory banner stays at tutorial position during the camera pan")
	game.capture_effect.begin(Vector2i(85, 25))
	check(not game.capture_effect.new_tech_label.visible, "Captures without new core-gated research omit the subtitle")
	game.capture_effect.cancel()
	game.research("iron_storage", true)
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	await process_frame
	await process_frame
	var view = game.hud.tech_scroll
	var point: Vector2 = game.TECH.refining.pos + Vector2(108, 64)
	var location: Vector2 = point * view.zoom + view.graph.position - Vector2(view.scroll_horizontal, view.scroll_vertical)
	check(location.distance_to(view.size / 2) < 2, "Tree focuses the last researched branch when the newest research is a leaf")
	game.cores.resize(1)
	check(game.tech_core_unlocked("refining"), "Previously reached core research availability survives a rewind")
	print("CORE RESEARCH UNLOCK CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
