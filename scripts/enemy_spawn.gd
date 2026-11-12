@tool
extends Node2D
## Configure expedition progression directly in the Godot inspector.
@export var Order: int = 1
@export_range(1, 100) var waves_before_conversion: int = 4
@export var turns_into_core := true
## Added to base building prices inside this core's range; 100 means double.
@export var core_resource_price_increase: Dictionary[String, float] = {"copper": 0.0, "iron": 0.0, "verdite": 0.0, "alloy": 0.0, "pink": 0.0}
@export var credits_per_wave: PackedInt32Array = PackedInt32Array([9, 28, 42, 60])
@export_enum("red", "green", "blue") var possible_colors: PackedStringArray = PackedStringArray(["red", "green", "blue"])
@export var wave_color_palettes: Array[PackedStringArray] = []
@export_enum("Squirrel", "Bunny", "Tapir", "Deer", "Bison", "Elephant", "Tortoise", "Gazelle", "Horse") var allowed_enemies: PackedStringArray = PackedStringArray(["Squirrel", "Bunny", "Tapir", "Deer", "Bison", "Elephant", "Tortoise", "Gazelle", "Horse"]):
	set(value): allowed_enemies = enemy_display_names(value)
## Entry 0 configures this spawn's first wave. Missing/empty entries use allowed_enemies.
@export var wave_enemy_lists: Array[PackedStringArray] = []:
	set(value):
		wave_enemy_lists = []
		for entries in value: wave_enemy_lists.append(enemy_display_names(entries))
var waves_completed := 0
var converted := false
var active := false
var prepared_color := "red"
var gate_label: Label
var face_icon: Texture2D
func _enter_tree() -> void:
	if not Engine.is_editor_hint(): return
	# Inspector array editors cache their element options across tool-script reloads.
	var source: Script = get_script()
	if not source.changed.is_connected(refresh_inspector_options):
		source.changed.connect(refresh_inspector_options)
	refresh_inspector_options()
func refresh_inspector_options() -> void:
	notify_property_list_changed.call_deferred()
static func enemy_dropdown_choices() -> String:
	var names := PackedStringArray()
	for data in preload("res://scripts/content.gd").ENEMY_TYPES.values(): names.append(data.name)
	return ",".join(names)
func _validate_property(property: Dictionary) -> void:
	if property.name == "allowed_enemies":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, enemy_dropdown_choices()]
	elif property.name == "core_resource_price_increase":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:copper,iron,verdite,alloy,pink;%d:" % [TYPE_STRING, PROPERTY_HINT_ENUM, TYPE_FLOAT]
	elif property.name in ["wave_enemy_lists", "wave_color_palettes"]:
		var choices := enemy_dropdown_choices() if property.name == "wave_enemy_lists" else "red,green,blue"
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:%d/%d:%s" % [TYPE_PACKED_STRING_ARRAY, PROPERTY_HINT_TYPE_STRING, TYPE_STRING, PROPERTY_HINT_ENUM, choices]
func _ready() -> void:
	if Engine.is_editor_hint(): return
	gate_label = Label.new()
	gate_label.position = Vector2(-33, 35)
	gate_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gate_label.add_theme_font_override("font", preload("res://PixelifySans.ttf"))
	gate_label.add_theme_font_size_override("font_size", 12)
	gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gate_label)

func budget(offset: int = 0) -> int:
	if credits_per_wave.is_empty(): return 0
	return maxi(0, credits_per_wave[mini(waves_completed + offset, credits_per_wave.size() - 1)])
func colors_for_wave(offset: int = 0) -> PackedStringArray:
	if wave_color_palettes.is_empty(): return possible_colors
	return wave_color_palettes[mini(waves_completed + offset, wave_color_palettes.size() - 1)]
func has_wave_enemy_override(offset: int = 0) -> bool:
	var index := waves_completed + offset
	return index < wave_enemy_lists.size() and not wave_enemy_lists[index].is_empty()
func enemies_for_wave(offset: int = 0) -> PackedStringArray:
	var entries: PackedStringArray = wave_enemy_lists[waves_completed + offset] if has_wave_enemy_override(offset) else allowed_enemies
	var result := PackedStringArray()
	var types: Dictionary = preload("res://scripts/content.gd").ENEMY_TYPES
	for entry in entries:
		if types.has(entry): result.append(entry)
		else:
			for id in types:
				if types[id].name == entry:
					result.append(id)
					break
	return result
static func enemy_display_names(entries: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var types: Dictionary = preload("res://scripts/content.gd").ENEMY_TYPES
	for entry in entries: result.append(types[entry].name if types.has(entry) else entry)
	return result
func _draw() -> void:
	if converted: return
	var color := Color("eb9376") if active or Engine.is_editor_hint() else Color("776267")
	draw_circle(Vector2.ZERO, 25, Color("201418"))
	draw_arc(Vector2.ZERO, 31, 0, TAU, 48, Color(color, 0.7), line_width())
	draw_arc(Vector2.ZERO, 23, 0, TAU, 40, color, line_width())
	if face_icon == null:
		face_icon = preload("res://scripts/pixel_art.gd").texture(load("res://assets/ui/spawn_face.svg"), Vector2i(64, 64))
	draw_texture_rect(face_icon, Rect2(-18, -18, 36, 36), false, color)
	if Engine.is_editor_hint(): draw_string(preload("res://PixelifySans.ttf"), Vector2(-33, 49), "GATE " + (preload("res://scripts/display_numbers.gd").format(Order) if Order >= 1000 else "%02d" % Order), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	elif is_instance_valid(gate_label):
		gate_label.text = "GATE " + (preload("res://scripts/display_numbers.gd").format(Order) if Order >= 1000 else "%02d" % Order)
		gate_label.add_theme_color_override("font_color", color)




func line_width() -> float:
	return preload("res://scripts/drawing_style.gd").stroke(self)


