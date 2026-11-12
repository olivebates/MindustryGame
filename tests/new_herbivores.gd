extends "res://tests/iron_supply_zoom.gd"

func run() -> void:
	fresh()
	for row in [["runner","Bunny",5,20,5],["gazelle","Gazelle",25,100,6],["horse","Horse",125,500,5]]:
		var data: Dictionary = game.Content.ENEMY_TYPES[row[0]]
		check(data.name == row[1] and data.credits == row[2] and data.hp == row[3] and data.speed == row[4] * game.TILE and data.reload == 1 and data.damage == 1, row[1] + " has requested combat and movement stats")
		check(game.enemy_health(row[0],1) == row[3] and game.enemy_health(row[0],20) == row[3], row[1] + " retains its specified health across waves")
		for resolution in [16,32,64]:
			var sprites: Dictionary = game.sprite_rasters(resolution)
			check(sprites.has(row[0]+"_red") and sprites[row[0]+"_red"].get_width() == resolution, row[1] + " has colored art at " + str(resolution))
	check(game.Content.ENEMY_TYPES.scout.name == "Squirrel", "Smallest enemy is a squirrel")
	game.tutorial.ui_revealed.copper_storage_hint = true
	game.research("barriers",true)
	game.research("solar_speed",true)
	game.research("turret_range",true)
	check(not game.tutorial.storage_hint_active() and game.tutorial.storage_hint_tech() == "", "Old storage hints no longer highlight the silo or research button")
	var info = load("res://scripts/structure_info.gd")
	game._add_building(Vector2i(27,25),"refinery",0)
	var distillery: Dictionary = game.buildings[Vector2i(27,25)]
	distillery.item = "pink"
	var stats: String = info.stats(game,"refinery",distillery)
	check(stats.contains("Produces: 1 per 10s") and not stats.contains("Cargo:"), "Distillery displays production instead of cargo")
	check(game.BUILDINGS.healer.cost == {"iron":15,"pink":8}, "Heal Beacon costs eight Pink Stuff and fifteen scales")
	for kind in ["runner","gazelle","horse"]:
		var enemy: Dictionary = game.create_enemy(kind,Vector2(800,800),"red")
		game.enemies.append(enemy)
	game.queue_redraw()
	await process_frame
	print("NEW HERBIVORE CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
