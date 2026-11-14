extends SceneTree
const Search = preload("res://scripts/developer_waves.gd")
var game: Node2D
var failures := 0
var checks := 0

class ScriptedSearch extends Search:
	var candidates: Array = []
	func run_trial(units: Array[Dictionary]) -> Outcome:
		var cost := 0
		var kinds: Array = []
		for unit in units:
			cost += game.Content.ENEMY_TYPES[unit.kind].credits
			kinds.append(unit.kind)
		candidates.append(kinds)
		return Outcome.DESTROYED if cost > 18 else Outcome.SURVIVED

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func key(code: Key, pressed := true, shift := false, echo := false) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	return game.handle_debug_shortcut(event)

func configure_gate(kinds: PackedStringArray) -> void:
	game.active_spawners.assign([game.spawners[0]])
	var gate: Node2D = game.spawners[0]
	gate.waves_completed = 0
	gate.position = game.cell_center(Vector2i(31, 22))
	gate.allowed_enemies = kinds
	gate.wave_enemy_lists.assign([kinds])
	gate.wave_color_palettes.assign([PackedStringArray(["red"])])

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.tutorial.set_process(false)
	game.hud.set_process(false)
	game.audio.muted = true
	game.rocks.clear()
	game.ores.clear()
	game.paused = true
	game._add_building(Vector2i(27, 22), "solar", 0)
	configure_gate(PackedStringArray(["heavy", "scout"]))
	check(not key(KEY_H) and not game.developer_waves.running, "H is inactive outside developer mode")
	key(KEY_Z, true, true)
	check(not game.developer_mode, "Shift+Z alone does not enter developer mode")
	check(key(KEY_B, true, true) and game.developer_mode, "Shift+Z+B enters developer mode")
	key(KEY_Z, false)
	key(KEY_B, false)
	check(game.hud.developer_panel.visible and game.hud.developer_panel.position.x > game.hud.inventory_panel.size.x, "Credits panel sits to the right of resources")
	check(not key(KEY_H, true, false, true), "Held H does not start repeat searches")
	check(key(KEY_H) and game.developer_waves.running, "H starts a search while the game is paused")
	check(game.developer_waves.trials == 0, "Input schedules work without running a battle immediately")
	key(KEY_H)
	check(game.developer_waves.trials == 0 and game.developer_waves.running, "A second H press leaves the active search intact")
	var search: RefCounted = game.developer_waves
	check(search.roster == ["heavy", "scout"], "An explicit wave roster permits expensive enemies before their normal unlock")
	var state_before: Array = game.saves.snapshot().duplicate(true)
	var rng_before: int = game.rng.state
	var tutorial_before: Dictionary = game.tutorial.ui_revealed.duplicate(true)
	var saves_before: Array = game.saves.entries.duplicate(true)
	var started := Time.get_ticks_msec()
	for frame in 50:
		if not search.running: break
		var previous: int = search.trials
		game._process(0)
		check(search.trials == previous + 1, "One complete battle runs per frame advance")
	check(not search.running and search.results.size() == 1, "Real combat search completes with a credit result")
	if not search.results.is_empty():
		var result: Dictionary = search.results[0]
		check(result.wave == 1 and result.credits >= 0, "Result identifies the upcoming wave")
		check(search.run_trial(result.units) == Search.Outcome.SURVIVED, "Accepted army leaves a local turret standing")
		var lethal: Array[Dictionary] = result.units.duplicate(true)
		lethal.append(search.next_enemy("scout"))
		check(search.run_trial(lethal) == Search.Outcome.DESTROYED, "One additional cheapest enemy destroys all local turrets")
		check(game.hud.developer_credit_list.text.contains("Round 1: 0-%d" % result.credits), "HUD uses the requested result wording")
	check(game.saves.snapshot() == state_before and game.rng.state == rng_before and game.tutorial.ui_revealed == tutorial_before and game.saves.entries == saves_before and game.shots.is_empty() and game.particles.is_empty(), "Simulations leave live combat, inventory, RNG, tutorial and saves untouched")
	print("Real search elapsed ms: ", Time.get_ticks_msec() - started)
	var h_amount: int = search.results[0].h_credits
	check(key(KEY_G) and search.first_loss and search.running, "G starts the first-turret-loss search")
	for frame in 50:
		if not search.running: break
		game._process(0)
	check(not search.running and search.results.size() == 1 and search.results[0].h_credits == h_amount, "G preserves the H result in the same round")
	check(game.hud.developer_credit_list.text.contains("Round 1: %d-%d" % [search.results[0].g_credits, h_amount]), "Round displays G then H amounts")
	search.start()
	check(not search.first_loss, "H selects all-turret-loss mode again")
	search.running = false
	# Deterministic battles make the greedy boundary and retained mixed army
	# independent of future balance changes to individual weapons.
	var scripted := ScriptedSearch.new(game)
	scripted.start()
	for frame in 20:
		if not scripted.running: break
		scripted.advance()
	check(scripted.candidates == [["heavy"], ["heavy", "heavy"], ["heavy", "heavy", "heavy"], ["heavy", "heavy", "scout"], ["heavy", "heavy", "scout", "scout"], ["heavy", "heavy", "scout", "scout", "scout"]], "Search rejects the lethal addition and retains expensive units while filling with cheaper ones")
	check(scripted.results.size() == 1 and scripted.results[0].credits == 18, "Only accepted enemies contribute credits")
	# The baseline is captured at H, even if the live world changes afterward.
	var captured_hp: float = search.baseline.buildings[Vector2i(27, 22)].hp
	game.buildings[Vector2i(27, 22)].hp = 1
	check(search.baseline.buildings[Vector2i(27, 22)].hp == captured_hp, "Later live changes do not alter a captured baseline")
	game.buildings[Vector2i(27, 22)].pending = true
	game._add_building(Vector2i(100, 70), "turret", 0)
	search.start()
	check(not search.running and search.results.size() == 1 and search.results[0].credits == 0, "Pending and distant turrets do not count; rerunning replaces the same wave entry")
	game.buildings[Vector2i(27, 22)].pending = false
	game.spawners[0].wave_enemy_lists.clear()
	search.start()
	check(search.roster == ["scout"], "Normal enemy unlocks filter unavailable expensive types")
	search.running = false
	game.spawners[0].allowed_enemies = PackedStringArray()
	search.start()
	check(not search.running and search.status.contains("No enemies"), "Empty rosters stop cleanly")
	# Losing the core must not stop a turret-capacity trial or open save UI.
	configure_gate(PackedStringArray(["scout"]))
	game.buildings[game.current_core].hp = 0.1
	search.start()
	var core_attack: Array[Dictionary] = [{"kind": "scout", "pos": game.cell_center(game.current_core + Vector2i(-1, 0)), "color": "red", "wave_id": 1}]
	check(search.run_trial(core_attack) == Search.Outcome.DESTROYED, "Trials continue after core destruction until the last local turret is destroyed")
	check(game.buildings[game.current_core].hp == 0.1 and not game.lost and not is_instance_valid(game.hud.modal), "Simulated core destruction cannot end the live game")
	search.running = false
	# A trapped enemy exceeds the one-minute limit and rejects this tier.
	configure_gate(PackedStringArray(["scout"]))
	var trapped := Vector2i(60, 50)
	for direction in game.DIRS: game.rocks[trapped + direction] = true
	search.start()
	var units: Array[Dictionary] = [{"kind": "scout", "pos": game.cell_center(trapped), "color": "red", "wave_id": 1}]
	check(search.run_trial(units) == Search.Outcome.DESTROYED, "Combat exceeding one simulated minute counts as all turrets destroyed")
	search.running = false
	game.free()
	print("DEVELOPER WAVES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
