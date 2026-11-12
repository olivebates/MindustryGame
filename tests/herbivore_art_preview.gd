extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1640, 500)
	root.content_scale_size = Vector2i(1640, 500)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("182c33")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var font = load("res://PixelifySans.ttf")
	var content = preload("res://scripts/content.gd")
	var art = preload("res://scripts/pixel_art.gd")
	var markings = preload("res://scripts/enemy_art.gd")
	var colors := [Color("f16e64"), Color("83d780"), Color("7aa7f0")]
	for index in content.ENEMY_TYPES.size():
		var kind: String = content.ENEMY_TYPES.keys()[index]
		var x: int = 12 + index * 180
		var title := Label.new()
		title.text = content.ENEMY_TYPES[kind].name
		title.position = Vector2(x, 20)
		title.size = Vector2(172, 30)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 20)
		layer.add_child(title)
		for row in 4:
			var raster: int = [64, 64, 32, 16][row]
			var display: int = [144, 64, 32, 16][row]
			var sprite := TextureRect.new()
			var tint: Color = colors[index % 3] if row == 0 else colors[row - 1]
			var parts: Array[Texture2D] = []
			for suffix in ["_body", "_gun"]:
				var base: Texture2D = art.texture(load("res://assets/units/%s%s.svg" % [kind,suffix]),Vector2i.ONE * raster)
				var marking: Texture2D = art.texture(load("res://assets/units/%s%s_accent.svg" % [kind,suffix]),Vector2i.ONE * raster)
				parts.append(markings.composite(base,marking,tint))
			sprite.texture = markings.assemble(parts[0],parts[1])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.size = Vector2.ONE * display
			sprite.position = Vector2(x + (172 - display) / 2.0, [68, 250, 350, 420][row])
			layer.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/herbivore_art_preview.png")
	print("HERBIVORE ART PREVIEW FINISHED")
	quit()
