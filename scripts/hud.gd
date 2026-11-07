extends CanvasLayer
const INK := Color("f3ded5")
const MUTED := Color("b29a91")
const ACCENT := Color("edb183")
const BACK := Color("0c080a")
const BORDER := Color("bb8967")
const ERROR_COLOR := Color("ff716c")
const UI_SCALE := 1.5
var game: Node2D
var root: Control
var info_root: Control
var modal: ColorRect
var modal_was_paused := false
var next_wave_label: Label
var rewind_effect: Control

func capture_rewind_frame() -> Dictionary:
	var frame: Texture2D
	if DisplayServer.get_name() != "headless": frame = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var ghosts: Array = []
	var traces: Array = []
	var transform: Transform2D = game.get_canvas_transform()
	for enemy in game.enemies:
		ghosts.append({"pos": transform * enemy.pos, "velocity": enemy.get("velocity", Vector2.ZERO) * game.camera.zoom, "angle": enemy.angle, "scale": game.camera.zoom.x, "texture": game.textures[enemy.kind], "size": game.Content.ENEMY_TYPES[enemy.kind].size, "color": game.TEAM_COLORS[enemy.color]})
	for shot in game.shots: traces.append({"from": transform * shot.from, "to": transform * shot.to, "color": shot.color})
	return {"frame": frame, "ghosts": ghosts, "traces": traces}

func play_rewind_effect(before: Dictionary) -> void:
	if is_instance_valid(rewind_effect): rewind_effect.queue_free()
	rewind_effect = Control.new()
	rewind_effect.set_script(preload("res://scripts/rewind_effect.gd"))
	rewind_effect.material = game.material
	rewind_effect.frame = before.frame
	rewind_effect.ghosts = before.ghosts
	rewind_effect.traces = before.traces
	for ghost in rewind_effect.ghosts:
		ghost.pos = ui_point(ghost.pos)
		ghost.velocity /= UI_SCALE
		ghost.scale /= UI_SCALE
	for trace in rewind_effect.traces:
		trace.from = ui_point(trace.from)
		trace.to = ui_point(trace.to)
	root.add_child(rewind_effect)
	game.play_sound("rewind")
var radial: Control
var resources: Dictionary = {}
var resource_views: Dictionary = {}
var displayed_amounts: Dictionary = {}
var previous_amounts: Dictionary = {}
var amount_tweens: Dictionary = {}
var pending_gains: Dictionary = {}
var gain_clock := 0.0
var preview_kind := ""
var hovered_core := Vector2i(-1000, -1000)
var inventory_panel: Panel
var map_panel: Panel
var wave_controls: Panel
var tech_button: Button
var tutorial_prompt: Label
var tech_graph: Control
var tech_scroll: ScrollContainer
var wave_label: Label
var notice_label: Label
var wave_announcement: Label
var wave_announcement_tween: Tween
var ghost_cost: Control
var tool_hint: Label
var next_button: Button
var speed_button: Button
var pause_button: Button
var mute_icon: TextureRect
var palette: Panel
var expanded: Panel
var tray_tween: Tween
var category := ""
var category_buttons: Dictionary = {}
var tool_buttons: Dictionary = {}
var cards: Dictionary = {}
var card_views: Dictionary = {}
var tech_buttons: Dictionary = {}
var tech_resource_labels: Dictionary = {}
var minimap: Control
var tooltip: Panel
var tooltip_title: Label
var tooltip_body: RichTextLabel
var ui_regions: Array[Control] = []
var research_signature := -1
var price_signature := -1
var shortage_cooldown := 0.0
var last_shortage_message := ""
var feedback_labels: Array[Label] = []
var back_button: Button
var demolish_button: Button
var saves_button: Button
var save_browser: RefCounted
var tooltip_layer: CanvasLayer
var screen_edges: ColorRect
var color_dots: Control
var tooltip_identity := ""
var info_fade: Tween
var last_info_msec := -1000
var hovered_enemy: Dictionary = {}
var shortcuts_label: Label
var tech_material_strip: Control
var tech_material_signature := -1

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2.ONE * UI_SCALE
	root.size = get_viewport().get_visible_rect().size / UI_SCALE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = preload("res://PixelifySans.ttf")
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color("fff1e6"))
	theme.set_color("font_disabled_color", "Button", MUTED)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var tint := Color(0.20, 0.09, 0.10, 0.85) if state in ["hover", "pressed"] else Color.TRANSPARENT
		theme.set_stylebox(state, "Button", style(tint))
	theme.set_stylebox("panel", "TooltipPanel", style(BACK))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_color("font_shadow_color", "Label", Color(0.025, 0.008, 0.01, 0.95))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	root.theme = theme
	screen_edges = ColorRect.new()
	screen_edges.name = "ModeGlow"
	screen_edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_edges.z_index = -10
	var edge_material := ShaderMaterial.new()
	edge_material.shader = load("res://scripts/screen_edges.gdshader")
	screen_edges.material = edge_material
	root.add_child(screen_edges)
	_build_resources()
	_build_palette()
	_build_map()
	_build_wave_controls()
	save_browser = preload("res://scripts/save_browser.gd").new(self)
	save_browser.build_timeline()
	tutorial_prompt = label(root, "Press and hold on an ore deposit.", Vector2.ZERO, Vector2(1200, 180), 24, Color("ffe494"))
	tutorial_prompt.anchor_left = 0.5
	tutorial_prompt.anchor_right = 0.5
	tutorial_prompt.offset_left = -450
	tutorial_prompt.offset_right = 450
	tutorial_prompt.anchor_top = 0
	tutorial_prompt.anchor_bottom = 0
	tutorial_prompt.offset_top = 104
	tutorial_prompt.offset_bottom = 284
	tutorial_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_prompt.clip_text = false
	tutorial_prompt.add_theme_color_override("font_shadow_color", Color(1, 0.7, 0.1, 0.5))
	tutorial_prompt.add_theme_constant_override("shadow_outline_size", 6)
	tutorial_prompt.add_theme_constant_override("shadow_offset_x", 0)
	tutorial_prompt.add_theme_constant_override("shadow_offset_y", 0)
	tutorial_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label = label(root, "", Vector2(0, 72), Vector2(870, 26), 13, MUTED)
	wave_announcement = label(root, "", Vector2(-300, -142), Vector2(600, 60), 34, INK)
	wave_announcement.anchor_left = 0.5
	wave_announcement.anchor_right = 0.5
	wave_announcement.anchor_top = 1
	wave_announcement.anchor_bottom = 1
	wave_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_announcement.add_theme_color_override("font_shadow_color", Color.BLACK)
	wave_announcement.add_theme_constant_override("shadow_outline_size", 4)
	ghost_cost = Control.new()
	ghost_cost.set_script(preload("res://scripts/ghost_cost.gd"))
	ghost_cost.game = game
	ghost_cost.hud = self
	root.add_child(ghost_cost)
	tool_hint = label(root, "", Vector2(0, -100), Vector2(990, 24), 12, MUTED)
	tool_hint.anchor_top = 1
	tool_hint.anchor_bottom = 1
	shortcuts_label = label(root, "", Vector2(-248, -286), Vector2(240, 160), 13, Color.WHITE)
	shortcuts_label.anchor_left = 1
	shortcuts_label.anchor_right = 1
	shortcuts_label.anchor_top = 1
	shortcuts_label.anchor_bottom = 1
	shortcuts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shortcuts_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	shortcuts_label.add_theme_constant_override("shadow_outline_size", 2)
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 100
	add_child(tooltip_layer)
	info_root = Control.new()
	info_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info_root.scale = Vector2.ONE * UI_SCALE
	info_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_root.theme = theme
	tooltip_layer.add_child(info_root)
	tooltip = panel(Vector2.ZERO, Vector2(330, 120), info_root)
	ui_regions.erase(tooltip)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_title = label(tooltip, "", Vector2(8, 8), Vector2(314, 26), 15)
	tooltip_body = RichTextLabel.new()
	tooltip_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tooltip_body.position = Vector2(8, 40)
	tooltip_body.size = Vector2(314, 72)
	tooltip_body.bbcode_enabled = true
	tooltip_body.scroll_active = false
	tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_body.add_theme_font_size_override("normal_font_size", 13)
	tooltip_body.add_theme_color_override("default_color", INK)
	tooltip.add_child(tooltip_body)
	tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	color_dots = Control.new()
	color_dots.set_script(load("res://scripts/color_dots.gd"))
	color_dots.material = game.material
	color_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(color_dots)
	tooltip.hide()
	get_viewport().size_changed.connect(resize_ui)
	resize_ui()
	apply_graphics_style(root)
	apply_graphics_style(info_root)
	refresh()
