extends Button
## Pixelate the button surface while rendering its caption independently.
var caption: Label
var caption_colors: Dictionary = {}
func _ready() -> void:
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
		caption_colors[key] = get_theme_color(key)
		add_theme_color_override(key, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	caption = Label.new()
	caption.name = "FullResolutionCaption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	caption.horizontal_alignment = alignment
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	add_child(caption)
	sync_caption()
func _draw() -> void:
	if is_instance_valid(caption): sync_caption()
func sync_caption() -> void:
	if caption.text != text: caption.text = text
	caption.visible = text != ""
	var font := get_theme_font("font")
	if caption.get_theme_font("font") != font: caption.add_theme_font_override("font", font)
	var font_size := get_theme_font_size("font_size")
	if caption.get_theme_font_size("font_size") != font_size: caption.add_theme_font_size_override("font_size", font_size)
	var key := "font_disabled_color" if disabled else ("font_pressed_color" if is_pressed() else ("font_hover_color" if is_hovered() else "font_color"))
	var tint: Color = caption_colors.get(key, Color.WHITE)
	if caption.get_theme_color("font_color") != tint: caption.add_theme_color_override("font_color", tint)
