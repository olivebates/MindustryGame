extends RefCounted
static func variants(colored: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for color in colored:
		for kind in colored[color]: result.append({"kind": kind, "color": color, "count": colored[color][kind]})
	return result
static func signature(game: Node2D, selected: int) -> int:
	var state: Array = [game.wave, game.pending_waves, selected]
	for gate in game.spawners:
		state.append([gate.waves_completed, gate.converted, gate.Order, gate.waves_before_conversion, gate.turns_into_core, gate.credits_per_wave, gate.possible_colors, gate.wave_color_palettes, gate.allowed_enemies, gate.wave_enemy_lists])
	return hash(state)
static func build(game: Node2D, selected: int, count: int = 7) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var states: Array = []
	var number: int = game.wave + 1
	for gate in game.spawners:
		var completed: int = gate.waves_completed + game.pending_gate_waves(gate)
		var converted: bool = gate.converted or completed >= gate.waves_before_conversion
		if converted and not gate.converted and gate.turns_into_core: number = 1
		states.append([completed, converted, gate.prepared_color])
	var started: bool = states[selected][1] and not game.spawners[selected].converted
	if started:
		# The main popup shows this gate's already scheduled final wave.
		result.append({"number": game.wave, "local": game.spawners[selected].waves_before_conversion, "total": game.spawners[selected].waves_before_conversion, "order": game.spawners[selected].Order, "variants": []})
	for _step in 1000:
		if started and states[selected][1]: break
		var order := 2147483647
		for index in states.size():
			if not states[index][1]: order = mini(order, game.spawners[index].Order)
		if order == 2147483647: break
		var indices: Array = []
		for index in states.size():
			if not states[index][1] and game.spawners[index].Order == order: indices.append(index)
		var forecast := preload("res://scripts/wave_forecast.gd").build(game, number, indices, states)
		if indices.has(selected): started = true
		if started:
			var colored: Dictionary = {}
			for index in indices:
				# Keep this spawn's rows separate until progression moves beyond it.
				if indices.has(selected) and index != selected: continue
				for color in forecast.by_spawn[index].colored:
					if not colored.has(color): colored[color] = {}
					for kind in forecast.by_spawn[index].colored[color]: colored[color][kind] = colored[color].get(kind, 0) + forecast.by_spawn[index].colored[color][kind]
			var gate_index: int = selected if indices.has(selected) else indices[0]
			result.append({"number": number, "local": states[gate_index][0] + 1, "total": game.spawners[gate_index].waves_before_conversion, "order": order, "variants": variants(colored)})
			if result.size() >= count: break
		var reset := false
		for index in indices:
			states[index][0] += 1
			if states[index][0] >= game.spawners[index].waves_before_conversion:
				states[index][1] = true
				if game.spawners[index].turns_into_core: reset = true
		number = 1 if reset else number + 1
	return result
