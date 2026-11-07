extends RefCounted
var hud: CanvasLayer
var selected := -1
var timeline: HSlider
var milestone_markers: Array[Button] = []
func _init(owner: CanvasLayer) -> void:
	hud = owner
static func age_text(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds < 60: return "Just now"
	var parts: Array[String] = []
	var hours := seconds / 3600
	var minutes := (seconds / 60) % 60
	if hours > 0: parts.append("%sh" % preload("res://scripts/display_numbers.gd").format(hours))
	if minutes > 0: parts.append("%sm" % preload("res://scripts/display_numbers.gd").format(minutes))
	return " ".join(parts) + " ago"
func show_browser(_died: bool = false) -> void:
	hud.game.tutorial.on_wave_menu_opened()
	var content: Panel = hud.modal_panel(Vector2(920, 430))
	hud.label(content, "Wave saves", Vector2(24, 16), Vector2(860, 38), 26)
	var scroll := ScrollContainer.new()
	scroll.set_script(preload("res://scripts/save_timeline_scroll.gd"))
	scroll.name = "SaveTimeline"
	scroll.position = Vector2(24, 66)
	scroll.size = Vector2(872, 244)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var slider := HSlider.new()
	slider.name = "TimelineSlider"
	slider.position = Vector2(24, 322)
	slider.size = Vector2(872, 28)
	slider.max_value = 1.0
	slider.step = 0.001
	scroll.slider = slider
	content.add_child(scroll)
	var list := HBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var group := -1
	var now := int(Time.get_unix_time_from_system())
	for index in hud.game.saves.entries.size():
		var snapshot: Array = hud.game.saves.load_snapshot(index)
		if snapshot.is_empty(): continue
		var core_number: int = snapshot[1][10].size()
		if core_number != group:
			group = core_number
			var header := VBoxContainer.new()
			header.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header.custom_minimum_size = Vector2(64, 228)
			list.add_child(header)
			var title := Label.new()
			title.text = "Core %02d" % group
			title.add_theme_font_size_override("font_size", 12)
			title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header.add_child(title)
			var line := VSeparator.new()
			line.size_flags_vertical = Control.SIZE_EXPAND_FILL
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header.add_child(line)
		var entry: Dictionary = hud.game.saves.entries[index]
		var card: Button = hud.button(list, "", Vector2.ZERO, Vector2(200, 228), func():
			if hud.game.lost:
				if hud.game.saves.restore(index):
					hud.game.tutorial.on_wave_menu_loaded()
					hud.modal_was_paused = true
					hud.close_modal()
			else: confirm_restore(index, false, true)
		)
		card.custom_minimum_size = Vector2(200, 228)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_meta("save_index", index)
		# Grid containers own positioning; hover must never offset their children.
		card.set_meta("save_card", true)
		populate_thumbnail(card, entry.file, snapshot)
		var caption: Label = hud.label(card, "Wave %s" % preload("res://scripts/display_numbers.gd").format(entry.wave), Vector2(8, 186), Vector2(184, 22), 17)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var age: Label = hud.label(card, age_text(now - hud.game.saves.last_played(index)), Vector2(8, 210), Vector2(184, 18), 12, hud.MUTED)
		age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(slider)
	scroll.call_deferred("scroll_to_newest")
	if not hud.game.lost:
		hud.button(content, "Cancel", Vector2(340, 366), Vector2(240, 44), hud.close_modal)
	elif hud.game.saves.entries.is_empty():
		hud.label(content, "No checkpoints available.", Vector2(24, 90), Vector2(860, 40), 18)

func populate_thumbnail(card: Button, name: String, snapshot: Array) -> void:
	var path: String = hud.game.saves.preview_path(name)
	if not FileAccess.file_exists(path): await hud.game.saves.capture_preview(name, snapshot)
	if not is_instance_valid(card) or not FileAccess.file_exists(path): return
	var picture := Image.load_from_file(path)
	if picture == null: return
	var image := TextureRect.new()
	image.texture = ImageTexture.create_from_image(picture)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = Vector2(12, 8)
	image.size = Vector2(176, 176)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)

