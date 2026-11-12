extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	game.research("splitter",true)
	game.research("teleporters",true)
	var a := Vector2i(24,25)
	var b := Vector2i(30,25)
	var copper: int = game.inventory.copper
	var iron: int = game.inventory.iron
	check(game.place_building(a,"teleporter",0) and game.inventory.copper == copper and game.inventory.iron == iron, "First node is placed without charging resources")
	check(game.buildings[a].pending and not game.can_receive(a,"copper"), "Unpaired node is inactive")
	check(game.saves.snapshot()[2].all(func(row): return row[1] != "teleporter"), "Unpaid node is excluded from checkpoints")
	game.cancel_build_selection()
	check(not game.buildings.has(a) and game.inventory.copper == copper, "Cancel removes unpaid first node")
	game.place_building(a,"teleporter",0)
	game.inventory.iron = 0
	check(not game.place_building(b,"teleporter",0) and game.buildings.has(a) and not game.buildings.has(b), "Unaffordable second node leaves pair unfinished without charging")
	game.inventory.iron = iron
	check(game.place_building(b,"teleporter",0) and game.inventory.copper == copper-30 and game.inventory.iron == iron-5, "Second node charges the pair once")
	check(game.buildings[a].tunnel_pair == b and game.buildings[b].tunnel_pair == a, "Pair links are reciprocal")
	check(game.building_cost("teleporter") == {"iron":6,"copper":38}, "Next pair price increases by twenty-five percent")
	game._add_building(b+Vector2i.RIGHT,"belt",0)
	game.refresh_belt_inputs()
	check(game.buildings[b+Vector2i.RIGHT].input_dir == 0, "Belt sprite accepts teleporter input")
	game.buildings[a].item = "iron"
	game.teleporters.transfer()
	check(game.buildings[a].item == "" and game.buildings[b].item == "iron", "Incoming resource teleports to paired node")
	game._update_items(4)
	check(game.buildings[b].item == "" and game.buildings[b+Vector2i.RIGHT].item == "iron", "Remote node distributes to outgoing belt")
	game._add_building(b+Vector2i.UP,"splitter",0)
	game._add_building(b+Vector2i.DOWN,"turret",0)
	game.buildings[b+Vector2i.DOWN].ammo = 0
	check(game.splitter_outputs(b,"iron").has(3) and game.splitter_outputs(b,"iron").has(1), "Remote node also outputs to splitters and resource-consuming buildings")
	game.buildings[a].item = "iron"
	game.buildings[a].progress = 0
	game.buildings[b].item = "copper"
	game.buildings[b].progress = 0
	game.teleporters.transfer()
	check(game.buildings[a].item == "copper" and game.buildings[b].item == "iron", "Simultaneous bidirectional input does not deadlock")
	var snapshot: Array = game.saves.snapshot()
	game.saves.restore_snapshot(snapshot,-1)
	check(game.buildings[a].tunnel_pair == b and game.buildings[b].tunnel_pair == a, "Checkpoint restores pair links")
	game.remove_building(a,false)
	check(not game.buildings.has(a) and not game.buildings.has(b), "Deleting a node removes both")
	game._add_building(a,"splitter",0)
	game._add_building(a+Vector2i.DOWN,"belt",0)
	game.refresh_belt_inputs()
	check(game.buildings[a+Vector2i.DOWN].input_dir == 1, "Belt corner accepts splitter input")
	check(game.TECH.teleporters.parent == "splitter" and game.TECH.teleporters.core == 3 and game.TECH.teleporters.cost == {"iron":30}, "Teleporter research follows splitter at core three for thirty scales")
	print("TELEPORTER CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
