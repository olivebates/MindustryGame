extends "res://tests/iron_supply_zoom.gd"
const Nuclear = preload("res://scripts/nuclear.gd")
const State = preload("res://scripts/save_state.gd")
func add(cell: Vector2i, kind: String) -> Dictionary:
	game._add_building(cell, kind, 0)
	game.buildings[cell].pending = false
	return game.buildings[cell]
func enemy(cell: Vector2i, kind := "horse") -> Dictionary:
	var e: Dictionary = game.create_enemy(kind, game.cell_center(cell), "green")
	game.enemies.append(e)
	return e
func run() -> void:
	fresh()
	game.tutorial_enabled = false
	game.tutorial.waves_started = false
	game.inventory.verdite = 1000
	check(game.Content.NUCLEAR_KINDS.size() == 7, "Seven plutonium structures remain")
	for kind in game.Content.REMOVED_NUCLEAR_KINDS:
		check(not game.BUILDINGS.has(kind) and not game.TECH.has(kind), kind + " is removed from structures and research")
	for kind in game.Content.NUCLEAR_KINDS:
		check(game.BUILDINGS[kind].cost.size() <= 2 and game.TECH[kind].cost.size() <= 2 and game.TECH[kind].core == 4, kind + " retains fourth-core and two-material requirements")
		check(not game.tech_core_unlocked(kind), kind + " stays locked before core four")
		check(game.ui_textures.has(kind), kind + " has a sprite")
		check(game.TECH[kind].parent == "" or game.TECH.has(game.TECH[kind].parent), kind + " has an available research parent")
	game.tutorial.ui_revealed.max_core_count = 4
	for kind in game.Content.NUCLEAR_KINDS: game.research(kind, true)
	var rows := {}
	var ids: Array[String] = game.hud.visible_tech_ids()
	var positions: Dictionary = game.hud.tech_positions(ids)
	for id in positions: rows[positions[id].y] = rows.get(positions[id].y, 0) + 1
	check(rows.values().all(func(count): return count <= 4), "Tech tree stays at four technologies per row")
	var drill := add(Vector2i(34, 25), "drill")
	game.ores[Vector2i(34, 25)] = "verdite"
	game.advance_logistics(5)
	check(drill.item == "verdite", "Plutonium uses normal extraction")
	drill.item = ""
	var reactor := add(Vector2i(31, 21), "reactor")
	var second_reactor := add(Vector2i(35, 21), "reactor")
	reactor.buffer.verdite = 20
	second_reactor.buffer.verdite = 20
	Nuclear.advance(game, 0.05)
	check(Nuclear.production_speed(drill) == 1.5, "Overlapping reactors never stack production boosts")
	check(not game.can_receive(Vector2i(31, 21), "coolant") and game.BUILDINGS.reactor.inputs.verdite == 20, "Reactor holds twenty plutonium and accepts no coolant")
	reactor.nuclear.heat = 1000
	reactor.nuclear.overheated = true
	reactor.nuclear.fuel = 0.0
	reactor.buffer.verdite = 2
	for step in 60: Nuclear.reactor(game, Vector2i(31, 21), reactor, 0.05)
	check(reactor.buffer.verdite == 1 and not reactor.nuclear.has("heat") and not reactor.nuclear.has("overheated"), "Reactor spends one plutonium per three active seconds without heat")
	Nuclear.reactor(game, Vector2i(31, 21), reactor, 0.05)
	check(reactor.buffer.verdite == 0, "Reactor loads the next fuel unit after three seconds")
	var injector := add(Vector2i(52, 30), "emergency_injector")
	var tower := add(Vector2i(52, 31), "solar")
	tower.hp = 5
	injector.buffer.verdite = 4
	Nuclear.advance(game, 0.05)
	check(tower.nuclear.injected == 0 and injector.buffer.verdite == 4, "Injector cannot activate with fewer than five plutonium")
	injector.buffer.verdite = 10
	Nuclear.advance(game, 0.05)
	check(injector.buffer.verdite == 5 and tower.nuclear.injected == 6 and tower.nuclear.emergency_shield == 50, "Injector uses five plutonium for its shield and boost")
	check(game.BUILDINGS.emergency_injector.inputs.verdite == 10, "Injector holds ten plutonium")
	game._damage_building(Vector2i(52, 31), 30)
	check(tower.hp == 5 and tower.nuclear.emergency_shield == 20, "Injector shield still absorbs damage")
	var chrono_cell := Vector2i(75, 25)
	var chrono := add(chrono_cell, "chrono_capacitor")
	chrono.buffer.verdite = 6
	var target := enemy(Vector2i(75, 28), "scout")
	target.nuclear_slow_time = 3.0
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	check(chrono.nuclear.get("pending_enemy", 0) == 0 and chrono.buffer.verdite == 6, "Capacitor ignores enemies already slowed")
	target.nuclear_slow_time = 0.0
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	Nuclear.chrono(game, chrono_cell, chrono, 0.9)
	check(target.nuclear_slow_time == 0 and chrono.buffer.verdite == 6, "Capacitor waits one second before firing")
	target.nuclear_slow_time = 4.0
	Nuclear.chrono(game, chrono_cell, chrono, 0.2)
	check(chrono.nuclear.pending_enemy == 0 and chrono.buffer.verdite == 6, "External slowing cancels the countdown without spending fuel")
	target.nuclear_slow_time = 0.0
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	Nuclear.chrono(game, chrono_cell, chrono, 1.0)
	check(target.nuclear_slow_time == 5 and chrono.buffer.verdite == 4, "A single unslowed enemy triggers a pulse for two plutonium")
	Nuclear.chrono(game, chrono_cell, chrono, 1.0)
	check(chrono.buffer.verdite == 4, "Slowed enemies cannot waste another charge")
	target.nuclear_slow_time = 0.0
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	target.pos = game.cell_center(Vector2i(100, 60))
	Nuclear.chrono(game, chrono_cell, chrono, 1.0)
	check(chrono.nuclear.pending_enemy == 0 and chrono.buffer.verdite == 4, "Leaving the square cancels the pending trigger")
	target.pos = game.cell_center(Vector2i(75, 28))
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	target.hp = 0
	Nuclear.chrono(game, chrono_cell, chrono, 1.0)
	check(chrono.nuclear.pending_enemy == 0 and chrono.buffer.verdite == 4, "Target death cancels the countdown without spending fuel")
	target.hp = target.max_hp
	chrono.buffer.verdite = 1
	Nuclear.chrono(game, chrono_cell, chrono, 0.05)
	check(chrono.nuclear.pending_enemy == 0 and target.nuclear_slow_time == 0, "Capacitor cannot start with fewer than two plutonium")
	var other_chrono := add(Vector2i(71, 25), "chrono_capacitor")
	chrono.buffer.verdite = 6
	other_chrono.buffer.verdite = 6
	Nuclear.advance(game, 0.05)
	for step in 20: Nuclear.advance(game, 0.05)
	check(chrono.buffer.verdite + other_chrono.buffer.verdite == 10 and target.nuclear_slow_time > 0, "Overlapping capacitors spend only one charge when their targets overlap")
	check(other_chrono.nuclear.pending_enemy == 0 and game.BUILDINGS.chrono_capacitor.inputs.verdite == 6, "The second trigger cancels and capacity is six plutonium")
	game.enemies.clear()
	var beacon_cell := Vector2i(55, 40)
	var beacon := add(beacon_cell, "breach_beacon")
	beacon.buffer.verdite = 1
	var victim := enemy(Vector2i(60, 41))
	victim.hp = 250.0
	Nuclear.tower(game, beacon_cell, beacon, 0.5)
	check(is_equal_approx(victim.hp, 247.5) and not game.shots.is_empty(), "Beacon laser deals one percent of maximum health per second")
	check(game.is_turret("breach_beacon") and beacon.buffer.verdite == 0, "Beacon is a fueled laser tower rather than an enemy lure")
	beacon.nuclear.fuel = 0.0
	var hp: float = victim.hp
	Nuclear.tower(game, beacon_cell, beacon, 0.5)
	check(victim.hp == hp, "Unfueled beacon cannot deal damage")
	game.enemies.clear()
	var lance_cell := Vector2i(52, 48)
	var lance := add(lance_cell, "isotope_lance")
	lance.buffer.verdite = 1
	var first := enemy(Vector2i(56, 49))
	var second := enemy(Vector2i(58, 49))
	Nuclear.tower(game, lance_cell, lance, 0.05)
	check(first.hp == first.max_hp - 35 and second.hp == second.max_hp - 35 and lance.nuclear.shots == 9, "Lance retains its piercing beam and requires only plutonium")
	game.enemies.clear()
	var engine_cell := Vector2i(90, 35)
	var engine := add(engine_cell, "containment_engine")
	engine.buffer.verdite = 3
	var blast_target := enemy(Vector2i(95, 36))
	Nuclear.tower(game, engine_cell, engine, 0.05)
	for step in 101: Nuclear.tower(game, engine_cell, engine, 0.05)
	check(blast_target.hp == blast_target.max_hp - 120 and engine.buffer.verdite == 0, "Containment works without the removed coolant supply")
	game.enemies.clear()
	var saved: Dictionary = State.capture(game)
	for record in saved.buildings:
		if record.kind == "chrono_capacitor" and record.cell == chrono_cell: record.buffer.verdite = 10
	for kind in game.Content.REMOVED_NUCLEAR_KINDS:
		saved.buildings.append({"kind":kind,"cell":Vector2i(100, 65),"nuclear":{"underlay":{"kind":"belt","dir":2,"hp":65}}})
		saved.tech[kind] = true
	var rebuilt: Array = State.expand(game, saved)
	check(not rebuilt.is_empty() and rebuilt[2].all(func(row): return not game.Content.REMOVED_NUCLEAR_KINDS.has(row[1])), "Old saves discard retired structures without failing")
	check(rebuilt[2].any(func(row): return row[0] == Vector2i(100, 65) and row[1] == "belt"), "Retired phase barriers preserve their underlying belts")
	check(game.Content.REMOVED_NUCLEAR_KINDS.all(func(kind): return not rebuilt[1][1].has(kind)), "Retired research is removed from loaded saves")
	check(rebuilt[1][0].verdite == saved.resources.verdite + 4, "Excess legacy plutonium above the reduced buffer capacity returns to inventory")
	print("PLUTONIUM CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
