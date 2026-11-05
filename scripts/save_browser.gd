extends RefCounted
var hud: CanvasLayer
var selected := -1
var rows: Dictionary = {}
var scroll: ScrollContainer
var timeline: HSlider
var selection_label: Label
var syncing := false
var opened_at := 0
var milestone_markers: Array[Button] = []
func _init(owner: CanvasLayer) -> void:
	hud = owner
static func age_text(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds < 60: return "Just now"
	var parts: Array[String] = []
	var hours := seconds / 3600
	var minutes := (seconds / 60) % 60
	if hours > 0: parts.append("%dh" % hours)
	if minutes > 0: parts.append("%dm" % minutes)
	return " ".join(parts) + " ago"
func show_browser(died: bool = false) -> void:
	opened_at = int(Time.get_unix_time_from_system())
	if hud.game.saves.entries.is_empty() and not died: return
	var content: Panel = hud.modal_panel(Vector2(760, 700))
	hud.label(content, "You Died" if died else "WAVE SAVES", Vector2(24, 18), Vector2(712, 32), 24)
	var subtitle: Label = hud.label(content, "But it's not the end, our chronotech can turn back time." if died else "Choose a checkpoint to roll back time.", Vector2(24, 60), Vector2(712, 28), 16)
	selection_label = hud.label(content, "", Vector2(24, 96), Vector2(680, 26), 15)
	selection_label.visible = false
	timeline = HSlider.new()
	timeline.position = Vector2(32, 130)
	timeline.size = Vector2(696, 28)
	timeline.max_value = maxi(0, hud.game.saves.entries.size() - 1)
	timeline.step = 1
	var track := StyleBoxLine.new()
	track.color = hud.BORDER
	track.thickness = 1
	timeline.add_theme_stylebox_override("slider", track)
	timeline.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	timeline.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]: timeline.add_theme_icon_override(state, load("res://assets/ui/marker.svg"))
	content.add_child(timeline)
	milestone_markers.clear()
	var events: Array[Dictionary] = hud.game.saves.timeline_events()
	for index in events.size():
		var event: Dictionary = events[index]
		var ratio := float(index) / maxi(1, events.size() - 1)
		var x := 8.0 + ratio * (timeline.size.x - 16.0)
		if event.cores > 0: add_milestone(index, x - (10 if not event.research.is_empty() else 0), "core", "Core captured", "%d new core(s) captured at this checkpoint." % event.cores)
		if not event.research.is_empty(): add_milestone(index, x + (10 if event.cores > 0 else 0), "research", "Research unlocked", ", ".join(event.research))
	scroll = ScrollContainer.new()
	scroll.position = Vector2(24, 174)
	scroll.size = Vector2(712, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	rows.clear()
	for i in range(hud.game.saves.entries.size() - 1, -1, -1):
		var entry: Dictionary = hud.game.saves.entries[i]
		var summary: Dictionary = events[i].summary
		var groups: Array = [[load("res://assets/ui/structures.svg"), summary.buildings], [hud.game.textures.solar, summary.turrets], [load("res://assets/ui/milestone_research.svg"), summary.techs]]
		for kind in hud.game.Content.ENEMY_TYPES:
			if summary.enemies.has(kind): groups.append([hud.game.textures[kind], summary.enemies[kind]])
		var stat_rows := ceili(float(groups.size()) / 8.0)
		var height := 106 + stat_rows * 22
		var row: Button = hud.button(list, "", Vector2.ZERO, Vector2(690, height), func(): select_save(i, false))
		row.custom_minimum_size = Vector2(690, height)
		row.set_meta("summary", summary)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var preview := TextureRect.new()
		preview.position = Vector2(8, 8)
		preview.size = Vector2(96, 96)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path: String = hud.game.saves.preview_path(entry.file)
		if FileAccess.file_exists(path): preview.texture = ImageTexture.create_from_image(Image.load_from_file(path))
		row.add_child(preview)
		if preview.texture == null: fill_missing_preview(preview, i)
		hud.label(row, "Wave %d" % entry.wave, Vector2(120, 16), Vector2(540, 32), 21)
		for group_index in groups.size():
			var origin := Vector2(120 + (group_index % 8) * 66, 48 + (group_index / 8) * 22)
			hud.icon(row, groups[group_index][0], origin, Vector2(18, 18))
			hud.label(row, "x%d" % groups[group_index][1], origin + Vector2(22, -1), Vector2(42, 20), 12)
		var age: Label = hud.label(row, "", Vector2(120, 54 + stat_rows * 22), Vector2(540, 20), 15, hud.MUTED)
		row.set_meta("age_label", age)
		row.set_meta("save_time", entry.time)
		var milestones: Array[String] = []
		if events[i].cores > 0: milestones.append("Core captured")
		for upgrade in events[i].research: milestones.append(upgrade)
		if not milestones.is_empty(): hud.label(row, " • ".join(milestones), Vector2(120, 78 + stat_rows * 22), Vector2(540, 18), 11, hud.ACCENT)
		rows[i] = row
	timeline.value_changed.connect(func(value: float):
		if not syncing: select_save(int(value), true)
	)
	var cancel: Button = hud.button(content, "Cancel", Vector2(24, 630), Vector2(340, 44), func():
		hud.close_modal()
	)
	cancel.visible = not died
	var confirm: Button = hud.button(content, "Confirm", Vector2(396, 630), Vector2(340, 44), func(): confirm_restore(selected))
	confirm.disabled = rows.is_empty()
	if not milestone_markers.is_empty():
		hud.icon(content, load("res://assets/ui/milestone_core.svg"), Vector2(24, 601), Vector2(16, 16))
		hud.label(content, "Core capture", Vector2(46, 598), Vector2(140, 24), 12, Color("8fd8e8"))
		hud.icon(content, load("res://assets/ui/milestone_research.svg"), Vector2(210, 601), Vector2(16, 16))
		hud.label(content, "Research unlock", Vector2(232, 598), Vector2(180, 24), 12, hud.ACCENT)
	if rows.is_empty():
		selected = -1
		selection_label.text = "No checkpoints yet."
	else:
		selected = hud.game.saves.entries.size() - 1
		select_save(selected, true)
	update_ages()
func add_milestone(index: int, x: float, kind: String, title: String, description: String) -> void:
	var marker: Button = hud.button(timeline, "", Vector2(x - 9, -20), Vector2(18, 18), func(): select_save(index, true))
	var texture: Texture2D = load("res://assets/ui/milestone_%s.svg" % kind)
	var sprite: TextureRect = hud.icon(marker, texture, Vector2(2, 2), Vector2(14, 14))
	sprite.modulate = Color("8fd8e8") if kind == "core" else hud.ACCENT
	hud.set_info(marker, title, description, "")
	marker.set_meta("milestone", kind)
	marker.set_meta("save_index", index)
	milestone_markers.append(marker)
func update_ages() -> void:
	var now := opened_at
	for row in rows.values():
		if is_instance_valid(row): row.get_meta("age_label").text = age_text(now - int(row.get_meta("save_time")))
func fill_missing_preview(target: TextureRect, index: int) -> void:
	var data: Array = hud.game.saves.load_snapshot(index)
	if data.is_empty(): return
	var entry: Dictionary = hud.game.saves.entries[index]
	var path: String = hud.game.saves.preview_path(entry.file)
	await hud.game.saves.capture_preview(entry.file, data)
	if is_instance_valid(target) and FileAccess.file_exists(path): target.texture = ImageTexture.create_from_image(Image.load_from_file(path))
func start_new_expedition() -> void:
	hud.game.saves.directory = "user://wave_saves_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	hud.game.saves.write_active_directory()
	hud.game.get_tree().reload_current_scene()
func select_save(index: int, reveal: bool) -> void:
	selected = index
	selection_label.text = ""
	for i in rows: rows[i].add_theme_stylebox_override("normal", hud.style(Color("56311f") if i == index else Color.TRANSPARENT))
	syncing = true
	timeline.value = index
	syncing = false
	if reveal: scroll.call_deferred("ensure_control_visible", rows[index])
func confirm_restore(index: int) -> void:
	if index < 0 or index >= hud.game.saves.entries.size(): return
	if hud.game.lost:
		if hud.game.saves.restore(index):
			hud.modal_was_paused = true
			hud.close_modal()
			hud.game.paused = true
		return
	var was_paused: bool = hud.modal_was_paused if is_instance_valid(hud.modal) else hud.game.paused
	var content: Panel = hud.modal_panel(Vector2(560, 260))
	hud.modal_was_paused = was_paused
	hud.label(content, "Return to wave start", Vector2(24, 20), Vector2(512, 32), 24)
	var text: Label = hud.label(content, "Are you sure you want to roll back time?", Vector2(24, 76), Vector2(512, 80), 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.button(content, "Cancel", Vector2(24, 192), Vector2(244, 44), func():
		if hud.game.lost: show_browser(true)
		else: hud.close_modal()
	)
	hud.button(content, "Confirm", Vector2(292, 192), Vector2(244, 44), func():
		if hud.game.saves.restore(index):
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
	hud.label(content, "Continue from wave %d?" % hud.game.saves.entries[-1].wave, Vector2(24, 78), Vector2(512, 36), 18)
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


