extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var motion = preload("res://scripts/conveyor_motion.gd")
	var failures := 0
	for direction in 4:
		for incoming in 4:
			for phase in 8:
				var time := float(phase) / 16.0
				var texture: Texture2D = motion.arrow_texture(direction, incoming, time, 64)
				if texture != motion.arrow_texture(direction, incoming, time + 0.01, 64): failures += 1
				var image := texture.get_image()
				for y in 16:
					for x in 16:
						var color := image.get_pixel(x * 4 + 2, y * 4 + 2)
						for dy in 4:
							for dx in 4:
								if image.get_pixel(x * 4 + dx, y * 4 + dy) != color: failures += 1
	print("CONVEYOR PIXEL GRID: %d failures across all directions and phases" % failures)
	quit(1 if failures else 0)
