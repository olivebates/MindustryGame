extends Control
var game: Node2D
var hud: CanvasLayer
var cost: Dictionary = {}
var icon_layer: Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Keep the cost text independent from the pixelated material icons.
	icon_layer = Control.new()
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_layer.material = hud.icon_material()
	icon_layer.draw.connect(_draw_icons)
	add_child(icon_layer)
func _process(_dt: float) -> void: update_preview()
func update_preview(pointer_override: Vector2 = Vector2.INF) -> void:
	visible = game.active_tool == "build" and game.selected != "" and game.is_cell_visible(game.hover_cell) and not hud.is_pointer_over_ui(pointer_override)
	if not visible: return
	var existing: Dictionary = game.building_at(game.hover_cell)
	if not existing.is_empty() and not ((game.is_turret(game.selected) and existing.kind in ["wall", "wall_iron"]) or (game.selected == "splitter" and existing.kind == "belt")):
		visible = false
		return
	cost = game.building_cost(game.selected, -1, game.hover_cell)
	var font := preload("res://PixelifySans.ttf")
	var width := 0.0
	for resource in cost: width += 18 + font.get_string_size(preload("res://scripts/display_numbers.gd").format(cost[resource]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6
	size = Vector2(width, 18)
	var dimension: float = game.footprint_size(game.selected) * game.TILE
	var bottom: Vector2 = Vector2(game.hover_cell * game.TILE) + Vector2(dimension / 2, dimension)
	position = hud.ui_point(game.get_canvas_transform() * bottom) + Vector2(-width / 2, 4)
	queue_redraw()
	icon_layer.queue_redraw()
func _draw_icons() -> void:
	var x := 0.0
	var font := preload("res://PixelifySans.ttf")
	for resource in cost:
		icon_layer.draw_texture_rect(game.ui_textures[resource + "_item"], Rect2(x, 2, 12, 12), false)
		var text := preload("res://scripts/display_numbers.gd").format(cost[resource])
		x += 18 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6
func _draw() -> void:
	var x := 0.0
	var font := preload("res://PixelifySans.ttf")
	for resource in cost:
		var text := preload("res://scripts/display_numbers.gd").format(cost[resource])
		var color: Color = hud.INK if game.inventory[resource] >= cost[resource] else hud.ERROR_COLOR
		draw_string_outline(font, Vector2(x + 16, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(font, Vector2(x + 16, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		x += 18 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6





