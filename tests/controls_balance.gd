extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	game.saves.directory = "res://.godot/controls_balance_check"
	game.saves.entries.clear()
	game.saves.current = -1
	game.wave = 2
	game.saves.capture()
	game.wave = 3
	game.hud.refresh()
	var browser = game.hud.save_browser
	check(browser.wave_caption.text == "Wave 2", "Timeline label shows selected checkpoint wave rather than live wave")
	game.hud.toggle_category("Structures")
	game.hud.refresh()
	check(not browser.strip.visible, "Building tray hides timeline")
	game.cancel_build_selection()
	game.hud.refresh()
	check(browser.strip.visible, "Closing building tray restores timeline")
	game.lost = true
	game.hud.refresh()
	game.hud._process(0.01)
	check(browser.strip.modulate == Color.WHITE and game.hud.back_button.get_meta("tutorial_glow", false), "Death highlights rewind arrow instead of timeline")
	check(game.hud.tutorial_prompt.text == "Use the arrow button or timeline to roll back time.", "Death instruction names both recovery controls")
	game.lost = false
	game.paused = true
	game.spawn_remaining = 0
	game.wave_in_progress = false
	game.request_next_wave()
	check(not game.paused and game.wave_warp_active, "Wave shortcut unpauses and requests next wave")
	game.cancel_wave_warp()
	game.speed = 1
	game.cycle_speed()
	check(game.speed == 5 and game.wave_warp_speed() == 5, "Fast speed is five times normal")
	game.cycle_speed()
	check(game.speed == 1, "Speed button returns to normal")
	check(game.TECH.turret_range.cost.copper == 5 and game.TECH.copper_storage.cost.copper == 10, "Research copper prices are reduced")
	check(game.enemy_health("scout", 1) == floorf(game.Content.ENEMY_TYPES.scout.hp / 10.0) * 3, "Enemy health is tripled")
	game.hud.refresh()
	check(game.hud.speed_button.icon.get_size() == Vector2(32, 32), "GUI icons render at thirty-two pixels")
	var position: Vector2 = game.camera.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(600, 400)
	game._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 420)
	motion.relative = Vector2(40, 20)
	game._input(motion)
	check(game.camera.position != position, "Right dragging pans world camera")
	press.pressed = false
	game._input(press)
	check(not game.camera_right_held, "Releasing right mouse ends camera drag")
	game.tutorial.tech_available = true
	game.hud.show_tech_tree()
	var tree = game.hud.tech_scroll
	press.pressed = true
	press.position = tree.get_global_rect().get_center()
	tree._input(press)
	check(tree.panning and tree.pan_button == MOUSE_BUTTON_RIGHT, "Right dragging also pans tech tree")
	press.pressed = false
	tree._input(press)
	check(not tree.panning, "Right release ends tech tree drag")
	game.hud.close_modal()
	print("CONTROLS AND BALANCE CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)

