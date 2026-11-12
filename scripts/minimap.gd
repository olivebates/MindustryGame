extends Control
var game: Node2D
var bounds := Rect2(Vector2.ZERO, Vector2.ONE)
var map_scale := 1.0
var map_offset := Vector2.ZERO
var dragging := false
var cached_key := Vector3i(-1,-1,-1)
var cached_fog_disabled := false
var cached_terrain_counts := Vector2i(-1,-1)
var terrain_texture: ImageTexture
var terrain_builds := 0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func update_bounds() -> void:
	var key: Vector3i = game.render_visibility_key()
	var counts := Vector2i(game.rocks.size(),game.ores.size())
	if key != cached_key or game.fog_disabled != cached_fog_disabled or counts != cached_terrain_counts:
		var revealed: Dictionary = game.visible_cells if game.fog_disabled else game.render_visible_cells()
		var low := Vector2i(2147483647,2147483647)
		var high := Vector2i(-2147483647,-2147483647)
		for cell in revealed:
			low.x = mini(low.x,cell.x)
			low.y = mini(low.y,cell.y)
			high.x = maxi(high.x,cell.x)
			high.y = maxi(high.y,cell.y)
		var region := Rect2i(low,high-low+Vector2i.ONE)
		if revealed.is_empty() or game.fog_disabled: region = Rect2i(0,0,game.WIDTH,game.HEIGHT)
		bounds = Rect2(region)
		var image := Image.create(region.size.x,region.size.y,false,Image.FORMAT_RGBA8)
		image.fill(Color("142d23"))
		for cell in revealed:
			if region.has_point(cell): image.set_pixelv(cell-region.position,terrain_color(cell))
		if game.fog_disabled:
			for cell in game.rocks:
				if region.has_point(cell): image.set_pixelv(cell-region.position,terrain_color(cell))
			for cell in game.ores:
				if region.has_point(cell): image.set_pixelv(cell-region.position,terrain_color(cell))
		terrain_texture = ImageTexture.create_from_image(image)
		cached_key = key
		cached_fog_disabled = game.fog_disabled
		cached_terrain_counts = counts
		terrain_builds += 1
	map_scale = minf(size.x / bounds.size.x, size.y / bounds.size.y)
	map_offset = (size - bounds.size * map_scale) / 2.0
func terrain_color(cell: Vector2i) -> Color:
	if game.ores.has(cell): return game.RESOURCE_COLORS[game.ores[cell]].darkened(0.4)
	return Color("287246") if game.rocks.has(cell) else Color("42332c")
func map_point(cell: Vector2) -> Vector2:
	return map_offset + (cell - bounds.position) * map_scale
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging: move_view(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			dragging = false
			return
		move_view(event.position)
		accept_event()
func move_view(position_on_map: Vector2) -> void:
	update_bounds()
	var cell: Vector2 = (position_on_map - map_offset) / map_scale + bounds.position
	if not bounds.has_point(cell): return
	game.camera.position = game.clamp_camera_position(cell * game.TILE)
	if is_instance_valid(game.capture_effect): game.capture_effect.cancel_pan()
	queue_redraw()
func _draw() -> void:
	if game == null: return
	update_bounds()
	draw_rect(Rect2(Vector2.ZERO, size), Color("142d23"))
	var tile := Vector2.ONE * map_scale
	draw_texture_rect(terrain_texture,Rect2(map_offset,bounds.size * map_scale),false)
	var revealed: Dictionary = game.render_visible_cells()
	for cell in game.buildings:
		if not game.fog_disabled and not revealed.has(cell): continue
		var b: Dictionary = game.buildings[cell]
		var color: Color = game.TEAM_COLORS[b.color] if game.is_turret(b.kind) else Color("c5a48b")
		if b.kind == "core": color = game.TEAL if cell == game.current_core else game.RED
		if b.get("pending", false): color.a = 0.33
		draw_rect(Rect2(map_point(Vector2(cell)), tile * game.footprint_size(b.kind)), color)
		if game.core_should_glow(cell):
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			draw_circle(map_point(Vector2(cell) + Vector2.ONE / 2), 4 + pulse * 3, Color(1, 0.85, 0.35, 0.25 + pulse * 0.4))
	for enemy in game.enemies:
		if game.fog_disabled or revealed.has(Vector2i((enemy.pos / game.TILE).floor())): draw_circle(map_point(enemy.pos / game.TILE), 2, game.TEAM_COLORS[enemy.color])
	for spawner in game.active_spawners:
		if game.fog_disabled or revealed.has(Vector2i((spawner.position / game.TILE).floor())): draw_circle(map_point(spawner.position / game.TILE), 3, Color("edb183"))
	var center: Vector2 = map_point(game.camera.position / game.TILE)
	if is_instance_valid(game.capture_effect) and game.capture_effect.active:
		var phase := fposmod(game.capture_effect.time, 0.9) / 0.9
		draw_arc(map_point(game.capture_effect.origin / game.TILE), 5 + phase * 14, 0, TAU, 40, Color(1, 0.8, 0.4, 1 - phase), 2)
	var visible_size: Vector2 = get_viewport_rect().size / game.camera.zoom / game.TILE * map_scale
	draw_rect(Rect2(center - visible_size / 2, visible_size), Color(0.93, 0.70, 0.51, 0.5), false, line_width())

func line_width() -> float:
	return 2.0


