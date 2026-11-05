extends Control
var game: Node2D
var hud: CanvasLayer
var cost: Dictionary = {}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_dt: float) -> void: update_preview()
func update_preview(pointer_override: Vector2 = Vector2.INF) -> void:
	visible = game.active_tool == "build" and game.selected != "" and game.is_cell_visible(game.hover_cell) and not hud.is_pointer_over_ui(pointer_override)
	if not visible: return
	var existing: Dictionary = game.building_at(game.hover_cell)
	if not existing.is_empty() and not (game.is_turret(game.selected) and existing.kind == "wall"):
		visible = false
		return
	cost = game.building_cost(game.selected, -1, game.hover_cell)
	var font := ThemeDB.fallback_font
	var width := 0.0
	for resource in cost: width += 18 + font.get_string_size(str(cost[resource]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6
	size = Vector2(width, 18)
	var dimension: float = game.footprint_size(game.selected) * game.TILE
	var bottom: Vector2 = Vector2(game.hover_cell * game.TILE) + Vector2(dimension / 2, dimension)
	position = game.get_canvas_transform() * bottom + Vector2(-width / 2, 4)
	queue_redraw()
func _draw() -> void:
	var x := 0.0
	var font := ThemeDB.fallback_font
	for resource in cost:
		draw_texture_rect(game.textures[resource + "_item"], Rect2(x, 2, 12, 12), false)
		var text := str(cost[resource])
		var color: Color = hud.INK if game.inventory[resource] >= cost[resource] else hud.ERROR_COLOR
		draw_string_outline(font, Vector2(x + 16, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(font, Vector2(x + 16, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		x += 18 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6
