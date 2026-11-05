@tool
extends Node2D
## Configure expedition progression directly in the Godot inspector.
@export var Order: int = 1
@export_range(1, 100) var waves_before_conversion: int = 4
@export var turns_into_core := true
@export var credits_per_wave: PackedInt32Array = PackedInt32Array([9, 28, 42, 60])
@export var possible_colors: PackedStringArray = PackedStringArray(["red", "green", "blue"])
@export var wave_color_palettes: Array[PackedStringArray] = []
@export var allowed_enemies: PackedStringArray = PackedStringArray(["scout", "runner", "heavy", "skirmisher", "bulwark", "siege", "mender"])
## Entry 0 configures this spawn's first wave. Missing/empty entries use allowed_enemies.
@export var wave_enemy_lists: Array[PackedStringArray] = []
var waves_completed := 0
var converted := false
var active := false
var prepared_color := "red"

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
	if has_wave_enemy_override(offset): return wave_enemy_lists[waves_completed + offset]
	return allowed_enemies
func _draw() -> void:
	if converted: return
	var color := Color("eb9376") if active or Engine.is_editor_hint() else Color("776267")
	draw_circle(Vector2.ZERO, 25, Color("201418"))
	draw_arc(Vector2.ZERO, 31, 0, TAU, 48, Color(color, 0.7), 1)
	draw_arc(Vector2.ZERO, 23, 0, TAU, 40, color, 2)
	for i in 3:
		var p := Vector2(i * 11 - 11, 0)
		draw_polyline(PackedVector2Array([p + Vector2(3, -7), p + Vector2(-3, 0), p + Vector2(3, 7)]), color, 2)
	draw_string(ThemeDB.fallback_font, Vector2(-33, 49), "GATE %02d" % Order, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
