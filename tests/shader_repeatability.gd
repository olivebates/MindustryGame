extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var drawing := Node2D.new()
	drawing.material = ShaderMaterial.new()
	drawing.material.shader = load("res://scripts/crisp_sprite.gdshader")
	viewport.add_child(drawing)
	var textures: Array[Texture2D] = [null]
	drawing.draw.connect(func():
		for i in 5:
			drawing.draw_set_transform(Vector2(48 + i * 80, 48 + i * 80))
			drawing.draw_texture_rect(textures[0], Rect2(-16, -16, 32, 32), false)
	)
	var failures := 0
	for asset in ["res://assets/buildings/drill.svg", "res://assets/terrain/copper.svg"]:
		textures[0] = preload("res://scripts/pixel_art.gd").texture(load(asset), Vector2i(64, 64))
		for zoom in [0.5, 1.0, 1.25, 2.0]:
			viewport.canvas_transform = Transform2D(0, Vector2.ONE * zoom, 0, Vector2(0.3, 0.7))
			drawing.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := viewport.get_texture().get_image()
			var span := roundi(32 * zoom)
			var first := Vector2i(Vector2(32, 32) * zoom + Vector2(0.3, 0.7))
			for i in range(1, 3):
				var offset := Vector2i.ONE * roundi(i * 80 * zoom)
				for y in span:
					for x in span:
						if picture.get_pixelv(first + Vector2i(x, y)) != picture.get_pixelv(first + offset + Vector2i(x, y)):
							failures += 1
	print("SHADER REPEATABILITY: %d differing pixels" % failures)
	quit(1 if failures else 0)
