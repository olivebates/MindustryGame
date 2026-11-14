extends RefCounted

var game: Node2D
var first := Vector2i(-99999,-99999)
var redirecting := Vector2i(-99999,-99999)
var cycle_on_release := false
func is_output(cell: Vector2i) -> bool:
	var node: Dictionary = game.buildings.get(cell, {})
	if node.get("kind", "") != "teleporter": return false
	if node.tunnel_role != "": return node.tunnel_role == "exit"
	# Older checkpoints stored pairs in placement order without roles.
	return game.buildings.has(node.tunnel_pair) and game.buildings.keys().find(cell) > game.buildings.keys().find(node.tunnel_pair)
func redirect(cell: Vector2i) -> void:
	if cell == redirecting or not is_output(redirecting): return
	cycle_on_release = false
	game.buildings[redirecting].dir = game.direction_for(cell - redirecting)
	game.buildings[redirecting].route_dir = game.buildings[redirecting].dir
	game.refresh_belt_inputs()
func cycle_output(cell: Vector2i) -> void:
	if not is_output(cell): return
	var current: int = game.buildings[cell].dir
	var outputs: Array[int] = game.splitter_outputs(cell)
	outputs = outputs.filter(func(direction): return not is_output(game.anchor_at(cell + game.DIRS[direction])))
	if outputs.size() <= 1:
		game.buildings[cell].dir = (current + 1) % 4
		game.buildings[cell].route_dir = game.buildings[cell].dir
		game.refresh_belt_inputs()
		return
	for offset in range(1, 5):
		var direction := (current + offset) % 4
		if not outputs.has(direction): continue
		var neighbor: Vector2i = game.anchor_at(cell + game.DIRS[direction])
		if is_output(neighbor): continue
		game.buildings[cell].dir = direction
		game.buildings[cell].route_dir = direction
		game.refresh_belt_inputs()
		return
func _init(owner_game: Node2D) -> void: game = owner_game
func cancel() -> void:
	if game.buildings.has(first) and game.buildings[first].tunnel_pair == game.INVALID:
		game.remove_building(first,false)
	first = game.INVALID
	redirecting = game.INVALID
	cycle_on_release = false
func price() -> Dictionary:
	var nodes := 0
	for cell in game.buildings:
		if game.buildings[cell].kind == "teleporter" and game.buildings[cell].tunnel_pair != game.INVALID: nodes += 1
	var multiplier := pow(1.25,nodes / 2)
	return {"iron":roundi(5 * multiplier),"copper":roundi(30 * multiplier)}
func default_direction(cell: Vector2i) -> int:
	var best := 0
	var best_priority := -1
	var nearest := INF
	for direction in game.splitter_outputs(cell):
		var neighbor: Vector2i = cell + game.DIRS[direction]
		var receiver: Dictionary = game.building_at(neighbor)
		if receiver.kind == "teleporter" and is_output(game.anchor_at(neighbor)): continue
		var priority := 0 if receiver.kind == "belt" else 1
		var distance: float = game.cell_center(cell).distance_squared_to(game.building_center(game.anchor_at(neighbor)))
		if priority > best_priority or (priority == best_priority and distance < nearest):
			best = direction
			best_priority = priority
			nearest = distance
	return best
func place(cell: Vector2i) -> bool:
	if not game.buildings.has(first):
		game._add_building(cell,"teleporter",0)
		first = cell
		game.buildings[cell].tunnel_role = "entry"
		game.buildings[cell].pending = true
		game.play_sound("build",game.cell_center(cell))
		return true
	var cost := price()
	if not game.affordable(cost):
		game.report_shortage(cost,cell)
		return false
	game.pay(cost)
	game._add_building(cell,"teleporter",0)
	game.buildings[cell].tunnel_role = "exit"
	game.buildings[cell].dir = default_direction(cell)
	redirecting = cell
	game.buildings[first].tunnel_pair = cell
	game.buildings[cell].tunnel_pair = first
	game.buildings[first].paid_cost = cost
	game.buildings[first].pending = game.buildings[cell].pending
	game.tutorial.on_building_placed("teleporter",first)
	game.tutorial.on_building_placed("teleporter",cell)
	game.enemy_navigation.invalidate(game)
	first = game.INVALID
	game.refresh_belt_inputs()
	game.play_sound("build",game.cell_center(cell))
	return true
func transfer() -> void:
	for cell in game.buildings:
		var b: Dictionary = game.buildings[cell]
		if b.kind != "teleporter" or is_output(cell) or b.get("pending",false) or b.item == "": continue
		var other: Dictionary = game.buildings.get(b.tunnel_pair,{})
		if other.is_empty() or other.get("pending",false): continue
		if other.item != "": continue
		other.item = b.item
		other.progress = 1.0
		other.travel = 0.0
		other.route_dir = -1
		b.item = ""
		b.travel = 0.0
func draw_links() -> void:
	if game.buildings.has(first):
		draw_connection(game.cell_center(first), game.get_global_mouse_position())
	var node: Dictionary = game.building_at(game.hover_cell)
	if node.is_empty() or node.kind != "teleporter" or not game.buildings.has(node.tunnel_pair): return
	var cell: Vector2i = game.anchor_at(game.hover_cell)
	var input: Vector2i = node.tunnel_pair if is_output(cell) else cell
	var output: Vector2i = cell if is_output(cell) else node.tunnel_pair
	draw_connection(game.building_center(input), game.building_center(output))

func draw_connection(start: Vector2, end: Vector2) -> void:
	game.draw_line(start, end, Color(1,1,1,0.35), game.line_width())
	var direction := (end - start).normalized()
	var scale: float = maxf(0.001, game.get_screen_transform().x.length())
	var arrow_size := maxf(6.0, 8.0 / scale)
	for index in maxi(1, floori(start.distance_to(end) / 48)):
		var distance := (index + 0.5) * 48
		if distance < start.distance_to(end): draw_arrow(start + direction * distance, direction, Color(1,1,1,0.8), arrow_size)

func draw_arrow(center: Vector2, direction: Vector2, color: Color, size: float) -> void:
	var side := direction.orthogonal()
	var points := PackedVector2Array([center + direction * size, center - direction * size * 0.6 + side * size * 0.65, center - direction * size * 0.6 - side * size * 0.65])
	var outer := size + 1.0
	var outline := PackedVector2Array([center + direction * outer, center - direction * outer * 0.6 + side * outer * 0.65, center - direction * outer * 0.6 - side * outer * 0.65])
	game.draw_colored_polygon(outline, Color.BLACK)
	game.draw_colored_polygon(points, color)
