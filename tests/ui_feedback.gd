extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
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
	game.fog_disabled = true
	game.rocks.clear()
	game.hud.toggle_category("Defense")
	check(game.hud.cards.size() == 3 and game.hud.cards.has("turret") and not game.hud.cards.has("repeater") and not game.hud.cards.has("cannon"), "Build menus hide unresearched buildings")
	check(game.hud.expanded.size.x == 564 and game.hud.expanded.size.y == 104, "Category tray fits its unlocked building cards")
	check(game.hud.tray_tween.is_valid() and game.hud.expanded.modulate.a < 1, "Opening a category starts an upward slide and fade")
	await create_timer(0.19).timeout
	check(is_equal_approx(game.hud.expanded.modulate.a, 1.0), "Category opening animation settles after 150 milliseconds")
	var card: Button = game.hud.cards.turret
	var card_id: int = card.get_instance_id()
	game.inventory.copper = 0
	game.inventory.iron = 0
	game.hud.refresh()
	check(game.hud.card_views.turret.shade.visible and game.hud.card_views.turret.shade.color.a > 0.4, "Unaffordable buildings receive a transparent black overlay")
	var red_prices := true
	for amount in game.hud.card_views.turret.amounts.values(): red_prices = red_prices and amount.get_theme_color("font_color") == game.hud.ERROR_COLOR
	check(red_prices, "Every price amount is red on an unaffordable building")
	check(not game.place_building(Vector2i(25, 20), "turret", 0, "red"), "Unaffordable construction fails without placing a building")
	check(game.hud.last_shortage_message == "Not enough Copper, Iron...", "Construction shortage feedback names the actual missing resources")
	check(not game.hud.feedback_labels.is_empty() and game.hud.feedback_labels[-1].get_theme_color("font_color") == game.hud.ERROR_COLOR, "Shortage feedback is rendered as floating red text")
	var feedback: Label = game.hud.feedback_labels[-1]
	var initial_y: float = feedback.position.y
	await create_timer(0.10).timeout
	check(feedback.position.y < initial_y, "Shortage text animates upward")
	game.inventory.copper = 200
	game.inventory.iron = 100
	game.hud.refresh()
	check(not game.hud.card_views.turret.shade.visible, "Affordability overlay clears when resources become available")
	check(game.hud.cards.turret.get_instance_id() == card_id, "Price and stock changes preserve card instances and hover state")
	card.mouse_entered.emit()
	game.hud.refresh()
	check(game.hud.preview_kind == "turret" and game.hud.resource_views.copper.deduction.text == "-35" and game.hud.resource_views.iron.deduction.text == "-12", "Hovering a building previews deductions beside its materials")
	var rest: Vector2 = card.get_meta("rest_position")
	await create_timer(0.11).timeout
	check(is_equal_approx(card.position.y, rest.y - 2), "Hovered buttons lift two pixels")
	card.button_down.emit()
	await create_timer(0.11).timeout
	check(is_equal_approx(card.position.y, rest.y + 1), "Pressed buttons recess before release")
	card.button_up.emit()
	card.mouse_exited.emit()
	game.hud.refresh()
	check(game.hud.preview_kind == "" and game.hud.resource_views.copper.deduction.text == "", "Resource cost preview clears when the hover ends")
	await create_timer(0.22).timeout
	var old_display: float = game.hud.displayed_amounts.copper
	game.inventory.copper += 7
	game.hud.refresh()
	check(game.hud.amount_tweens.copper.is_valid() and game.hud.displayed_amounts.copper == old_display, "Resource counters roll instead of immediately jumping")
	await create_timer(0.22).timeout
	check(game.hud.resources.copper.text == str(game.inventory.copper), "Animated resource counters settle on the exact inventory")
	check(game.hud.resource_views.copper.capacity.text == "/ 500", "Capacity is shown separately from the larger owned amount")
	check(is_equal_approx(game.hud.resource_views.copper.fill.size.x, 132.0 * game.inventory.copper / 500.0), "Material capacity bar reflects the actual fill ratio")
	game.hud.pending_gains.copper = 5
	game.hud.gain_clock = 0.28
	game.hud._process(0)
	var gain_label := false
	for caption in game.hud.feedback_labels:
		if caption.text == "+5": gain_label = true
	check(gain_label and game.hud.resource_views.copper.icon.get_meta("pulse_tween").is_valid(), "Grouped income creates a gain label and icon pulse")
	game.inventory.verdite = 0
	check(game.missing_resources({"copper": 2, "verdite": 3}) == ["Verdite"], "Shortage lists exclude materials that are already sufficient")
	check(game.hud.palette.position.x == 0 and game.hud.palette.offset_bottom == 0, "Bottom toolbar has zero outer screen margin")
	var framed_panels := true
	for region in game.hud.ui_regions:
		if is_instance_valid(region): framed_panels = framed_panels and region.get_theme_stylebox("panel") is StyleBoxFlat
	check(framed_panels, "GUI containers retain black backgrounds and tan frames")
	var button_style: StyleBoxFlat = card.get_theme_stylebox("normal")
	check(button_style.get_margin(SIDE_LEFT) == 0 and button_style.border_width_left == 2, "Buttons retain zero margin with a two-pixel outline")
	game.inventory.copper = 300
	game.inventory.iron = 200
	check(game.research("repeater"), "Research can unlock a building after the menu was created")
	game.hud.refresh()
	check(game.hud.cards.has("repeater") and not game.hud.cards.has("cannon"), "Research reveals only newly unlocked designs")
	var valid_audio: bool = game.audio.streams.size() == 16
	for id in game.audio.streams:
		var stream: AudioStreamWAV = game.audio.streams[id]
		valid_audio = valid_audio and stream != null and stream.get_length() > 0.02 and stream.get_length() <= (2.5 if id == "core_capture" else 1.05) and stream.data.size() > 0
		var peak := 0
		for index in range(0, stream.data.size() - 1, 2): peak = maxi(peak, absi(stream.data.decode_s16(index)))
		valid_audio = valid_audio and peak > 200 and peak < 32767
	check(valid_audio, "All sixteen active generated WAVs load, contain audible signal and avoid clipping")
	check(game.audio.ui_voices.size() == 6 and game.audio.world_voices.size() == 12, "UI and positional game sounds use bounded voice pools")
	var before: bool = game.audio.muted
	game.toggle_audio()
	check(game.audio.muted != before, "Sound mute control toggles audio")
	game.audio.muted = false
	game.audio.cooldowns.clear()
	var ui_voice: int = game.audio.ui_index
	game.audio.play("ui_click")
	check(game.audio.ui_voices[ui_voice].playing, "Generated UI sound plays through the UI voice pool")
	var world_voice: int = game.audio.world_index
	game.audio.play("shot", game.cell_center(game.CORE))
	check(game.audio.world_voices[world_voice].playing, "Generated combat sound plays as a positional world effect")
	var next_voice: int = game.audio.world_index
	game.audio.play("shot", game.cell_center(game.CORE))
	check(game.audio.world_index == next_voice, "Rapid duplicate effects are rate limited")
	game.audio.toggle_mute()
	check(not game.audio.ui_voices[ui_voice].playing and not game.audio.world_voices[world_voice].playing, "Muting immediately stops active UI and world sounds")
	game.audio.muted = true
	print("UI AND AUDIO CHECKS: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	quit(0 if failures == 0 else 1)








