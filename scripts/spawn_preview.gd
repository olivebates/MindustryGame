extends Control
var hud: CanvasLayer
var summary: Control
var signature := 0
var future_signature := 0
var future_rows: Array[Dictionary] = []
var future_height := 0.0
const CARD_SIZE := Vector2(240, 204)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary = Control.new()
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.tooltip.add_child(summary)
func hide_preview() -> void:
	hide()
	if is_instance_valid(summary): summary.hide()
func show_forecast(counts: Dictionary, pointer: Vector2, wave: int, colored: Dictionary = {}, gate_index: int = -1) -> void:
	if gate_index >= 0:
		var next_signature: int = preload("res://scripts/spawn_lookahead.gd").signature(hud.game, gate_index)
		if next_signature != future_signature:
			future_signature = next_signature
			future_rows = preload("res://scripts/spawn_lookahead.gd").build(hud.game, gate_index)
	else: future_rows.clear()
	var variants: Array[Dictionary] = preload("res://scripts/spawn_lookahead.gd").variants(colored)
	if gate_index >= 0 and not hud.game.spawners[gate_index].active and not future_rows.is_empty():
		variants.assign(future_rows[0].variants)
		wave = future_rows[0].number
	if variants.is_empty():
		for kind in counts: variants.append({"kind": kind, "count": counts[kind], "color": "red"})
	var key := hash([counts, wave, variants, future_rows])
	var kinds: Array = []
	for variant in variants: kinds.append(variant.kind)
	if key != signature:
		signature = key
		for child in get_children():
			remove_child(child)
			child.queue_free()
		for child in summary.get_children():
			summary.remove_child(child)
			child.queue_free()
		for i in kinds.size():
			var kind: String = kinds[i]
			var tint: Color = hud.game.TEAM_COLORS[variants[i].color]
			var origin := Vector2(8 + (i % 4) * 78, 38 + (i / 4) * 40)
			var tank: TextureRect = hud.icon(summary, hud.game.ui_textures[kind + "_" + variants[i].color], origin, Vector2(32, 32))
			tank.modulate = Color.WHITE
			add_color_frame(tank, tint)
			hud.label(summary, "x%s" % preload("res://scripts/display_numbers.gd").format(variants[i].count), origin + Vector2(36, 4), Vector2(42, 24), 16)
			var card := Panel.new()
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.size = CARD_SIZE
			card.material = hud.game.material
			card.add_theme_stylebox_override("panel", hud.style(hud.BACK))
			card.set_meta("enemy_kind", kind)
			add_child(card)
			var portrait: TextureRect = hud.icon(card, hud.game.ui_textures[kind + "_" + variants[i].color], Vector2(8, 8), Vector2(40, 40))
			portrait.modulate = Color.WHITE
			add_color_frame(portrait, tint)
			hud.label(card, hud.game.Content.ENEMY_TYPES[kind].name, Vector2(56, 10), Vector2(176, 28), 16)
			var health: float = hud.game.enemy_health(kind, wave)
			var enemy := {"kind": kind, "hp": health, "max_hp": health, "speed": hud.game.Content.ENEMY_TYPES[kind].speed}
			var text: String = preload("res://scripts/structure_info.gd").enemy_stats(hud.game, enemy).replace("   Shot interval:", "\nShot interval:")
			hud.label(card, text, Vector2(8, 52), Vector2(224, 144), 12)
		build_future_rows(46 + ceili(float(kinds.size()) / 4) * 40)
	show()
	summary.show()
	hud.tooltip_body.hide()
	var rows := maxi(1, floori((hud.root.size.y - 16) / (CARD_SIZE.y + 8)))
	rows = mini(rows, maxi(1, kinds.size()))
	var columns := ceili(float(kinds.size()) / rows)
	var extent := Vector2(columns * (CARD_SIZE.x + 8), rows * (CARD_SIZE.y + 8) - 8)
	var mouse: Vector2 = hud.ui_point(pointer)
	hud.tooltip.size = Vector2(380, 46 + ceili(float(kinds.size()) / 4) * 40 + future_height)
	var max_x := maxf(8, hud.root.size.x - hud.tooltip.size.x - extent.x - 16)
	hud.tooltip.position = Vector2(clampf(mouse.x + 18, 8, max_x), clampf(mouse.y - hud.tooltip.size.y / 2, 8, maxf(8, hud.root.size.y - hud.tooltip.size.y - 8)))
	position = Vector2(hud.tooltip.position.x + hud.tooltip.size.x + 8, clampf(mouse.y - extent.y / 2, 8, maxf(8, hud.root.size.y - extent.y - 8)))
	for i in get_child_count(): get_child(i).position = Vector2((i / rows) * (CARD_SIZE.x + 8), (i % rows) * (CARD_SIZE.y + 8))
func build_future_rows(top: float) -> void:
	var y := top
	if future_rows.size() > 1:
		hud.label(summary, "Future waves", Vector2(8, y), Vector2(350, 20), 11, hud.MUTED)
		y += 20
	for index in range(1, mini(7, future_rows.size())):
		var row: Dictionary = future_rows[index]
		var origin := Vector2(8, y)
		hud.label(summary, "Wave %d/%d" % [row.local, row.total], origin, Vector2(78, 20), 10, hud.MUTED)
		var x := 88.0
		for variant in row.variants:
			if x + 40 > 372:
				x = 88
				y += 18
			var tank: TextureRect = hud.icon(summary, hud.game.ui_textures[variant.kind + "_" + variant.color], Vector2(x, origin.y), Vector2(16, 16))
			tank.position.y = y
			tank.modulate = Color.WHITE
			add_color_frame(tank, hud.game.TEAM_COLORS[variant.color])
			hud.label(summary, "x%s" % preload("res://scripts/display_numbers.gd").format(variant.count), Vector2(x + 17, y), Vector2(23, 18), 10)
			x += 40
		y += 24
	future_height = y - top
func add_color_frame(target: Control, tint: Color) -> void:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = target.size
	target.add_child(frame)
	frame.draw.connect(func():
		var width := 1.0 / maxf(0.001, frame.get_screen_transform().x.length())
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size).grow(width / 2), tint, false, width)
	)



