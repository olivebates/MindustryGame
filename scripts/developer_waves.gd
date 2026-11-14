extends RefCounted
## Greedy wave capacity search. One complete, isolated battle per advance().
const STEP := 0.05
const MAX_TRIAL_SECONDS := 60.0
const MAX_ENEMIES := 1000
const COPY_FIELDS := ["buildings", "occupied", "rocks", "ores", "inventory", "researched", "cores", "current_core", "core_health", "core_build_radius", "base_copper_capacity", "base_material_capacity", "debug_resource_capacity", "placement_counts"]
enum Outcome { SURVIVED, DESTROYED, INCONCLUSIVE }
var game: Node2D
var baseline: Dictionary = {}
var roster: Array[String] = []
var sources: Dictionary = {}
var accepted: Array[Dictionary] = []
var results: Array[Dictionary] = []
var running := false
var status := "G: first turret / H: all turrets"
var wave_number := 0
var kind_index := 0
var credits := 0
var trials := 0
var first_loss := false
var initial_turrets := 0

func _init(owner_game: Node2D) -> void:
	game = owner_game

func start(stop_at_first_loss := false) -> void:
	if running or not game.developer_mode: return
	first_loss = stop_at_first_loss
	baseline.clear()
	for field in COPY_FIELDS:
		var value = game.get(field)
		baseline[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	initial_turrets = local_turret_count(baseline.buildings)
	wave_number = game.wave + 1
	roster.clear()
	sources.clear()
	accepted.clear()
	kind_index = 0
	credits = 0
	trials = 0
	# Match normal wave unlocks, per-gate overrides and shared wave colors, but
	# deliberately ignore the authored budget: this search measures that budget.
	var forecast: Dictionary = game.next_wave_forecast()
	for gate in game.active_spawners:
		var offset: int = game.pending_gate_waves(gate)
		var explicit: bool = gate.has_wave_enemy_override(offset)
		var colors: PackedStringArray = gate.colors_for_wave(offset)
		var color: String = forecast.color
		if not colors.has(color):
			for candidate in colors:
				if game.TEAM_COLORS.has(candidate):
					color = candidate
					break
		for kind in gate.enemies_for_wave(offset):
			if not game.Content.ENEMY_TYPES.has(kind): continue
			if not explicit and game.Content.ENEMY_TYPES[kind].unlock > wave_number: continue
			if not sources.has(kind):
				roster.append(kind)
				sources[kind] = []
			sources[kind].append({"pos": gate.position, "color": color})
	roster.sort_custom(func(a, b):
		var a_cost: int = game.Content.ENEMY_TYPES[a].credits
		var b_cost: int = game.Content.ENEMY_TYPES[b].credits
		return a < b if a_cost == b_cost else a_cost > b_cost)
	if not has_local_turrets(baseline.buildings):
		finish()
	elif roster.is_empty():
		status = "No enemies available for this wave."
	else:
		running = true
		status = "Simulating Round %d..." % wave_number
	refresh()

func has_local_turrets(buildings: Dictionary) -> bool:
	return local_turret_count(buildings) > 0

func local_turret_count(buildings: Dictionary) -> int:
	var count := 0
	for cell in buildings:
		var building: Dictionary = buildings[cell]
		if game.is_turret(building.kind) and not building.get("pending", false) and building.hp > 0 and cell.distance_squared_to(baseline.current_core) <= baseline.core_build_radius * baseline.core_build_radius:
			count += 1
	return count

func next_enemy(kind: String) -> Dictionary:
	var count := 0
	for enemy in accepted:
		if enemy.kind == kind: count += 1
	var source: Dictionary = sources[kind][count % sources[kind].size()]
	# Stable jitter keeps the accepted prefix identical across all trials.
	var random := RandomNumberGenerator.new()
	random.seed = wave_number * 1000003 + accepted.size()
	return {"kind": kind, "pos": source.pos + Vector2(random.randf_range(-18, 18), random.randf_range(-48, 48)), "color": source.color, "wave_id": wave_number}

func advance() -> void:
	if not running: return
	if accepted.size() >= MAX_ENEMIES:
		stop_inconclusive("enemy limit reached")
		return
	var candidate: Array[Dictionary] = accepted.duplicate(true)
	var kind: String = roster[kind_index]
	candidate.append(next_enemy(kind))
	var outcome := run_trial(candidate)
	trials += 1
	match outcome:
		Outcome.SURVIVED:
			accepted = candidate
			credits += game.Content.ENEMY_TYPES[kind].credits
		Outcome.DESTROYED:
			# The lethal addition is discarded; keep the last surviving prefix.
			kind_index += 1
		Outcome.INCONCLUSIVE:
			stop_inconclusive("battle did not resolve")
			return
	if kind_index == roster.size():
		finish()
	else:
		status = "Round %d: trial %d (%d credits kept)" % [wave_number, trials, credits]
	refresh()

func run_trial(units: Array[Dictionary]) -> Outcome:
	# Instantiate only the game script, outside the tree: no level rendering,
	# audio, HUD, checkpoints or automatic wave advancement are initialized.
	var simulation: Node2D = game.get_script().new()
	simulation.combat_preview = true
	simulation.tutorial_enabled = false
	simulation.tutorial = preload("res://scripts/tutorial.gd").new()
	simulation.tutorial.game = simulation
	simulation.add_child(simulation.tutorial)
	for field in COPY_FIELDS:
		var value = baseline[field]
		simulation.set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	simulation.wave = wave_number
	simulation.rng.seed = wave_number
	simulation.spawn_queue.assign(units.duplicate(true))
	simulation.spawn_remaining = units.size()
	# A battle that exceeds one simulated minute counts as a lethal addition.
	var outcome := Outcome.DESTROYED
	# Use the same fixed timestep, spawning cadence, navigation, logistics,
	# healing, shields and projectile damage as the live combat loop.
	for step in ceili(MAX_TRIAL_SECONDS / STEP) + 1:
		simulation.simulate(STEP)
		if local_turret_count(simulation.buildings) < (initial_turrets if first_loss else 1):
			outcome = Outcome.DESTROYED
			break
		if simulation.spawn_remaining == 0 and simulation.enemies.is_empty():
			outcome = Outcome.SURVIVED
			break
	simulation.free()
	return outcome

func finish() -> void:
	running = false
	var result := {"wave": wave_number, "credits": credits, "core": baseline.current_core, "units": accepted.duplicate(true)}
	var replaced := false
	for i in results.size():
		if results[i].wave == wave_number and results[i].core == baseline.current_core:
			result.merge(results[i], false)
			result["g_credits" if first_loss else "h_credits"] = credits
			results[i] = result
			replaced = true
			break
	if not replaced:
		result.g_credits = credits if first_loss else 0
		result.h_credits = 0 if first_loss else credits
		results.append(result)
	status = "G: first turret / H: all turrets"

func stop_inconclusive(reason: String) -> void:
	running = false
	status = "Round %d: inconclusive (%s). H: retry" % [wave_number, reason]
	refresh()

func refresh() -> void:
	if is_instance_valid(game.hud): game.hud.refresh_developer_waves()
