extends RefCounted
static func build(game: Node2D, number: int, indices: Array, states: Array = [], pending: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = number
	var offsets: Dictionary = {}
	var palette := ["red", "green", "blue"]
	var all_colors: Array[String] = []
	for index in indices:
		var gate = game.spawners[index]
		var completed: int = gate.waves_completed if states.is_empty() else int(states[index][0])
		var outstanding := 0
		for wave_id in pending:
			if int(wave_id) != number and pending[wave_id].has(index): outstanding += 1
		offsets[index] = completed + outstanding - gate.waves_completed
		var colors: PackedStringArray = gate.colors_for_wave(offsets[index])
		palette = palette.filter(func(color): return colors.has(color))
		for color in colors:
			if game.TEAM_COLORS.has(color) and not all_colors.has(color): all_colors.append(color)
	if palette.is_empty(): palette.assign(all_colors)
	if palette.is_empty(): palette = ["red"]
	var color_rng := RandomNumberGenerator.new()
	color_rng.seed = number
	var shared_color: String = palette[color_rng.randi_range(0, palette.size() - 1)]
	var units: Array[Dictionary] = []
	var by_spawn: Dictionary = {}
	var budget := 0
	for index in indices:
		var gate = game.spawners[index]
		var credits: int = gate.budget(offsets[index])
		budget += credits
		var remaining := credits
		var roster: PackedStringArray = gate.enemies_for_wave(offsets[index])
		var explicit: bool = gate.has_wave_enemy_override(offsets[index])
		var maximum := 0
		var counts: Dictionary = {}
		var colored: Dictionary = {}
		var emitted_colors: Array[String] = []
		for kind in roster:
			if game.Content.ENEMY_TYPES.has(kind):
				var data: Dictionary = game.Content.ENEMY_TYPES[kind]
				if (explicit or data.unlock <= number) and data.credits <= credits: maximum = maxi(maximum, data.credits)
		while remaining > 0 and units.size() < 1000:
			var affordable: Array[String] = []
			for kind in roster:
				if not game.Content.ENEMY_TYPES.has(kind): continue
				var data: Dictionary = game.Content.ENEMY_TYPES[kind]
				if (explicit or data.unlock <= number) and data.credits <= remaining and (remaining < maximum or data.credits == maximum): affordable.append(kind)
			if affordable.is_empty(): break
			var kind: String = affordable[rng.randi_range(0, affordable.size() - 1)]
			remaining -= game.Content.ENEMY_TYPES[kind].credits
			var position: Vector2 = gate.position + Vector2(rng.randf_range(-18, 18), rng.randf_range(-48, 48))
			var color := shared_color
			var colors: PackedStringArray = gate.colors_for_wave(offsets[index])
			if not colors.has(color):
				var valid: Array[String] = []
				for candidate in colors:
					if game.TEAM_COLORS.has(candidate): valid.append(candidate)
				if not valid.is_empty(): color = valid[rng.randi_range(0, valid.size() - 1)]
			units.append({"kind": kind, "pos": position, "color": color, "wave_id": number})
			if not emitted_colors.has(color): emitted_colors.append(color)
			counts[kind] = counts.get(kind, 0) + 1
			if not colored.has(color): colored[color] = {}
			colored[color][kind] = colored[color].get(kind, 0) + 1
		by_spawn[index] = {"counts": counts, "budget": credits, "colors": emitted_colors, "colored": colored}
	return {"units": units, "by_spawn": by_spawn, "budget": budget, "color": shared_color, "rng_state": rng.state}
