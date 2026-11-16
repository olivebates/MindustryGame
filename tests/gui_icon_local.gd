extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(740, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("160f12")
	background.size = Vector2(740, 256)
	viewport.add_child(background)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://scripts/gui_icon.gdshader")
	var assets := ["demolish", "undo", "play", "pause", "speed3", "tech", "structures"]
	for i in assets.size():
		var texture = preload("res://scripts/pixel_art.gd").texture(load("res://assets/ui/%s.svg" % assets[i]), Vector2i(32, 32))
		for row in 2:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.material = shader_material
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size = Vector2.ONE * (64 if row == 0 else 32)
			icon.position = Vector2(24 + i * 100 + row * 0.37, 24 + row * 120 + row * 0.21)
			viewport.add_child(icon)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	var differences := 0
	for i in assets.size():
		for y in 16:
			for x in 16:
				if picture.get_pixel(24 + i * 100 + x * 4 + 2, 24 + y * 4 + 2) != picture.get_pixel(24 + i * 100 + x * 2 + 1, 144 + y * 2 + 1): differences += 1
	picture.save_png("res://.godot/gui-icon-preview.png")
	print("GUI LOCAL PIXELS: %d differences across positions and sizes" % differences)
	quit(1 if differences else 0)
