extends RefCounted
const HEIGHT := 32.0
const WIDTH := 64.0
var hud: CanvasLayer
var material_bar: Panel
var color_bar: Panel
var description: Label
var material_buttons: Dictionary = {}
var color_buttons: Dictionary = {}
var enabled := {"base":true, "pink":true, "verdite":true}
func _init(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
func build() -> void:
	material_bar = bar("MaterialFilters", -72 - HEIGHT)
	color_bar = bar("TurretColors", -72 - HEIGHT * 2)
	for group in enabled:
		var target := small_button(material_bar, func(): toggle_material(group))
		material_buttons[group] = target
		if group == "base":
			hud.icon(target, hud.game.ui_textures.copper_item, Vector2(10, 6), Vector2(20, 20))
			hud.icon(target, hud.game.ui_textures.iron_item, Vector2(34, 6), Vector2(20, 20))
		else: hud.icon(target, hud.game.ui_textures[group + "_item"], Vector2(22, 6), Vector2(20, 20))
	for color in hud.game.TEAM_COLORS:
		var target := small_button(color_bar, func(): select_color(color))
		color_buttons[color] = target
		var swatch := ColorRect.new()
		swatch.position = Vector2(12, 8)
		swatch.size = Vector2(40, 16)
		swatch.color = hud.game.TEAM_COLORS[color]
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(swatch)
	description = hud.label(color_bar, "", Vector2(196, 0), Vector2(600, HEIGHT), 16)
	description.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	description.offset_left = 196
	description.offset_right = -8
	description.offset_top = 0
	description.offset_bottom = HEIGHT
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
func bar(title: String, y: float) -> Panel:
	var panel: Panel = hud.panel(Vector2(0, y), Vector2(hud.root.size.x, HEIGHT))
	panel.name = title
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.anchor_right = 1
	panel.offset_right = 0
	panel.add_theme_stylebox_override("panel", appearance(false))
	return panel
func appearance(on: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("483329") if on else Color("0c080a")
	box.border_color = Color("bb8967")
	box.set_border_width_all(1)
	box.set_content_margin_all(0)
	return box
func small_button(parent: Panel, action: Callable) -> Button:
	var target := Button.new()
	target.size = Vector2(WIDTH, HEIGHT)
	target.toggle_mode = true
	target.add_theme_font_size_override("font_size", 1)
	target.focus_mode = Control.FOCUS_NONE
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for mode in ["normal","hover","pressed","disabled","focus"]: target.add_theme_stylebox_override(mode, appearance(mode == "pressed"))
	target.pressed.connect(action)
	parent.add_child(target)
	return target
func group_for(kind: String) -> String:
	var data: Dictionary = hud.game.BUILDINGS.get(kind, {})
	for item in ["verdite", "pink"]:
		if data.get("stores", "") == item or data.get("cost", {}).has(item): return item
	return "base"
func allows(kind: String) -> bool:
	return enabled[group_for(kind)]
func toggle_material(group: String) -> void:
	enabled[group] = not enabled[group]
	hud.preview_kind = ""
	hud._rebuild_cards()
	refresh()
func select_color(color: String) -> void:
	if not hud.game.researched.has("turret_color") or not hud.game.TEAM_COLORS.has(color): return
	hud.game.build_color = color
	hud._rebuild_cards()
	refresh()
func refresh() -> void:
	if not is_instance_valid(material_bar): return
	if not hud.game.researched.has("turret_color"): hud.game.build_color = "red"
	material_bar.visible = hud.palette.visible
	color_bar.visible = hud.palette.visible
	var x := 0.0
	for group in material_buttons:
		var target: Button = material_buttons[group]
		target.visible = (hud.material_known("copper") or hud.material_known("iron")) if group == "base" else hud.material_known(group)
		target.position.x = x
		target.set_pressed_no_signal(enabled[group])
		target.add_theme_stylebox_override("normal", appearance(enabled[group]))
		if target.visible: x += WIDTH
	x = 0
	for color in color_buttons:
		var target: Button = color_buttons[color]
		target.visible = hud.game.researched.has("turret_color") and hud.expanded.visible and hud.category == "Defence"
		target.position.x = x
		target.set_pressed_no_signal(color == hud.game.build_color)
		target.add_theme_stylebox_override("normal", appearance(color == hud.game.build_color))
		if target.visible: x += WIDTH
	description.offset_left = x + 4
	refresh_description()
func refresh_description() -> void:
	var kind: String = hud.preview_kind
	if kind == "" and not hud.is_pointer_over_ui(): kind = hud.game.building_at(hud.game.hover_cell).get("kind", "")
	description.text = preload("res://scripts/display_text.gd").format(preload("res://scripts/structure_info.gd").description(hud.game, kind)) if kind != "" else ""
