extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	game.core_build_radius = 100000
	game.separate_build_categories = true
	game.researched["barriers"] = true
	game.researched["weapons"] = true
	game.researched["industry"] = true
	for kind in ["turret", "repeater", "cannon"]:
		for color in ["red", "green", "blue"]: game.researched[kind + "_" + color] = true
	game.base_copper_capacity = 500
	root.add_child(game)
	game.tutorial.extractors_ever_built = 1
	game.tutorial.extractor_connected_once = true
	game.tutorial.waves_started = true
	game.tutorial.tech_available = true
	game.selected = "belt"
	game.set_process(false)
	game.audio.muted = true
	game.inventory.copper = 0
	game.inventory.iron = 0
	game.hud.toggle_category("Defense")
	game.hud.preview_kind = "turret"
	game.hud.refresh()
	game.report_shortage(game.building_cost("turret"), Vector2i(25, 20))
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shortage_feedback.png")
	print("SHORTAGE CAPTURE COMPLETE")
	quit()


