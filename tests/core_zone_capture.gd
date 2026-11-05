extends SceneTree
class PreviewGame extends "res://scripts/game.gd":
	func _draw() -> void:
		super._draw()
		if selected != "": _draw_cursor()
var game
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/core_%s.png" % name)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.set_script(PreviewGame)
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.hud.ghost_cost.set_process(false)
	game.audio.muted = true
	game.tutorial.stage = game.tutorial.Stage.READY
	game.tutorial.onboarding_completed = true
	game.tutorial.waves_started = true
	game.tutorial.first_wave_completed = true
	game.tutorial.paused_once = true
	game.tutorial.pause_exit_completed = true
	game.tutorial.barrier_tree_closed = true
	game.tutorial.info_hover_time = 2.0
	game.tutorial.category_visits = {"Infrastructure": true, "Defence": true}
	game.research("barriers", true)
	game.inventory.copper = 35
	game.add_resource("scrap", 15)
	game.fog_disabled = true
	game.rocks.clear()
	var old: Vector2i = game.current_core
	var latest: Vector2i = old + Vector2i(32, 0)
	game._add_building(old + Vector2i(3, 0), "solar", 0)
	game._add_building(old + Vector2i(5, 0), "solar", 0)
	game._add_building(latest, "core", 0)
	game.cores.append(latest)
	game.current_core = latest
	game.tutorial.on_new_core(latest)
	game._reveal_map()
	await shot("move_right")
	game.camera.position = game.cell_center(latest)
	game.camera.force_update_scroll()
	await shot("defend")
	game._add_building(latest + Vector2i(3, 0), "solar", 0)
	game._add_building(latest + Vector2i(2, 2), "wall", 0)
	game.selected = "solar"
	game.hover_cell = latest + Vector2i(2, 2)
	game.hud.ghost_cost.update_preview(Vector2(700, 400))
	await shot("ghost_price")
	game.tutorial.next_core_stage = 3
	game.selected = ""
	game.hud.ghost_cost.hide()
	game.hud.announce_wave(7)
	game.place_building(latest + Vector2i(0, 21), "solar", 0, "red")
	await shot("wave_error")
	quit()
