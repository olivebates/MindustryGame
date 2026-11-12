extends RefCounted

var game: Node2D
var first := Vector2i(-99999,-99999)
func _init(owner_game: Node2D) -> void: game = owner_game
func cancel() -> void:
	if game.buildings.has(first) and game.buildings[first].tunnel_pair == game.INVALID:
		game.remove_building(first,false)
	first = game.INVALID
func price() -> Dictionary:
	var nodes := 0
	for cell in game.buildings:
		if game.buildings[cell].kind == "teleporter" and game.buildings[cell].tunnel_pair != game.INVALID: nodes += 1
	var multiplier := pow(1.25,nodes / 2)
	return {"iron":roundi(5 * multiplier),"copper":roundi(30 * multiplier)}
func place(cell: Vector2i) -> bool:
	if not game.buildings.has(first):
		game._add_building(cell,"teleporter",0)
		first = cell
		game.buildings[cell].pending = true
		game.play_sound("build",game.cell_center(cell))
		return true
	var cost := price()
	if not game.affordable(cost):
		game.report_shortage(cost,cell)
		return false
	game.pay(cost)
	game._add_building(cell,"teleporter",0)
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
		if b.kind != "teleporter" or b.get("pending",false) or b.item == "" or b.progress == 1: continue
		var other: Dictionary = game.buildings.get(b.tunnel_pair,{})
		if other.is_empty() or other.get("pending",false): continue
		if other.item != "":
			if other.progress == 0:
				var item: String = b.item
				b.item = other.item
				other.item = item
				b.progress = 1.0
				other.progress = 1.0
				b.travel = 0.0
				other.travel = 0.0
				b.route_dir = -1
				other.route_dir = -1
			continue
		other.item = b.item
		other.progress = 1.0
		other.travel = 0.0
		other.route_dir = -1
		b.item = ""
		b.travel = 0.0
func draw_links() -> void:
	if game.buildings.has(first):
		game.draw_line(game.cell_center(first),game.get_global_mouse_position(),Color(1,1,1,0.35),game.line_width())
	var node: Dictionary = game.building_at(game.hover_cell)
	if node.is_empty() or node.kind != "teleporter" or not game.buildings.has(node.tunnel_pair): return
	game.draw_line(game.building_center(game.anchor_at(game.hover_cell)),game.building_center(node.tunnel_pair),Color(1,1,1,0.35),game.line_width())
