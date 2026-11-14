extends Node2D
## A presentation-only sequence; game pause and checkpoint data remain independent.
const BANNER_DURATION := 1.6
const PAN_DURATION := 1.4
const REVEAL_DELAY := BANNER_DURATION
const REVEAL_DURATION := 3.0
var game: Node2D
var active := false
var time := 0.0
var origin := Vector2.ZERO
var previous_origin := Vector2.ZERO
var reveal_sources: Array[Vector2] = []
var old_visibility: Dictionary = {}
var revealed_visibility: Dictionary = {}
var reveal_order: Array[Vector3] = []
var frontier_index := 0
var visibility_generation := 0
var reveal_radius := 0.0
var reveal_extent := 640.0
var banner: Label
var new_tech_label: Label
var pan_started := false
var pan_cancelled := false
var pan_from := Vector2.ZERO
var pan_points: Array[Vector2] = []
var zoom_from := 2.0
const GATE_HOLD := 0.4
func tour_duration() -> float:
	return maxi(1, pan_points.size() - 1) * PAN_DURATION + maxi(0, pan_points.size() - 2) * GATE_HOLD
func _ready() -> void:
	z_index = 202
	material = game.material
	banner = game.hud.label(game.hud.root, "Core successfully defended!", Vector2.ZERO, Vector2(1200, 74), 36, Color("83d780"))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -600
	banner.offset_right = 600
	banner.offset_top = 112
	banner.offset_bottom = 186
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.z_index = 80
	banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.65, 0.35, 0.5))
	banner.add_theme_constant_override("shadow_outline_size", 6)
	banner.hide()
	new_tech_label = game.hud.label(banner, "New tech unlocked", Vector2(0, 68), Vector2(1200, 32), 18, Color("b7e6b1"))
	new_tech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
func begin(cell: Vector2i) -> void:
	cancel()
	active = true
	time = 0
	origin = game.cell_center(cell)
	previous_origin = game.cell_center(game.current_core)
	reveal_sources.clear()
	var steps := maxi(1, ceili(previous_origin.distance_to(origin) / game.TILE))
	for index in steps + 1:
		reveal_sources.append(previous_origin.lerp(origin, float(index) / steps))
	old_visibility = game.visible_cells.duplicate()
	revealed_visibility = old_visibility.duplicate()
	reveal_order.clear()
	frontier_index = 0
	visibility_generation += 1
	reveal_radius = 0
	reveal_extent = game.TILE * 20
	pan_started = false
	pan_cancelled = false
	pan_points.clear()
	var reached: int = maxi(game.cores.size(), int(game.tutorial.ui_revealed.get("max_core_count", 1)))
	var next_count: int = game.cores.size() + (0 if game.cores.has(cell) else 1)
	new_tech_label.visible = false
	for id in game.TECH:
		var required: int = int(game.TECH[id].get("core", 1))
		if not game.researched.has(id) and required > reached and required <= next_count: new_tech_label.visible = true
	banner.modulate.a = 0
	banner.show()
	game.play_sound("core_capture")
	game.hud.tutorial_prompt.hide()
	queue_redraw()
func update_reveal_extent() -> void:
	if not active: return
	revealed_visibility.clear()
	reveal_order.clear()
	frontier_index = 0
	for cell in game.visible_cells:
		if old_visibility.has(cell):
			revealed_visibility[cell] = true
		else:
			var point: Vector2 = game.cell_center(cell)
			# The new core radiates immediately while the route also spreads
			# outward from the previous core toward it.
			var arrival: float = point.distance_to(origin) / (game.TILE * 20.0)
			for index in reveal_sources.size():
				var departure := float(index) / maxi(1, reveal_sources.size() - 1)
				arrival = minf(arrival, departure + point.distance_to(reveal_sources[index]) / (game.TILE * 20.0))
			reveal_order.append(Vector3(cell.x, cell.y, arrival))
	reveal_order.sort_custom(func(a: Vector3,b: Vector3): return a.z < b.z)
	# Normalize arrival times so the entire spreading corridor finishes in
	# the original reveal duration, including the radial spread at its end.
	if not reveal_order.is_empty():
		var last_arrival := maxf(0.001, reveal_order.back().z)
		for index in reveal_order.size(): reveal_order[index].z /= last_arrival
	visibility_generation += 1
	advance_visibility()