func apply_graphics_style(node: Node) -> void:
	if node == ghost_cost or node is Label or node is RichTextLabel or node is TextureRect:
		node.material = null
		node.use_parent_material = false
	elif node is CanvasItem and node.material == null:
		node.material = game.material
	for child in node.get_children(): apply_graphics_style(child)
func ui_point(screen_point: Vector2) -> Vector2:
	return root.get_global_transform().affine_inverse() * screen_point
func resize_ui() -> void:
	root.size = get_viewport().get_visible_rect().size / UI_SCALE
	info_root.size = root.size
	var width := maxf(300, root.size.x - 32)
	tutorial_prompt.offset_left = -width / 2
	tutorial_prompt.offset_right = width / 2
	if is_instance_valid(modal):
		for child in modal.get_children():
			if child is Panel: fit_dialog(child)
func fit_dialog(content: Control) -> void:
	var factor := minf(1.0, minf((root.size.x - 24) / content.size.x, (root.size.y - 24) / content.size.y))
	content.pivot_offset = content.size / 2
	content.scale = Vector2.ONE * factor
func style(background: Color, _border: Color = BORDER, width: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BACK if background.a == 0 else background
	box.border_color = BORDER
	box.set_border_width_all(2)
	box.set_content_margin_all(0)
	return box
func panel(pos: Vector2, dimensions: Vector2, parent: Control = null) -> Panel:
	if parent == null: parent = root
	var result := Panel.new()
	result.position = pos
	result.size = dimensions
	result.add_theme_stylebox_override("panel", style(BACK))
	result.material = game.material
	parent.add_child(result)
	ui_regions.append(result)
	return result
func label(parent: Control, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 14, color: Color = INK) -> Label:
	var result := Label.new()
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.clip_text = true
	result.text = text
	result.position = pos
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.size = dimensions
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
func button(parent: Control, text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var result := Button.new()
	result.set_script(preload("res://scripts/pixel_button.gd"))
	result.material = game.material
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.text = text
	result.position = pos
	result.size = dimensions
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.focus_mode = Control.FOCUS_NONE
	result.set_meta("rest_position", pos)
	result.set_meta("hovered", false)
	result.set_meta("held", false)
	result.mouse_entered.connect(func():
		result.set_meta("hovered", true)
		animate_button(result)
		game.play_sound("ui_hover")
	)
	result.mouse_exited.connect(func():
		result.set_meta("hovered", false)
		animate_button(result)
	)
	result.button_down.connect(func():
		result.set_meta("held", true)
		animate_button(result)
	)
	result.button_up.connect(func():
		result.set_meta("held", false)
		animate_button(result)
	)
	result.pressed.connect(func(): game.play_sound("ui_click"))
	result.pressed.connect(callback)
	parent.add_child(result)
	return result
func animate_button(target: Button) -> void:
	if target.get_parent() is Container: return
	var old_tween = target.get_meta("motion_tween") if target.has_meta("motion_tween") else null
	if old_tween is Tween and old_tween.is_valid(): old_tween.kill()
	var origin: Vector2 = target.get_meta("rest_position")
	var offset := 1.0 if target.get_meta("held") else (-2.0 if target.get_meta("hovered") else 0.0)
	var motion := target.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(target, "position:y", origin.y + offset, 0.09)
	target.set_meta("motion_tween", motion)
func icon(parent: Control, texture: Texture2D, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var result := TextureRect.new()
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.texture = preload("res://scripts/pixel_art.gd").texture(texture, Vector2i.ONE * 32)
	result.position = pos
	result.size = dimensions
	result.pivot_offset = dimensions / 2
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
func cost_row(parent: Control, cost: Dictionary, pos: Vector2) -> Dictionary:
	var amounts: Dictionary = {}
	var x := 0.0
	var sprites: Array[TextureRect] = []
	for resource in cost:
		var sprite := icon(parent, game.ui_textures[resource + "_item"], pos + Vector2(x, 0), Vector2(16, 16))
		sprite.z_index = 2
		sprites.append(sprite)
		amounts[resource] = label(parent, preload("res://scripts/display_numbers.gd").format(cost[resource]), pos + Vector2(x + 18, -1), Vector2(24, 22), 12, MUTED)
		amounts[resource].z_index = 2
		x += 42
	parent.set_meta("cost_labels", amounts)
	parent.set_meta("cost_sprites", sprites)
	parent.set_meta("cost_position", pos)
	layout_cost_amounts(parent, amounts, cost, pos)
	return amounts
func layout_cost_amounts(parent: Control, amounts: Dictionary, cost: Dictionary, pos: Vector2) -> void:
	var x := 0.0
	var sprites: Array = parent.get_meta("cost_sprites", [])
	var index := 0
	for resource in amounts:
		var amount: Label = amounts[resource]
		amount.text = preload("res://scripts/display_numbers.gd").format(cost[resource])
		var width := maxf(24, amount.get_theme_font("font").get_string_size(amount.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 2)
		amount.position = pos + Vector2(x + 18, -1)
		amount.size.x = width
		if index < sprites.size(): sprites[index].position = pos + Vector2(x, 0)
		x += 18 + width + 6
		index += 1

func _build_resources() -> void:
	inventory_panel = panel(Vector2.ZERO, Vector2(160, 1))
	inventory_panel.name = "MaterialInventory"
	var index := 0
	for resource in game.Content.RESOURCES:
		var row := Control.new()
		row.name = resource.capitalize()
		row.position = Vector2(0, index * 66)
		row.size = Vector2(144, 66)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_panel.add_child(row)
		var sprite := icon(row, game.ui_textures[resource + "_item"], Vector2(0, 7), Vector2(32, 32))
		resources[resource] = label(row, preload("res://scripts/display_numbers.gd").format(game.inventory[resource]), Vector2(38, 0), Vector2(102, 29), 20)
		var cap := label(row, "", Vector2(38, 28), Vector2(102, 19), 11, MUTED)
		var deduction := label(row, "", Vector2(38, 43), Vector2(102, 18), 11, ERROR_COLOR)
		var track := ColorRect.new()
		track.position = Vector2(0, 61)
		track.size = Vector2(132, 3)
		track.color = Color(0.02, 0.01, 0.015, 0.65)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(track)
		var fill := ColorRect.new()
		fill.size = Vector2(0, 3)
		fill.color = resource_color(resource).darkened(0.25)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		resource_views[resource] = {"row": row, "icon": sprite, "capacity": cap, "deduction": deduction, "fill": fill, "position": row.position}
		displayed_amounts[resource] = float(game.inventory[resource])
		previous_amounts[resource] = game.inventory[resource]
		pending_gains[resource] = 0
		index += 1
func resource_color(resource: String) -> Color:
	return game.RESOURCE_COLORS.get(resource, Color("d4b69b"))

func _build_palette() -> void:
	palette = panel(Vector2(0, -72), Vector2(844, 72))
	palette.anchor_top = 1
	palette.anchor_bottom = 1
	palette.name = "BottomBar"
	palette.anchor_right = 1
	palette.offset_right = 0
	tech_button = button(palette, "", Vector2.ZERO, Vector2(82, 72), show_tech_tree)
	icon(tech_button, load("res://assets/ui/tech.svg"), Vector2(26, 21), Vector2(30, 30))
	set_info(tech_button, "Tech tree", "Unlock new structures and turret colors.", "T")
	var structures := button(palette, "", Vector2.ZERO, Vector2(100, 72), func(): toggle_category("Structures"))
	icon(structures, load("res://assets/ui/structures.svg"), Vector2(32, 18), Vector2(36, 36))
	set_info(structures, "Structures", "Choose a structure to build.", "")
	category_buttons["Structures"] = structures
	# Kept intact for a future switch to separate categories.
	for group in ["Logistics", "Extraction", "Defense", "Production", "Support", "Storage"]:
		var card := button(palette, "", Vector2.ZERO, Vector2(80, 72), func(): toggle_category(group))
		var kind: String = {"Logistics": "belt", "Extraction": "drill", "Defense": "solar", "Production": "forge", "Support": "healer", "Storage": "copper_store"}[group]
		icon(card, game.ui_textures[kind], Vector2(24, 20), Vector2(32, 32))
		set_info(card, group, "Choose a structure to build.", "")
		category_buttons[group] = card
		card.hide()
	for group in ["Infrastructure", "Defence"]:
		var card := button(palette, "", Vector2.ZERO, Vector2(80, 72), func(): toggle_category(group))
		icon(card, game.ui_textures["belt" if group == "Infrastructure" else "solar"], Vector2(24, 20), Vector2(32, 32))
		set_info(card, group, "Choose factory and transport buildings." if group == "Infrastructure" else "Choose turrets, barriers and defensive buildings.", "")
		category_buttons[group] = card
		card.hide()
	expanded = panel(Vector2(0, -200), Vector2(188, 128))
	expanded.anchor_top = 1
	expanded.anchor_bottom = 1
	expanded.hide()
func unlocked_in_category(group: String) -> Array[String]:
	var result: Array[String] = []
	for kind in game.BUILDINGS:
		var matches: bool = group == "Structures" or game.BUILDINGS[kind].category == group
		if group == "Infrastructure": matches = game.BUILDINGS[kind].category != "Defense"
		if group == "Defence": matches = game.BUILDINGS[kind].category == "Defense"
		if matches and game.unlocked(kind): result.append(kind)
	return result
func toggle_category(group: String) -> void:
	if not game.separate_build_categories and not game.researched.has("barriers"): group = "Structures"
	game.tutorial.on_menu_clicked(group)
	preview_kind = ""
	if category == group:
		category = ""
		hide_tray()
	elif unlocked_in_category(group).is_empty():
		category = ""
		hide_tray()
		show_tech_tree()
	else:
		category = group
		_rebuild_cards()
		animate_tray()
	refresh()
func hide_tray() -> void:
	if is_instance_valid(tray_tween) and tray_tween.is_valid(): tray_tween.kill()
	expanded.hide()
func animate_tray() -> void:
	if is_instance_valid(tray_tween) and tray_tween.is_valid(): tray_tween.kill()
	var target := expanded.position
	expanded.position.y += 12
	expanded.modulate.a = 0
	tray_tween = expanded.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tray_tween.tween_property(expanded, "position:y", target.y, 0.15)
	tray_tween.tween_property(expanded, "modulate:a", 1.0, 0.10)
func _rebuild_cards() -> void:
	if is_instance_valid(tray_tween) and tray_tween.is_valid(): tray_tween.kill()
	for child in expanded.get_children():
		expanded.remove_child(child)
		child.queue_free()
	cards.clear()
	card_views.clear()
	research_signature = build_menu_signature()
	expanded.visible = category != ""
	if category == "": return
	var kinds := unlocked_in_category(category)
	var columns := mini(3, maxi(1, kinds.size()))
	var rows := maxi(1, ceili(float(kinds.size()) / columns))
	var tray_width := float(columns * 188)
	var tray_height := float(rows * 80 + 24)
	var center: float = category_buttons[category].position.x + category_buttons[category].size.x / 2
	var left := clampf(center - tray_width / 2, 0, root.size.x - tray_width)
	expanded.offset_left = left
	expanded.offset_right = left + tray_width
	expanded.offset_top = -72 - tray_height
	expanded.offset_bottom = -72
	expanded.modulate.a = 1
	label(expanded, category.to_upper(), Vector2.ZERO, Vector2(expanded.size.x, 24), 11, ACCENT)
	var index := 0
	for kind in kinds:
		var data: Dictionary = game.BUILDINGS[kind]
		var card := button(expanded, "", Vector2((index % columns) * 188, 24 + (index / columns) * 80), Vector2(188, 80), func():
			game.select_building(kind)
		)
		icon(card, game.ui_textures.wall_iron if kind == "wall" and game.researched.has("iron_barriers") else game.ui_textures[kind], Vector2(8, 8), Vector2(32, 32))
		label(card, data.name, Vector2(46, 8), Vector2(134, 32), 13)
		var amounts := cost_row(card, game.building_cost(kind), Vector2(8, 48))
		if index < 9 and build_hotkeys_available(): set_hotkey_label(card, str(index + 1), true)
		var shade := ColorRect.new()
		shade.material = game.material
		shade.name = "UnaffordableShade"
		shade.color = Color(0, 0, 0, 0.58)
		shade.size = card.size
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.z_index = 1
		card.add_child(shade)
		card.mouse_entered.connect(func(): preview_kind = kind)
		card.mouse_exited.connect(func():
			if preview_kind == kind: preview_kind = ""
		)
		cards[kind] = card
		card_views[kind] = {"shade": shade, "amounts": amounts}
		index += 1
	_refresh_affordability()

func _build_map() -> void:
	map_panel = panel(Vector2(-220, 0), Vector2(220, 152))
	map_panel.anchor_left = 1
	map_panel.anchor_right = 1
	minimap = Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	minimap.game = game
	minimap.clip_contents = true
	minimap.position = Vector2.ZERO
	minimap.size = Vector2(220, 152)
	map_panel.add_child(minimap)
	var mute := button(map_panel, "", Vector2(188, 0), Vector2(32, 32), game.toggle_audio)
	set_info(mute, "Sound", "Mute or unmute game sound effects.", "M")
	mute_icon = icon(mute, load("res://assets/ui/sound.svg"), Vector2.ZERO, Vector2(28, 28))
	wave_label = label(root, "", Vector2(-220, 156), Vector2(220, 48), 34, INK)
	wave_label.anchor_left = 1
	wave_label.anchor_right = 1
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	wave_label.add_theme_constant_override("shadow_outline_size", 5)
	wave_label.add_theme_constant_override("shadow_offset_x", 0)
	wave_label.add_theme_constant_override("shadow_offset_y", 0)
	next_wave_label = label(root, "Next Wave: 1", Vector2(-220, 202), Vector2(220, 22), 13, INK)
	next_wave_label.anchor_left = 1
	next_wave_label.anchor_right = 1
	next_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_wave_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	next_wave_label.add_theme_constant_override("shadow_outline_size", 2)
func _build_wave_controls() -> void:
	wave_controls = panel(Vector2(-466, -72), Vector2(466, 72))
	wave_controls.anchor_left = 1
	wave_controls.anchor_right = 1
	wave_controls.anchor_top = 1
	wave_controls.anchor_bottom = 1
	demolish_button = button(wave_controls, "", Vector2.ZERO, Vector2(72, 72), func(): game.select_tool("abolish"))
	set_button_icon(demolish_button, "demolish")
	set_info(demolish_button, "Demolish", "Toggle demolition mode to remove buildings.", "X")
	back_button = button(wave_controls, "", Vector2(72, 0), Vector2(72, 72), func(): save_browser.confirm_restore(game.saves.current, true))
	set_button_icon(back_button, "undo")
	set_info(back_button, "Go back one save", "Restore the previous wave checkpoint and pause.", "")
	saves_button = button(wave_controls, "", Vector2(144, 0), Vector2(72, 72), func(): save_browser.show_browser())
	set_button_icon(saves_button, "saves")
	set_info(saves_button, "Browse saves", "Browse saved waves grouped by core.", "")
	next_button = button(wave_controls, "Start", Vector2(144, 0), Vector2(178, 72), game.request_next_wave)
	set_info(next_button, "Next wave", "Start the next enemy wave early.", "Q")
	next_button.add_theme_font_size_override("font_size", 24)
	speed_button = button(wave_controls, "", Vector2(322, 0), Vector2(72, 72), game.cycle_speed)
	pause_button = button(wave_controls, "", Vector2(394, 0), Vector2(72, 72), game.toggle_pause)
	set_info(speed_button, "Speed", "Switch between normal and triple simulation speed.", "E")
	set_info(pause_button, "Pause / Resume", "Freeze the battle while you build or demolish.", "Space")
func is_pointer_over_ui(pointer_override: Vector2 = Vector2.INF) -> bool:
	if is_instance_valid(modal) and modal.visible: return true
	if is_instance_valid(radial) and radial.visible: return true
	var pointer := root.get_global_mouse_position() if pointer_override == Vector2.INF else pointer_override
	for region in ui_regions:
		if is_instance_valid(region) and region.is_visible_in_tree() and region.get_global_rect().has_point(pointer): return true
	return false
func refresh() -> void:
	if resources.is_empty(): return
	game.saves.ensure_learning_loaded()
	_sync_tutorial_ui()
	if category != "" and research_signature != build_menu_signature(): _rebuild_cards()
	_refresh_resources()
	var active: bool = game.spawn_remaining > 0 or game.wave_warp_active or game.last_round_active()
	next_button.disabled = active or game.lost or game.active_spawners.is_empty()
	next_button.text = "In Progress..." if active else ("Start Early" if game.tutorial.waves_started else "Start")
	next_button.add_theme_font_size_override("font_size", 18 if active or game.tutorial.waves_started else 24)
	next_button.set_meta("tutorial_glow", game.tutorial.stage >= game.tutorial.Stage.READY and not game.tutorial.waves_started and not game.tutorial.ui_revealed.get("start_called", false))
	set_button_icon(speed_button, "speed3")
	speed_button.add_theme_stylebox_override("normal", style(Color("56311f") if game.speed == 3 else Color.TRANSPARENT))
	pause_button.add_theme_stylebox_override("normal", style(Color("56311f") if game.paused else Color.TRANSPARENT))
	set_button_icon(pause_button, "play" if game.paused else "pause")
	speed_button.set_meta("info", ["Speed: x%d" % game.speed, "Switch between normal and triple simulation speed.", "E"])
	back_button.disabled = game.saves.current < 0
	demolish_button.disabled = game.lost
	demolish_button.add_theme_stylebox_override("normal", style(Color("56311f") if game.active_tool == "abolish" else Color.TRANSPARENT))
	saves_button.visible = save_browser.available()
	save_browser.refresh_timeline()
	var remaining := ceili(maxf(0, game.wave_timer))
	wave_label.text = "00:00" if game.last_round_active() else "%02d:%02d" % [remaining / 60, remaining % 60]
	next_wave_label.text = "Next Wave: Last" if game.last_round_active() else "Next Wave: %s" % preload("res://scripts/display_numbers.gd").format(game.wave + 1)
	notice_label.text = game.notice if game.notice_time > 0 else ""
	tool_hint.text = game.tutorial.bottom_message()
	tool_hint.add_theme_font_size_override("font_size", 21)
	tool_hint.offset_top = expanded.offset_top - 28 if expanded.visible else -100
	tool_hint.offset_bottom = tool_hint.offset_top + 24
	for group in category_buttons:
		category_buttons[group].add_theme_stylebox_override("normal", style(Color(0.32, 0.16, 0.14, 0.9) if category == group else Color.TRANSPARENT))
		category_buttons[group].modulate = Color.WHITE if not unlocked_in_category(group).is_empty() else Color(0.55, 0.5, 0.5)
	for tool in tool_buttons:
		var selected_tool: bool = game.active_tool == tool or (tool == "blueprint_select" and game.active_tool == "blueprint_stamp")
		tool_buttons[tool].add_theme_stylebox_override("normal", style(Color(0.32, 0.16, 0.14, 0.9) if selected_tool else Color.TRANSPARENT))
	_refresh_affordability()
	if is_instance_valid(minimap): minimap.queue_redraw()
	if is_instance_valid(game.audio): mute_icon.texture = load("res://assets/ui/muted.svg" if game.audio.muted else "res://assets/ui/sound.svg")
	if is_instance_valid(game.audio): mute_icon.get_parent().add_theme_stylebox_override("normal", style(Color("56311f") if game.audio.muted else Color.TRANSPARENT))
	_refresh_tooltip()
	_refresh_research()
	_refresh_shortcuts()
	game.saves.remember_learning()
func _refresh_affordability() -> void:
	for kind in cards:
		var cost: Dictionary = game.building_cost(kind)
		var available: bool = game.affordable(cost)
		refresh_cost_row(kind, cost)
		layout_cost_amounts(cards[kind], card_views[kind].amounts, cost, cards[kind].get_meta("cost_position"))
		card_views[kind].shade.visible = not available
		for resource in card_views[kind].amounts:
			var amount_label: Label = card_views[kind].amounts[resource]
			amount_label.text = preload("res://scripts/display_numbers.gd").format(cost[resource])
			amount_label.add_theme_color_override("font_color", MUTED if available else ERROR_COLOR)
		cards[kind].add_theme_stylebox_override("normal", style(Color(0.32, 0.16, 0.14, 0.9) if game.selected == kind and game.active_tool == "build" else Color.TRANSPARENT))
func _refresh_resources() -> void:
	var quote: Dictionary = game.building_cost(preview_kind) if preview_kind != "" and game.BUILDINGS.has(preview_kind) else {}
	for resource in resources:
		var actual: int = game.inventory[resource]
		var previous: int = previous_amounts[resource]
		if actual != previous:
			previous_amounts[resource] = actual
			if actual > previous: pending_gains[resource] += actual - previous
			var old = amount_tweens.get(resource)
			if old is Tween and old.is_valid(): old.kill()
			var roll := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			roll.tween_method(_set_display_amount.bind(resource), float(displayed_amounts[resource]), float(actual), 0.18)
			amount_tweens[resource] = roll
		var capacity: int = game.material_capacity(resource)
		var view: Dictionary = resource_views[resource]
		view.capacity.text = "" if resource == "scrap" else "/ %s" % preload("res://scripts/display_numbers.gd").format(capacity)
		view.fill.get_parent().visible = resource != "scrap"
		view.fill.size.x = 132 * clampf(float(actual) / maxf(1, capacity), 0, 1)
		view.deduction.text = "-%s" % preload("res://scripts/display_numbers.gd").format(quote[resource]) if quote.has(resource) else ""
		view.deduction.add_theme_color_override("font_color", ERROR_COLOR if quote.get(resource, 0) > actual else ACCENT)
func _set_display_amount(value: float, resource: String) -> void:
	displayed_amounts[resource] = value
	resources[resource].text = preload("res://scripts/display_numbers.gd").format(roundi(value))
func _process(dt: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	tutorial_prompt.add_theme_color_override("font_shadow_color", Color(1, 0.7, 0.1, 0.35 + pulse * 0.3))
	_refresh_tooltip()
	game.tutorial.update_info_hover(dt, tooltip.visible, tooltip_identity)
	_refresh_shortcuts()
	tool_hint.text = game.tutorial.bottom_message()
	screen_edges.visible = game.paused or game.active_tool == "abolish"
	screen_edges.material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	screen_edges.material.set_shader_parameter("paused", game.paused)
	screen_edges.material.set_shader_parameter("demolishing", game.active_tool == "abolish")
	var outlines := PackedVector4Array()
	for region in [inventory_panel, map_panel, palette, expanded, tooltip]:
		if not is_instance_valid(region) or not region.is_visible_in_tree(): continue
		var rect: Rect2 = region.get_global_rect()
		outlines.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	screen_edges.material.set_shader_parameter("panel_count", outlines.size())
	outlines.resize(8)
	screen_edges.material.set_shader_parameter("panels", outlines)
	apply_button_glow(next_button)
	back_button.set_meta("tutorial_glow", game.lost)
	apply_button_glow(back_button)
	saves_button.set_meta("tutorial_glow", game.tutorial.rewind_hint_active())
	apply_button_glow(saves_button)
	apply_button_glow(tech_button)
	for target in category_buttons.values(): apply_button_glow(target)
	for target in cards.values(): apply_button_glow(target)
	for node in tech_buttons.values(): apply_button_glow(node.button)
	shortage_cooldown = maxf(0, shortage_cooldown - dt)
	gain_clock += dt
	if gain_clock >= 0.28:
		gain_clock = 0
		for resource in pending_gains:
			if pending_gains[resource] <= 0: continue
			var gained: int = pending_gains[resource]
			pending_gains[resource] = 0
			pulse_resource(resource)
			var position: Vector2 = resource_views[resource].position + Vector2(0, 47)
			floating_caption("+%s" % preload("res://scripts/display_numbers.gd").format(gained), root.get_global_transform() * position, resource_color(resource), 0.7, Vector2(0, -22), 12)
	for resource in resource_views:
		var view: Dictionary = resource_views[resource]
		var ratio: float = float(game.inventory[resource]) / maxf(1, game.material_capacity(resource))
		view.fill.color = resource_color(resource).lightened(0.15 + sin(Time.get_ticks_msec() * 0.004) * 0.10) if ratio >= 0.9 else resource_color(resource).darkened(0.25)
func pulse_resource(resource: String) -> void:
	var sprite: TextureRect = resource_views[resource].icon
	var old = sprite.get_meta("pulse_tween") if sprite.has_meta("pulse_tween") else null
	if old is Tween and old.is_valid(): old.kill()
	var pulse := sprite.create_tween().set_trans(Tween.TRANS_QUAD)
	pulse.tween_property(sprite, "scale", Vector2.ONE * 1.13, 0.06).set_ease(Tween.EASE_OUT)
	pulse.tween_property(sprite, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	sprite.set_meta("pulse_tween", pulse)
func floating_caption(text: String, origin: Vector2, color: Color, duration: float = 0.9, drift: Vector2 = Vector2(0, -40), font_size: int = 17) -> Label:
	origin = ui_point(origin)
	if color == ERROR_COLOR:
		duration = maxf(duration, 2.2)
		drift *= 0.6
	var caption := label(root, text, origin, Vector2(520, 30), font_size, color)
	caption.set_meta("duration", duration)
	caption.set_meta("drift", drift)
	caption.z_index = 100
	if is_instance_valid(modal) and modal.visible: caption.z_index = 300
	caption.add_theme_color_override("font_outline_color", Color("12080b"))
	caption.add_theme_constant_override("outline_size", 3)
	feedback_labels.append(caption)
	var motion := caption.create_tween().set_parallel(true)
	motion.tween_property(caption, "position", origin + drift, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(caption, "modulate:a", 0.0, duration * 0.65).set_delay(duration * 0.35)
	motion.chain().tween_callback(func():
		feedback_labels.erase(caption)
		caption.queue_free()
	)
	return caption
func announce_wave(number: int) -> void:
	if wave_announcement_tween != null and wave_announcement_tween.is_valid(): wave_announcement_tween.kill()
	wave_announcement.text = "Wave %s" % preload("res://scripts/display_numbers.gd").format(number)
	wave_announcement.modulate.a = 1.0
	wave_announcement_tween = wave_announcement.create_tween()
	wave_announcement_tween.tween_interval(1.8)
	wave_announcement_tween.tween_property(wave_announcement, "modulate:a", 0.0, 0.8)
func show_shortage(message: String, world_cell: Vector2i) -> void:
	if shortage_cooldown > 0 and last_shortage_message == message: return
	shortage_cooldown = 0.35
	last_shortage_message = message
	var origin := root.get_global_mouse_position() + Vector2(12, -12)
	if world_cell != game.INVALID: origin = game.get_canvas_transform() * game.cell_center(world_cell) + Vector2(12, -12)
	origin = ui_point(origin).clamp(Vector2(0, 45), root.size - Vector2(520, 132))
	if wave_announcement.text != "" and wave_announcement.modulate.a > 0.05: origin.y = minf(origin.y, root.size.y - 186)
	floating_caption(message, root.get_global_transform() * origin, ERROR_COLOR)
	game.play_sound("error")

func _refresh_tooltip(pointer_override: Vector2 = Vector2.INF) -> void:
	tooltip.visible = false
	if is_instance_valid(spawn_preview): spawn_preview.hide_preview()
	tooltip_body.visible = true
	tooltip_identity = ""
	hovered_enemy = {}
	hovered_core = game.INVALID
	if not Input.is_key_pressed(KEY_ALT): return
	var pointer := root.get_global_mouse_position() if pointer_override == Vector2.INF else pointer_override
	var modal_open := is_instance_valid(modal) and modal.visible
	for target in info_buttons:
		if not is_instance_valid(target) or not target.is_visible_in_tree() or not target.get_global_rect().has_point(pointer): continue
		if modal_open and not modal.is_ancestor_of(target): continue
		var info: Array = target.get_meta("info")
		show_info(info[0] + (" [" + info[2] + "]" if info[2] != "" else ""), info[1], pointer)
		tooltip_identity = "button:" + str(target.get_instance_id())
		return
	if modal_open: return
	for kind in cards:
		if cards[kind].is_visible_in_tree() and cards[kind].get_global_rect().has_point(pointer):
			show_structure_info(kind, {}, pointer)
			return
	if is_pointer_over_ui(pointer) or game.dragging or not game.is_cell_visible(game.hover_cell): return
	var world_point: Vector2 = game.get_canvas_transform().affine_inverse() * pointer
	for gate in game.spawners:
		if gate.converted or world_point.distance_to(gate.position) > game.TILE: continue
		var index: int = game.spawners.find(gate)
		var forecast: Dictionary = game.next_wave_forecast([] if gate.active else [index])
		var info: Dictionary = forecast.by_spawn.get(index, {"budget": 0, "counts": {}})
		show_info("Enemy spawn — Wave %s" % preload("res://scripts/display_numbers.gd").format(game.wave + 1), "", pointer)
		if not is_instance_valid(spawn_preview):
			spawn_preview = preload("res://scripts/spawn_preview.gd").new()
			spawn_preview.hud = self
			info_root.add_child(spawn_preview)
		spawn_preview.show_forecast(info.counts, pointer, game.wave + 1)
		tooltip_identity = "spawn:" + str(index)
		return
	for enemy in game.enemies:
		if enemy.hp <= 0 or not game.is_cell_visible(Vector2i((enemy.pos / game.TILE).floor())): continue
		if (game.get_canvas_transform().affine_inverse() * pointer).distance_to(game.enemy_visual_position(enemy)) <= game.Content.ENEMY_TYPES[enemy.kind].size * 0.6:
			hovered_enemy = enemy
			var info = preload("res://scripts/structure_info.gd")
			show_info(game.Content.ENEMY_TYPES[enemy.kind].name, info.enemy_stats(game, enemy), pointer, {"damaged": enemy.hp < enemy.max_hp})
			tooltip_identity = "enemy:" + str(enemy.info_id)
			return
	var building: Dictionary = game.building_at(game.hover_cell)
	if not building.is_empty():
		show_structure_info(building.kind, building, pointer)
	elif game.ores.has(game.hover_cell):
		show_info(game.ores[game.hover_cell].capitalize() + " deposit", "Hold the mouse button to gather this ore.\nManual extraction: 1 / %s" % "second", pointer)

func show_structure_info(kind: String, building: Dictionary, pointer: Vector2) -> void:
	if kind == "core" and not building.is_empty(): hovered_core = game.anchor_at(game.hover_cell)
	if not building.is_empty() and game.is_turret(kind) and not game.BUILDINGS[kind].get("ammo_free", false): game.tutorial.on_ammo_inspected()
	var info = preload("res://scripts/structure_info.gd")
	var title: String = "Core" if kind == "core" else game.BUILDINGS[kind].name
	var text: String = info.description(game, kind) + "\n\n" + info.stats(game, kind, building)
	var states := {"damaged": not building.is_empty() and building.hp < building.max_hp}
	if not building.is_empty():
		states.empty_ammo = game.is_turret(kind) and not game.BUILDINGS[kind].get("ammo_free", false) and building.ammo == 0
		if building.item != "":
			var target: Vector2i = game.output_target(game.anchor_at(game.hover_cell), building)
			states.blocked = target == game.INVALID or not game.can_receive(target, building.item, game.anchor_at(game.hover_cell))
			if states.blocked: text += "\nStatus: Output blocked"
		if game.active_tool == "abolish" and kind != "core":
			var refund: Dictionary = game.demolition_refund(game.hover_cell, true)
			text += "\n\nRefund: "
			if refund.is_empty(): text += "0"
			for resource in refund: text += "[img=14x14]res://assets/items/%s.svg[/img] %s  " % [resource, preload("res://scripts/display_numbers.gd").format(refund[resource])]
	show_info(title, text, pointer, states)
	tooltip_identity = "menu:" + kind if building.is_empty() else "building:" + str(game.anchor_at(game.hover_cell))
	if game.is_turret(kind):
		color_dots.colors = game.unlocked_colors(kind)
		color_dots.active = building.get("color", "")
		color_dots.position = Vector2(8, tooltip_body.get_rect().end.y + 6)
		color_dots.size = Vector2(100, 20)
		color_dots.visible = not color_dots.colors.is_empty()
		if color_dots.visible: tooltip.size.y += 26
		color_dots.queue_redraw()
		tooltip.position = (ui_point(pointer) + Vector2(18, -tooltip.size.y - 16)).clamp(Vector2(4, 4), root.size - tooltip.size - Vector2(4, 4))

func show_info(title: String, body: String, pointer: Vector2, states: Dictionary = {}) -> void:
	color_dots.hide()
	tooltip_identity = "info:" + title
	var now := Time.get_ticks_msec()
	if title != tooltip_title.text or now - last_info_msec > 150:
		if is_instance_valid(info_fade): info_fade.kill()
		tooltip.modulate.a = 0.0
		info_fade = create_tween()
		info_fade.tween_property(tooltip, "modulate:a", 1.0, 0.10)
	last_info_msec = now
	tooltip_title.text = title
	tooltip_body.text = decorated_stats(body, states)
	var height := maxf(18, tooltip_body.get_content_height())
	tooltip_body.size = Vector2(314, height)
	tooltip.size = Vector2(330, 40 + height + 8)
	tooltip.position = (ui_point(pointer) + Vector2(18, -tooltip.size.y - 16)).clamp(Vector2(4, 4), root.size - tooltip.size - Vector2(4, 4))
	tooltip.visible = true

func decorated_stats(body: String, states: Dictionary) -> String:
	var lines := body.split("\n")
	for i in lines.size():
		var stat := ""
		for pair in [["Health:", "health"], ["Damage:", "damage"], ["DPS:", "dps"], ["Range:", "range"], ["Radius:", "range"], ["Ammo:", "ammo"], ["Transport:", "speed"], ["Extraction:", "speed"], ["Speed:", "speed"], ["Status:", "blocked"]]:
			if lines[i].begins_with(pair[0]): stat = pair[1]
		if stat == "": continue
		var warning: bool = (stat == "health" and states.get("damaged", false)) or (stat == "ammo" and states.get("empty_ammo", false)) or (stat == "blocked" and states.get("blocked", false))
		if warning: lines[i] = "[color=#ff716c]" + lines[i] + "[/color]"
		lines[i] = "[img=14x14]res://assets/ui/stat_%s.svg[/img] " % stat + lines[i]
	return "\n".join(lines)

func floating_refund(refund: Dictionary, origin: Vector2) -> void:
	var row := Control.new()
	row.position = ui_point(origin) + Vector2(8, -16)
	row.size = Vector2(220, 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.z_index = 100
	root.add_child(row)
	var x := 0.0
	for resource in refund:
		icon(row, game.ui_textures[resource + "_item"], Vector2(x, 2), Vector2(18, 18))
		var text := "+%s" % preload("res://scripts/display_numbers.gd").format(refund[resource])
		var width := maxf(45, root.theme.default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2)
		label(row, text, Vector2(x + 21, 0), Vector2(width, 24), 15, ACCENT)
		x += 25 + width
	var motion := row.create_tween().set_parallel(true)
	motion.tween_property(row, "position:y", row.position.y - 32, 0.8)
	motion.tween_property(row, "modulate:a", 0.0, 0.5).set_delay(0.3)
	motion.chain().tween_callback(row.queue_free)
func modal_panel(dimensions: Vector2) -> Panel:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal_was_paused = game.paused
	game.paused = true
	modal = ColorRect.new()
	modal.material = game.material
	modal.z_index = 200
	modal.color = Color(0.035, 0.008, 0.012, 0.88)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var content := panel(-dimensions / 2, dimensions, modal)
	content.anchor_left = 0.5
	content.anchor_right = 0.5
	content.anchor_top = 0.5
	content.anchor_bottom = 0.5
	fit_dialog(content)
	return content
func close_modal() -> void:
	if not tech_buttons.is_empty(): game.tutorial.on_tree_closed()
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	game.paused = modal_was_paused
	tech_buttons.clear()
	tech_resource_labels.clear()
	_rebuild_cards()
func show_tech_tree() -> void:
	if (not game.tutorial.tech_available and not game.tutorial.storage_hint_active()) or is_instance_valid(modal): return
	game.tutorial.on_tech_opened()
	game.finish_drag()
	var content := modal_panel(Vector2(960, 664))
	label(content, "RESEARCH NETWORK", Vector2(24, 16), Vector2(600, 32), 23, ACCENT)
	var close_button := button(content, "Close", Vector2(798, 17), Vector2(138, 44), close_modal)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: close_button.add_theme_stylebox_override(state, style(Color.TRANSPARENT, BORDER, 3))
	set_info(close_button, "Close research", "Close the tech tree and restore the previous pause state.", "Esc")
	tech_scroll = ScrollContainer.new()
	tech_scroll.set_script(preload("res://scripts/tech_viewport.gd"))
	tech_scroll.position = Vector2(0, 70)
	tech_scroll.size = Vector2(960, 535)
	tech_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tech_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(tech_scroll)
	tech_graph = Control.new()
	tech_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tech_graph.draw.connect(func():
		for id in tech_buttons:
			var data: Dictionary = game.TECH[id]
			if data.parent == "" or not tech_buttons.has(data.parent): continue
			var start: Vector2 = game.TECH[data.parent].pos + Vector2(108, 128)
			var end: Vector2 = data.pos + Vector2(108, 0)
			tech_graph.draw_line(start, end, BORDER, 2.0)
	)
	_rebuild_tech_nodes()
	var focus_id := "barriers"
	for id in game.researched:
		if tech_buttons.has(id): focus_id = id
	tech_scroll.call_deferred("center_on_tech", game.TECH[focus_id].pos + Vector2(108, 64))
	tech_material_strip = Control.new()
	tech_material_strip.position = Vector2(24, 620)
	tech_material_strip.size = Vector2(912, 28)
	tech_material_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(tech_material_strip)
	tech_material_signature = -1
	apply_graphics_style(content)
	refresh()
func visible_tech_ids() -> Array[String]:
	var result: Array[String] = []
	for id in game.TECH:
		if id not in ["barriers", "iron_barriers", "slugger_shield", "time_speed", "turret_range", "copper_storage", "auto_scrap", "splitter", "weapons"]: continue
		var parent: String = game.TECH[id].parent
		if game.TECH[id].get("starter_color", false) and not game.researched.has(parent): continue
		if game.researched.has(id) or parent == "" or game.researched.has(parent): result.append(id)
	return result

func material_known(resource: String) -> bool:
	if game.inventory.get(resource, 0) > 0: game.discovered_resources[resource] = true
	return game.discovered_resources.has(resource)

func _refresh_shortcuts() -> void:
	var lines: Array[String] = game.tutorial.shortcut_lines()
	var alt_introduced: bool = game.tutorial.barrier_tree_closed
	shortcuts_label.text = "Hold alt for shortcuts" if alt_introduced and not Input.is_key_pressed(KEY_ALT) else "\n".join(lines)
	var height := 20.0 if alt_introduced and not Input.is_key_pressed(KEY_ALT) else float(lines.size() * 20)
	shortcuts_label.offset_left = -248
	shortcuts_label.offset_right = -8
	shortcuts_label.offset_top = -132 - height
	shortcuts_label.offset_bottom = -132
func _rebuild_tech_nodes() -> void:
	for child in tech_graph.get_children():
		tech_graph.remove_child(child)
		child.queue_free()
	tech_buttons.clear()
	var visible_ids := visible_tech_ids()
	var cursor: Array[float] = [20.0]
	for id in visible_ids:
		if game.TECH[id].parent == "" or not visible_ids.has(game.TECH[id].parent): layout_tech_branch(id, 0, visible_ids, cursor)
	var bottom := 120.0
	for id in visible_ids:
		var data: Dictionary = game.TECH[id]
		var node := button(tech_graph, "", data.pos, Vector2(216, 128), func():
			if game.research(id):
				_rebuild_tech_nodes()
				refresh()
			elif not game.researched.has(id) and not game.affordable(data.cost):
				floating_caption("Not enough resources...", root.get_global_mouse_position() + Vector2(12, -20), ERROR_COLOR)
				game.play_sound("error")
		)
		var sprite := icon(node, game.ui_textures[data.icon], Vector2(8, 8), Vector2(32, 32))
		node.set_meta("tech_card", true)
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			node.add_theme_stylebox_override(state_name, style(Color.TRANSPARENT, BORDER, 3))
		if data.has("color"): sprite.modulate = game.TEAM_COLORS[data.color]
		var title := label(node, data.name, Vector2(48, 6), Vector2(160, 36), 13)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.clip_text = false
		var effect := label(node, tech_stat_summary(id), Vector2(8, 44), Vector2(200, 28), 10, ACCENT)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.clip_text = false
		if not game.researched.has(id):
			var visible_cost: Dictionary = {}
			for resource in data.cost: visible_cost[resource] = data.cost[resource]
			cost_row(node, visible_cost, Vector2(8, 76))
		var state := label(node, "", Vector2(8, 104), Vector2(200, 20), 10, ACCENT)
		node.set_meta("tutorial_glow", id == "barriers" and not game.researched.has(id) and game.affordable(data.cost))
		tech_buttons[id] = {"button": node, "state": state, "effect": effect}
		bottom = maxf(bottom, data.pos.y + 144)
	var region := Rect2()
	for id in visible_ids:
		var rect := Rect2(game.TECH[id].pos, Vector2(216, 128))
		region = rect if region.size == Vector2.ZERO else region.merge(rect)
	region = region.grow(20)
	tech_graph.custom_minimum_size = region.end
	tech_scroll.configure(tech_graph, region)
	tech_graph.queue_redraw()
	_refresh_research()
func layout_tech_branch(id: String, depth: int, visible_ids: Array[String], cursor: Array[float]) -> float:
	var children: Array[String] = []
	for candidate in visible_ids:
		if game.TECH[candidate].parent == id: children.append(candidate)
	var center := 0.0
	if children.is_empty():
		center = cursor[0] + 108
		cursor[0] += 240
	else:
		for child in children: center += layout_tech_branch(child, depth + 1, visible_ids, cursor)
		center /= children.size()
	game.TECH[id].pos = Vector2(center - 108, 20 + depth * 164)
	return center
func _refresh_research() -> void:
	if is_instance_valid(tech_material_strip) and is_instance_valid(modal) and modal.is_ancestor_of(tech_material_strip):
		var known: Array[String] = []
		for resource in game.Content.RESOURCES:
			if material_known(resource): known.append(resource)
		if hash(known) != tech_material_signature:
			tech_material_signature = hash(known)
			for child in tech_material_strip.get_children():
				tech_material_strip.remove_child(child)
				child.queue_free()
			tech_resource_labels.clear()
			for i in known.size():
				var resource: String = known[i]
				icon(tech_material_strip, game.ui_textures[resource + "_item"], Vector2(i * 140, 0), Vector2(22, 22))
				tech_resource_labels[resource] = label(tech_material_strip, "", Vector2(30 + i * 140, 0), Vector2(94, 25), 14)
			_rebuild_tech_nodes()
			return
	for resource in tech_resource_labels:
		if is_instance_valid(tech_resource_labels[resource]): tech_resource_labels[resource].text = preload("res://scripts/display_numbers.gd").format(game.inventory[resource])
	for id in tech_buttons:
		var node: Dictionary = tech_buttons[id]
		if not is_instance_valid(node.button): continue
		var data: Dictionary = game.TECH[id]
		var done: bool = game.researched.has(id)
		node.button.set_meta("research_complete", done)
		node.button.set_meta("tutorial_glow", not done and game.affordable(data.cost) and (id == "barriers" or id == game.tutorial.storage_hint_tech() or (id == "weapons" and game.tutorial.slugger_rewind_hint_active())))
		var parent_ready: bool = data.parent == "" or game.researched.has(data.parent)
		node.button.disabled = done or not parent_ready
		var amounts: Dictionary = node.button.get_meta("cost_labels", {})
		for resource in amounts:
			amounts[resource].add_theme_color_override("font_color", Color.WHITE if game.inventory.get(resource, 0) >= data.cost[resource] else ERROR_COLOR)
		node.state.text = "RESEARCHED" if done else ("LOCKED" if not parent_ready else ("RESEARCH" if game.affordable(data.cost) else "INSUFFICIENT"))
		node.button.add_theme_stylebox_override("normal", style(Color("342025") if done else Color.TRANSPARENT, BORDER, 3))
		node.button.add_theme_stylebox_override("disabled", style(Color("342025") if done else Color.TRANSPARENT, BORDER, 3))
func show_affinity_picker(origin: Vector2) -> void:
	if is_instance_valid(radial): radial.queue_free()
	radial = Control.new()
	radial.set_script(load("res://scripts/affinity_picker.gd"))
	radial.material = game.material
	radial.available = game.unlocked_colors(game.radial_kind)
	radial.position = ui_point(origin)
	radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radial)
func dismiss_picker() -> void:
	if is_instance_valid(radial): radial.queue_free()
func show_outcome(victory: bool) -> void:
	var content := modal_panel(Vector2(560, 310))
	label(content, "FRONTIER SECURED" if victory else "SIGNAL LOST", Vector2(28, 23), Vector2(500, 30), 23, ACCENT)
	label(content, "%s waves | %s hostiles eliminated\n%s resources delivered" % [preload("res://scripts/display_numbers.gd").format(game.wave), preload("res://scripts/display_numbers.gd").format(game.kills), preload("res://scripts/display_numbers.gd").format(game.delivered)], Vector2(28, 83), Vector2(500, 70), 17)
	if victory:
		button(content, "Continue", Vector2(28, 232), Vector2(240, 44), func():
			close_modal()
			game.paused = false
		)
	button(content, "New expedition", Vector2(290 if victory else 28, 232), Vector2(240 if victory else 504, 44), func(): game.get_tree().reload_current_scene())

func build_menu_signature() -> int:
	return hash([game.researched, game.tutorial.stage, game.tutorial_enabled])
func refresh_cost_row(kind: String, cost: Dictionary) -> void:
	if card_views[kind].amounts.keys() == cost.keys(): return
	var target: Button = cards[kind]
	for old in card_views[kind].amounts.values():
		target.remove_child(old)
		old.queue_free()
	for old in target.get_meta("cost_sprites", []):
		target.remove_child(old)
		old.queue_free()
	card_views[kind].amounts = cost_row(target, cost, target.get_meta("cost_position"))
func _position_toolbar_button(target: Button, x: float) -> void:
	var rest := Vector2(x, 0)
	target.set_meta("rest_position", rest)
	target.position.x = x
func _sync_tutorial_ui() -> void:
	var progress = game.tutorial
	var sandbox: bool = not game.tutorial_enabled
	if progress.stage >= progress.Stage.SOLAR: progress.ui_revealed.solar_unlocked = true
	if game.researched.has("barriers") or progress.barrier_tree_closed: progress.ui_revealed.split = true
	if game.tutorial_enabled and game.researched.has("barriers"): progress.ui_revealed.barrier_building = true
	var central: String = "Use the arrow button or save menu to roll back time." if game.lost else progress.central_message()
	tutorial_prompt.visible = game.lost or (not sandbox and central != "")
	if is_instance_valid(game.capture_effect) and game.capture_effect.active: tutorial_prompt.visible = false
	tutorial_prompt.text = central
	var row_index := 0
	for resource in resource_views:
		if game.inventory[resource] > 0: game.discovered_resources[resource] = true
		var seen: bool = game.discovered_resources.has(resource)
		var view: Dictionary = resource_views[resource]
		view.row.visible = seen
		if seen:
			view.row.position = Vector2(8, 8 + row_index * 66)
			view.position = view.row.position
			row_index += 1
	inventory_panel.size.y = maxf(1, row_index * 66 + 16)
	inventory_panel.visible = row_index > 0
	palette.visible = sandbox or progress.stage >= progress.Stage.EXTRACTOR or progress.ui_revealed.get("palette", false)
	wave_controls.visible = progress.start_controls_available() or (progress.waves_started and progress.ui_revealed.get("waves", false))
	pause_button.visible = progress.pause_available() or progress.ui_revealed.get("pause", false)
	speed_button.visible = game.researched.has("time_speed")
	var start_x := 216 if save_browser.available() else 144
	next_button.position.x = start_x
	speed_button.position.x = start_x + 178
	var controls_width := start_x + 178 + (72 if speed_button.visible else 0) + (72 if pause_button.visible else 0)
	pause_button.position.x = start_x + 178 + (72 if speed_button.visible else 0)
	wave_controls.offset_left = -controls_width
	wave_controls.offset_right = 0
	map_panel.visible = wave_controls.visible
	wave_label.visible = wave_controls.visible
	next_wave_label.visible = wave_controls.visible
	notice_label.visible = wave_controls.visible
	tech_button.visible = progress.tech_available or progress.ui_revealed.get("tech", false) or progress.storage_hint_active()
	for entry in [["palette", palette], ["waves", wave_controls], ["pause", pause_button], ["tech", tech_button]]:
		if entry[1].visible: progress.ui_revealed[entry[0]] = true
	var highlighted: String = "barriers" if progress.tech_available and not game.researched.has("barriers") else progress.storage_hint_tech()
	tech_button.set_meta("tutorial_glow", (highlighted != "" and game.affordable(game.TECH[highlighted].cost)) or progress.slugger_rewind_hint_active())
	var x := 0.0
	var category_index := 0
	if tech_button.visible:
		_position_toolbar_button(tech_button, x)
		x += 82
	apply_button_glow(tech_button)
	for group in category_buttons:
		var target: Button = category_buttons[group]
		if game.separate_build_categories:
			target.visible = group not in ["Structures", "Infrastructure", "Defence"]
		elif game.researched.has("barriers") or progress.ui_revealed.get("split", false):
			target.visible = group in ["Infrastructure", "Defence"]
			if category == "Structures": category = "Infrastructure"
		else: target.visible = group == "Structures"
		target.set_meta("tutorial_glow", target.visible and (progress.menu_should_glow() or progress.category_should_glow(group)))
		if not target.visible or expanded.visible:
			var hint = target.get_node_or_null("Hotkey")
			if hint != null: hint.hide()
		if target.visible:
			category_index += 1
			set_info(target, group, "Choose a structure to build.", str(category_index) if not expanded.visible and category_index <= 9 and build_hotkeys_available() else "")
			_position_toolbar_button(target, x)
			x += target.size.x
	for tool in tool_buttons:
		tool_buttons[tool].visible = progress.waves_started
		if tool_buttons[tool].visible:
			_position_toolbar_button(tool_buttons[tool], x)
			x += 72
	for kind in cards: cards[kind].set_meta("tutorial_glow", progress.building_should_glow(kind))
	if not palette.visible: expanded.hide()
func apply_button_glow(target: Button) -> void:
	if not is_instance_valid(target): return
	var stroke := 2
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface = target.get_theme_stylebox(state)
		if surface is StyleBoxFlat and surface.border_width_left != stroke:
			var outlined: StyleBoxFlat = surface.duplicate()
			outlined.set_border_width_all(stroke)
			target.add_theme_stylebox_override(state, outlined)
	if not target.get_meta("tutorial_glow", false):
		if target.get_meta("glowing", false):
			for state in ["normal", "hover", "disabled"]:
				if target.get_meta("tech_card", false): target.add_theme_stylebox_override(state, style(Color("342025") if target.get_meta("research_complete", false) else Color.TRANSPARENT, BORDER, 3))
				else: target.remove_theme_stylebox_override(state)
			target.set_meta("glowing", false)
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var glow := style(Color(0.20, 0.12, 0.07, 1).lerp(Color(0.54, 0.29, 0.13, 1), pulse))
	glow.border_color = ACCENT.lerp(INK, pulse * 0.65)
	glow.set_border_width_all(2)
	glow.shadow_color = Color(ACCENT, 0.15 + pulse * 0.3)
	glow.shadow_size = 5 + roundi(pulse * 3)
	target.add_theme_stylebox_override("normal", glow)
	target.add_theme_stylebox_override("hover", glow)
	target.add_theme_stylebox_override("disabled", glow)
	target.set_meta("glowing", true)

var info_buttons: Array[Button] = []
func set_info(target: Button, title: String, description: String, shortcut: String) -> void:
	target.set_meta("info", [title, description, shortcut])
	if not info_buttons.has(target): info_buttons.append(target)
	set_hotkey_label(target, shortcut)
func set_hotkey_label(target: Button, shortcut: String, card: bool = false) -> void:
	var hint: Label = target.get_node_or_null("Hotkey")
	if hint == null:
		hint = label(target, "", Vector2.ZERO, Vector2.ZERO, 11, INK)
		hint.name = "Hotkey"
		hint.z_index = 3
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = shortcut
	hint.visible = shortcut != ""
	hint.position = Vector2(target.size.x - 28 if card else 0.0, target.size.y - 18)
	hint.size = Vector2(24 if card else target.size.x, 16)
func handle_number_hotkey(index: int) -> void:
	if not palette.visible or not build_hotkeys_available(): return
	if expanded.visible and category != "":
		if not build_hotkeys_available(): return
		var kinds := cards.keys()
		if index < kinds.size(): cards[kinds[index]].pressed.emit()
		return
	var groups: Array[String] = []
	for group in category_buttons:
		if category_buttons[group].visible: groups.append(group)
	if index < groups.size(): category_buttons[groups[index]].pressed.emit()
var button_icon_cache: Dictionary = {}
func set_button_icon(target: Button, id: String) -> void:
	if target.get_meta("icon_id", "") == id: return
	if not button_icon_cache.has(id): button_icon_cache[id] = preload("res://scripts/pixel_art.gd").texture(load("res://assets/ui/%s.svg" % id), Vector2i(32, 32))
	target.set_meta("icon_id", id)
	target.icon = button_icon_cache[id]
	target.expand_icon = true
	target.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_constant_override("icon_max_width", 28)


func tech_stat_summary(id: String) -> String:
	match id:
		"copper_storage": return "+50 copper capacity per silo"
		"auto_scrap": return "Collect scrap automatically after 2s"
		"build_hotkeys": return "Select menus and buildings: 1–9"
		"iron_barriers": return "Barrier health ×3"
		"slugger_shield": return "Blocks one hit; recharges after each wave"
		"time_speed": return "Press E for x3 speed"
		"conveyor_speed": return "Conveyors: 1 → 2 items / second"
		"turret_range":
			var base: float = game.BUILDINGS.solar.range / game.TILE
			var stats = preload("res://scripts/structure_info.gd")
			return "Solar range: %s → %s tiles" % [stats.number(base), stats.number(base + 2)]
		"armor": return "+25% building health"
		"mining": return "+30% extraction speed"
		"damage": return "+25% turret damage"
	return ""










var spawn_preview: Control
func build_hotkeys_available() -> bool:
	return game.tutorial.ui_revealed.get("split", false) or game.researched.has("barriers") or not game.tutorial_enabled






