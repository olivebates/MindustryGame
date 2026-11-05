extends Control
var hud: CanvasLayer
var summary: Control
var signature := 0
const CARD_SIZE := Vector2(240, 204)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary = Control.new()
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.tooltip.add_child(summary)
func hide_preview() -> void:
	hide()
	if is_instance_valid(summary): summary.hide()
func show_forecast(counts: Dictionary, pointer: Vector2, wave: int) -> void:
	var key := hash([counts, wave])
	var kinds: Array = []
	for kind in hud.game.Content.ENEMY_TYPES:
		if counts.get(kind, 0) > 0: kinds.append(kind)
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
			var origin := Vector2(8 + (i % 4) * 78, 38 + (i / 4) * 40)
			hud.icon(summary, hud.game.ui_textures[kind], origin, Vector2(32, 32))
			hud.label(summary, "x%s" % preload("res://scripts/display_numbers.gd").format(counts[kind]), origin + Vector2(36, 4), Vector2(42, 24), 16)
			var card := Panel.new()
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.size = CARD_SIZE
			card.material = hud.game.material
			card.add_theme_stylebox_override("panel", hud.style(hud.BACK))
			card.set_meta("enemy_kind", kind)
			add_child(card)
			hud.icon(card, hud.game.ui_textures[kind], Vector2(8, 8), Vector2(40, 40))
			hud.label(card, hud.game.Content.ENEMY_TYPES[kind].name, Vector2(56, 10), Vector2(176, 28), 16)
			var health: float = hud.game.enemy_health(kind, wave)
			var enemy := {"kind": kind, "hp": health, "max_hp": health, "speed": hud.game.Content.ENEMY_TYPES[kind].speed}
			var text: String = preload("res://scripts/structure_info.gd").enemy_stats(hud.game, enemy).replace("   Shot interval:", "\nShot interval:")
			hud.label(card, text, Vector2(8, 52), Vector2(224, 144), 12)
	show()
	summary.show()
	hud.tooltip_body.hide()
	var rows := maxi(1, floori((hud.root.size.y - 16) / (CARD_SIZE.y + 8)))
	rows = mini(rows, maxi(1, kinds.size()))
	var columns := ceili(float(kinds.size()) / rows)
	var extent := Vector2(columns * (CARD_SIZE.x + 8), rows * (CARD_SIZE.y + 8) - 8)
	var mouse: Vector2 = hud.ui_point(pointer)
	hud.tooltip.size = Vector2(330, 46 + ceili(float(kinds.size()) / 4) * 40)
	var max_x := maxf(8, hud.root.size.x - hud.tooltip.size.x - extent.x - 16)
	hud.tooltip.position = Vector2(clampf(mouse.x + 18, 8, max_x), clampf(mouse.y - hud.tooltip.size.y / 2, 8, maxf(8, hud.root.size.y - hud.tooltip.size.y - 8)))
	position = Vector2(hud.tooltip.position.x + hud.tooltip.size.x + 8, clampf(mouse.y - extent.y / 2, 8, maxf(8, hud.root.size.y - extent.y - 8)))
	for i in get_child_count(): get_child(i).position = Vector2((i / rows) * (CARD_SIZE.x + 8), (i % rows) * (CARD_SIZE.y + 8))