func advance_visibility() -> void:
	var progress := clampf((time - REVEAL_DELAY) / REVEAL_DURATION, 0, 1)
	while frontier_index < reveal_order.size() and reveal_order[frontier_index].z <= progress:
		var next := reveal_order[frontier_index]
		revealed_visibility[Vector2i(next.x,next.y)] = true
		frontier_index += 1
func cell_revealed(cell: Vector2i) -> bool:
	return not active or revealed_visibility.has(cell)
func cancel_pan() -> void:
	if active and time >= BANNER_DURATION: pan_cancelled = true
func camera_target() -> Vector2:
	return game.clamp_camera_position(origin)
func _process(dt: float) -> void: advance(dt)
func advance(dt: float) -> void:
	if not active: return
	time += dt
	var progress := clampf((time - REVEAL_DELAY) / REVEAL_DURATION, 0, 1)
	reveal_radius = reveal_extent * progress
	advance_visibility()
	var banner_end := BANNER_DURATION + PAN_DURATION
	banner.visible = time < banner_end
	banner.modulate.a = minf(clampf(time / 0.16, 0, 1), clampf((banner_end - time) / 0.35, 0, 1))
	if time >= BANNER_DURATION and not pan_cancelled:
		if not pan_started:
			pan_from = game.camera.position
			zoom_from = game.camera.zoom.x
			game.set_camera_zoom(1.0)
			game.camera.zoom = Vector2.ONE * zoom_from
			pan_points.append(pan_from)
			pan_points.append(camera_target())
			pan_started = true
		var elapsed := time - BANNER_DURATION
		game.camera.zoom = Vector2.ONE * lerpf(zoom_from, 1.0, smoothstep(0, 0.8, elapsed))
		var remaining := elapsed
		for segment in range(1, pan_points.size()):
			var blend := smoothstep(0, PAN_DURATION, remaining)
			game.camera.position = (pan_points[segment - 1].lerp(pan_points[segment], blend) * game.camera.zoom).round() / game.camera.zoom
			if remaining <= PAN_DURATION + GATE_HOLD or segment == pan_points.size() - 1: break
			remaining -= PAN_DURATION + GATE_HOLD
		game.camera.force_update_scroll()
	if progress >= 1 and time >= BANNER_DURATION + tour_duration():
		active = false
		old_visibility.clear()
		banner.hide()
		game.hud.refresh()
	if is_instance_valid(game.fog): game.fog.queue_redraw()
	if is_instance_valid(game.hud.minimap): game.hud.minimap.queue_redraw()
	queue_redraw()
func cancel() -> void:
	active = false
	old_visibility.clear()
	revealed_visibility.clear()
	reveal_order.clear()
	frontier_index = 0
	visibility_generation += 1
	if is_instance_valid(banner): banner.hide()
	if is_instance_valid(game.fog): game.fog.queue_redraw()
	queue_redraw()
func _draw() -> void:
	if not active: return
	var stroke := preload("res://scripts/drawing_style.gd").stroke(self)
	var pulse := clampf(time / 0.65, 0, 1)
	if pulse < 1:
		var radius := lerpf(20, game.TILE * 9, 1.0 - pow(1.0 - pulse, 2))
		for ring in 3:
			draw_arc(origin, radius + ring * stroke * 2, 0, TAU, 128, Color(1, 0.77, 0.36, (1 - pulse) * (0.6 / (ring + 1))), stroke)
		draw_circle(origin, 28 + pulse * 24, Color(1, 0.8, 0.45, (1 - pulse) * 0.18))
	var progress := clampf((time - REVEAL_DELAY) / REVEAL_DURATION, 0, 1)
	if progress > 0 and progress < 1:
		draw_arc(origin, maxf(1, reveal_radius), 0, TAU, 192, Color(0.45, 0.94, 0.85, sin(progress * PI) * 0.7), stroke)

