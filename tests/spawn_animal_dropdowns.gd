extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	var gate = load("res://scripts/enemy_spawn.gd").new()
	var properties := {}
	var stale := {"name":"allowed_enemies","hint":PROPERTY_HINT_ENUM,"hint_string":"scout,runner,heavy,skirmisher,bulwark,siege,mender"}
	gate._validate_property(stale)
	check(stale.hint_string.contains("Gazelle") and stale.hint_string.contains("Horse") and not stale.hint_string.contains("scout"), "Stale inspector options are replaced by the live enemy definitions")
	for property in gate.get_property_list(): properties[property.name] = property
	for field in ["allowed_enemies","wave_enemy_lists"]:
		for animal in ["Squirrel","Bunny","Gazelle","Horse"]:
			check(properties[field].hint_string.contains(animal), field + " offers " + animal)
	gate.allowed_enemies = PackedStringArray(["scout","runner","gazelle","horse"])
	check(gate.allowed_enemies == PackedStringArray(["Squirrel","Bunny","Gazelle","Horse"]), "Existing enemy IDs display as animal names")
	check(gate.enemies_for_wave() == PackedStringArray(["scout","runner","gazelle","horse"]), "Dropdown names resolve to save-compatible gameplay IDs")
	var waves: Array[PackedStringArray] = [PackedStringArray(["Bunny","Horse"]),PackedStringArray(["scout","gazelle"]),PackedStringArray()]
	gate.wave_enemy_lists = waves
	check(gate.enemies_for_wave() == PackedStringArray(["runner","horse"]), "Per-wave animal selections resolve correctly")
	check(gate.enemies_for_wave(1) == PackedStringArray(["scout","gazelle"]), "Old per-wave IDs migrate correctly")
	check(gate.enemies_for_wave(2) == gate.enemies_for_wave(3), "Empty wave selection falls back to the spawn roster")
	for authored_gate in game.spawners:
		check(not authored_gate.enemies_for_wave().is_empty(), "Authored spawn roster remains valid")
	gate.free()
	print("SPAWN DROPDOWN CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
