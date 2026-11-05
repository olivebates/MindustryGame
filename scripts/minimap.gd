extends Control
var game: Node2D
var bounds := Rect2(Vector2.ZERO, Vector2.ONE)
var map_scale := 1.0
var map_offset := Vector2.ZERO
var dragging := false
func update_bounds() -> void:
	var region := Rect2i()
	var first := true
	for cell in game.visible_cells:
		if first:
			region = Rect2i(cell, Vector2i.ONE)
			first = false
		else: region = region.merge(Rect2i(cell, Vector2i.ONE))
	if first or game.fog_disabled: region = Rect2i(0, 0, game.WIDTH, game.HEIGHT)
	bounds = Rect2(region)
	map_scale = minf(size.x / bounds.size.x, size.y / bounds.size.y)
	map_offset = (size - bounds.size * map_scale) / 2.0
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
	game.camera.position = cell * game.TILE
	queue_redraw()
func _draw() -> void:
	if game == null: return
	update_bounds()
	draw_rect(Rect2(Vector2.ZERO, size), Color("09070a"))
	var tile := Vector2.ONE * map_scale
	for cell in game.visible_cells: draw_rect(Rect2(map_point(Vector2(cell)), tile), Color("261c21"))
	for cell in game.rocks:
		if game.is_cell_visible(cell): draw_rect(Rect2(map_point(Vector2(cell)), tile), Color("3d3234"))
	for cell in game.ores:
		if game.is_cell_visible(cell): draw_rect(Rect2(map_point(Vector2(cell)), tile), game.RESOURCE_COLORS[game.ores[cell]].darkened(0.4))
	for cell in game.buildings:
		if not game.is_cell_visible(cell): continue
		var b: Dictionary = game.buildings[cell]
		var color: Color = game.TEAM_COLORS[b.color] if game.is_turret(b.kind) else Color("c5a48b")
		if b.kind == "core": color = game.TEAL if cell == game.current_core else game.RED
		draw_rect(Rect2(map_point(Vector2(cell)), tile * game.footprint_size(b.kind)), color)
	for enemy in game.enemies:
		if game.is_cell_visible(Vector2i((enemy.pos / game.TILE).floor())): draw_circle(map_point(enemy.pos / game.TILE), 2, game.TEAM_COLORS[enemy.color])
	for spawner in game.active_spawners:
		if game.is_cell_visible(Vector2i((spawner.position / game.TILE).floor())): draw_circle(map_point(spawner.position / game.TILE), 3, Color("edb183"))
	var center: Vector2 = map_point(game.camera.position / game.TILE)
	var visible_size: Vector2 = get_viewport_rect().size / game.camera.zoom / game.TILE * map_scale
	draw_rect(Rect2(center - visible_size / 2, visible_size), Color(0.93, 0.70, 0.51, 0.5), false, 1)
