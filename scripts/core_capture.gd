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
var old_visibility: Dictionary = {}
var reveal_radius := 0.0
var reveal_extent := 640.0
var banner: Label
var pan_started := false
var pan_cancelled := false
var pan_from := Vector2.ZERO
func _ready() -> void:
	z_index = 202
	material = game.material
	banner = game.hud.label(game.hud.root, "Core secured", Vector2.ZERO, Vector2(700, 80), 36, Color("fff0cc"))
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -350
	banner.offset_right = 350
	banner.offset_top = -60
	banner.offset_bottom = 20
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.z_index = 80
	banner.add_theme_color_override("font_shadow_color", Color(0.92, 0.48, 0.15, 0.65))
	banner.add_theme_constant_override("shadow_outline_size", 6)
	banner.hide()
func begin(cell: Vector2i) -> void:
	cancel()
	active = true
	time = 0
	origin = game.cell_center(cell)
	old_visibility = game.visible_cells.duplicate()
	reveal_radius = 0
	reveal_extent = game.TILE * 20
	pan_started = false
	pan_cancelled = false
	banner.modulate.a = 0
	banner.show()
	game.play_sound("core_capture")
	game.hud.tutorial_prompt.hide()
	queue_redraw()
func update_reveal_extent() -> void:
	if not active: return
	for cell in game.visible_cells:
		if not old_visibility.has(cell): reveal_extent = maxf(reveal_extent, origin.distance_to(game.cell_center(cell)) + game.TILE)
func cell_revealed(cell: Vector2i) -> bool:
	return not active or old_visibility.has(cell) or origin.distance_squared_to(game.cell_center(cell)) <= reveal_radius * reveal_radius
func cancel_pan() -> void:
	if active and time >= BANNER_DURATION: pan_cancelled = true
func camera_target() -> Vector2:
	return origin.clamp(Vector2(180, 100), Vector2(game.WIDTH * game.TILE - 180, game.HEIGHT * game.TILE - 100))
func _process(dt: float) -> void: advance(dt)
func advance(dt: float) -> void:
	if not active: return
	time += dt
	var progress := clampf((time - REVEAL_DELAY) / REVEAL_DURATION, 0, 1)
	reveal_radius = reveal_extent * progress
	banner.visible = time < BANNER_DURATION
	banner.modulate.a = minf(clampf(time / 0.16, 0, 1), clampf((BANNER_DURATION - time) / 0.35, 0, 1))
	if time >= BANNER_DURATION and not pan_cancelled:
		if not pan_started:
			pan_from = game.camera.position
			pan_started = true
		var blend := clampf((time - BANNER_DURATION) / PAN_DURATION, 0, 1)
		blend = blend * blend * (3.0 - 2.0 * blend)
		game.camera.position = (pan_from.lerp(camera_target(), blend) * game.camera.zoom).round() / game.camera.zoom
		game.camera.force_update_scroll()
	if progress >= 1 and time >= BANNER_DURATION + PAN_DURATION:
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