func available() -> bool:
	# Recognize expeditions saved before this reveal flag existed.
	for gate in hud.game.spawners:
		if gate.waves_completed >= 2: hud.game.tutorial.ui_revealed.wave_saves = true
	return hud.game.tutorial.ui_revealed.get("wave_saves", false) or hud.game.tutorial.ui_revealed.get("loss_saves_revealed", false) or hud.game.tutorial.skipped or not hud.game.tutorial_enabled
func add_milestone(index: int, x: float, kind: String, title: String, description: String) -> void:
	var marker: Button = hud.button(timeline, "", Vector2(x - 9, -20), Vector2(18, 18), func():
		begin_scrub()
		preview_save(index)
		finish_scrub()
	)
	var texture: Texture2D = load("res://assets/ui/milestone_%s.svg" % kind)
	var sprite: TextureRect = hud.icon(marker, texture, Vector2(2, 2), Vector2(14, 14))
	sprite.modulate = Color("8fd8e8") if kind == "core" else hud.ACCENT
	hud.set_info(marker, title, description, "")
	marker.set_meta("milestone", kind)
	marker.set_meta("save_index", index)
	milestone_markers.append(marker)
func confirm_restore(index: int, restart: bool = false, from_browser: bool = false) -> void:
	hud.game.tutorial.on_timeline_used()
	if index < 0 or index >= hud.game.saves.entries.size(): return
	var was_paused: bool = hud.modal_was_paused if is_instance_valid(hud.modal) else hud.game.paused
	var content: Panel = hud.modal_panel(Vector2(560, 260))
	hud.modal_was_paused = was_paused
	hud.label(content, "Return to wave start", Vector2(24, 20), Vector2(512, 32), 24)
	var text: Label = hud.label(content, "Are you sure you want to restart the current wave?" if restart else "Are you sure you want to rewind back to wave %s?" % preload("res://scripts/display_numbers.gd").format(hud.game.saves.entries[index].wave), Vector2(24, 76), Vector2(512, 80), 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.button(content, "Cancel", Vector2(24, 192), Vector2(244, 44), func():
		hud.close_modal()
	)
	hud.button(content, "Confirm", Vector2(292, 192), Vector2(244, 44), func():
		if hud.game.saves.restore(index):
			if from_browser: hud.game.tutorial.on_wave_menu_loaded()
			hud.modal_was_paused = true
			hud.close_modal()
			hud.game.paused = true
		else:
			text.text = hud.game.saves.last_error
	)
func show_continue() -> void:
	if hud.game.saves.entries.is_empty(): return
	var content: Panel = hud.modal_panel(Vector2(560, 240))
	hud.label(content, "Saved expedition", Vector2(24, 20), Vector2(512, 32), 24)
	hud.label(content, "Continue from wave %s?" % preload("res://scripts/display_numbers.gd").format(hud.game.saves.entries[-1].wave), Vector2(24, 78), Vector2(512, 36), 18)
	hud.button(content, "New expedition", Vector2(24, 168), Vector2(244, 44), func():
		# Keep the previous expedition as an archive; start a fresh history.
		hud.game.saves.directory = "user://wave_saves_" + str(Time.get_unix_time_from_system()).replace(".", "_")
		hud.game.saves.entries.clear()
		hud.game.saves.current = -1
		hud.game.saves.write_active_directory()
		hud.game.get_tree().reload_current_scene()
	)
	hud.button(content, "Continue", Vector2(292, 168), Vector2(244, 44), func():
		if hud.game.saves.restore(hud.game.saves.entries.size() - 1):
			hud.modal_was_paused = true
			hud.close_modal()
	)




var strip: Control
var wave_caption: Label
var death_title: Label
var dragging := false
var original_camera := Vector2.ZERO
var original_paused := false
var preview: Node2D
var cached_count := -1
func build_timeline() -> void:
	strip = Control.new()
	strip.name = "PersistentTimeline"
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 24
	strip.offset_right = -24
	strip.offset_top = -122
	strip.offset_bottom = -76
	hud.root.add_child(strip)
	hud.ui_regions.append(strip)
	timeline = HSlider.new()
	timeline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timeline.offset_top = 20
	timeline.step = 1
	var track := StyleBoxLine.new()
	track.color = hud.BORDER
	track.thickness = 2
	timeline.add_theme_stylebox_override("slider", track)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		timeline.add_theme_icon_override(state, preload("res://scripts/pixel_art.gd").texture(load("res://assets/ui/marker.svg"), Vector2i(32, 32)))
	strip.add_child(timeline)
	timeline.drag_started.connect(begin_scrub)
	timeline.value_changed.connect(func(value: float):
		if dragging: preview_save(int(value))
	)
	timeline.drag_ended.connect(func(_changed: bool): finish_scrub())
	wave_caption = hud.label(strip, "", Vector2.ZERO, Vector2(500, 22), 15)
	death_title = hud.label(hud.root, "You lost your core.", Vector2.ZERO, Vector2(1000, 70), 46, Color("f05b55"))
	death_title.anchor_left = 0.5
	death_title.anchor_right = 0.5
	death_title.anchor_top = 0.5
	death_title.anchor_bottom = 0.5
	death_title.offset_left = -500
	death_title.offset_right = 500
	death_title.offset_top = -65
	death_title.offset_bottom = 5
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title.visible = false
func refresh_timeline() -> void:
	if not is_instance_valid(strip): return
	strip.visible = false
	death_title.visible = hud.game.lost
	if hud.game.lost:
		hud.tutorial_prompt.anchor_top = 0.5
		hud.tutorial_prompt.anchor_bottom = 0.5
		hud.tutorial_prompt.offset_top = 12
		hud.tutorial_prompt.offset_bottom = 150
	else:
		hud.tutorial_prompt.anchor_top = 0
		hud.tutorial_prompt.anchor_bottom = 0
		hud.tutorial_prompt.offset_top = 104
		hud.tutorial_prompt.offset_bottom = 284
	strip.modulate = Color.WHITE
	var count: int = hud.game.saves.entries.size()
	timeline.editable = count > 0
	if count != cached_count:
		cached_count = count
		timeline.max_value = maxi(0, count - 1)
		for child in timeline.get_children(): child.queue_free()
		milestone_markers.clear()
		var events: Array[Dictionary] = hud.game.saves.timeline_events()
		for i in count:
			var mark := ColorRect.new()
			mark.color = hud.ACCENT
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.anchor_left = float(i) / maxi(1, count - 1)
			mark.anchor_right = mark.anchor_left
			mark.position.y = 7
			mark.size = Vector2(2, 12)
			timeline.add_child(mark)
			var event: Dictionary = events[i]
			if event.cores > 0: add_milestone(i, float(i) / maxi(1, count - 1) * timeline.size.x, "core", "Core captured", "%s new cores." % preload("res://scripts/display_numbers.gd").format(event.cores))
	if not dragging:
		selected = hud.game.saves.current
		timeline.set_value_no_signal(maxi(0, hud.game.saves.current))
		wave_caption.text = "Wave %s" % preload("res://scripts/display_numbers.gd").format(hud.game.saves.entries[selected].wave) if selected >= 0 and selected < count else ""
func begin_scrub() -> void:
	hud.game.tutorial.on_timeline_used()
	if hud.game.saves.entries.is_empty(): return
	dragging = true
	original_camera = hud.game.camera.position
	original_paused = hud.game.paused
	hud.game.paused = true
	preview_save(int(timeline.value))
func preview_save(index: int) -> void:
	var data: Array = hud.game.saves.load_snapshot(index)
	if data.is_empty(): return
	selected = index
	wave_caption.text = "Wave %s" % preload("res://scripts/display_numbers.gd").format(hud.game.saves.entries[index].wave)
	if is_instance_valid(preview): preview.queue_free()
	preview = Node2D.new()
	preview.z_index = 300
	hud.game.add_child(preview)
	var backdrop := preview
	backdrop.draw.connect(func(): backdrop.draw_rect(Rect2(-100000, -100000, 200000, 200000), Color("101d22")))
	var world := Node2D.new()
	world.set_script(preload("res://scripts/save_preview.gd"))
	world.configure(hud.game, data)
	preview.add_child(world)
	hud.game.camera.position = hud.game.cell_center(data[1][9])
	hud.game.camera.force_update_scroll()
func finish_scrub() -> void:
	if not dragging: return
	dragging = false
	if is_instance_valid(preview): preview.queue_free()
	hud.game.camera.position = original_camera
	hud.game.paused = original_paused
	if selected >= 0 and (selected != hud.game.saves.current or hud.game.lost or hud.game.wave_in_progress): confirm_restore(selected)






