extends RefCounted
static func finish(t: Node2D) -> void:
	if t.pink_lesson_kind == "": return
	t.ui_revealed[t.pink_lesson_kind + "_done"] = true
	t.pink_lesson_kind = ""
	t.pink_guide_path.clear()
	t.game.saves.remember_learning()
static func on_placed(t: Node2D, kind: String, cell: Vector2i) -> void:
	if kind != "refinery" or not t.game.tutorial_enabled or t.skipped: return
	if t.ui_revealed.get(kind + "_seen", false): return
	t.ui_revealed[kind + "_seen"] = true
	t.pink_lesson_kind = kind
	t.pink_lesson_source = cell if kind == "refinery" else t.game.INVALID
	t.pink_lesson_target = cell if kind == "iron_store" else t.game.INVALID
	t.pink_guide_signature = -1
	update(t)
	t.game.saves.remember_learning()
static func connected(game: Node2D, source: Vector2i, target: Vector2i) -> bool:
	var queue: Array[Vector2i] = []
	for cell in preload("res://scripts/pink_production.gd").ports(game, source):
		var building: Dictionary = game.building_at(cell)
		if not building.is_empty() and building.kind == "belt": queue.append(cell)
	var seen := {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		var anchor: Vector2i = game.anchor_at(cell)
		if anchor == target: return true
		if anchor == game.INVALID or seen.has(anchor): continue
		seen[anchor] = true
		var building: Dictionary = game.buildings[anchor]
		if building.kind == "belt": queue.append(game.output_target(anchor, building))
		elif building.kind == "splitter":
			for direction in game.splitter_outputs(anchor): queue.append(anchor + game.DIRS[direction])
	return false
static func update(t: Node2D) -> void:
	if t.pink_lesson_kind == "iron_store":
		finish(t)
		return
	if t.pink_lesson_kind == "": return
	if t.ui_revealed.get(t.pink_lesson_kind + "_done", false):
		t.pink_lesson_kind = ""
		t.pink_guide_path.clear()
		return
	var game: Node2D = t.game
	var fixed: Vector2i = t.pink_lesson_source if t.pink_lesson_kind == "refinery" else t.pink_lesson_target
	if not game.buildings.has(fixed):
		t.pink_guide_path.clear()
		return
	var nearest := INF
	var other: Vector2i = game.INVALID
	for cell in game.buildings:
		var kind: String = game.buildings[cell].kind
		if not (game.is_turret(kind) if t.pink_lesson_kind == "refinery" else kind == "refinery"): continue
		var distance: float = cell.distance_squared_to(fixed)
		if distance < nearest:
			nearest = distance
			other = cell
	if other == game.INVALID:
		t.pink_guide_path.clear()
		return
	if t.pink_lesson_kind == "refinery": t.pink_lesson_target = other
	else: t.pink_lesson_source = other
	if connected(game, t.pink_lesson_source, t.pink_lesson_target):
		finish(t)
		return
	t.pink_guide_path.clear()
