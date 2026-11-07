extends "res://tests/iron_supply_zoom.gd"
func run() -> void:
	fresh()
	var position: Vector2 = game.cell_center(Vector2i(20, 25))
	for i in 4: game.enemies.append(game.create_enemy("scout", position, "red"))
	game.update_enemy_visual_offsets(0.05)
	var first: Vector2 = game.enemy_visual_position(game.enemies[0])
	check(first.distance_to(position) > 0 and first.distance_to(position) < 16, "Stack spread eases through an intermediate offset")
	game.update_enemy_visual_offsets(2)
	var radius_ok := true
	var spacing_ok := true
	for i in 4:
		var point: Vector2 = game.enemy_visual_position(game.enemies[i])
		var next: Vector2 = game.enemy_visual_position(game.enemies[(i + 1) % 4])
		radius_ok = radius_ok and is_equal_approx(point.distance_to(position), 16)
		spacing_ok = spacing_ok and is_equal_approx(point.distance_to(next), sqrt(512))
	check(radius_ok and spacing_ok, "Four stacked enemies have equal angular spacing on a sixteen-pixel circle")
	check(game.enemies.all(func(enemy): return enemy.pos == position), "Visual spreading never changes gameplay positions")
	game.enemies[0].pos += Vector2(32, 0)
	game.update_enemy_visual_offsets(0.05)
	check(game.enemy_visual_offsets[game.enemies[0].info_id].length() > 0, "An enemy leaving a stack eases back toward its true position")
	game.update_enemy_visual_offsets(2)
	check(game.enemy_visual_offsets[game.enemies[0].info_id].length() < 0.01, "A solitary enemy returns to zero offset")
	var removed: int = game.enemies[3].info_id
	game.enemies.remove_at(3)
	game.update_enemy_visual_offsets(0.1)
	check(not game.enemy_visual_offsets.has(removed), "Removed enemies leave no stale visual offsets")
	game.enemy_visual_offsets.clear()
	for enemy in game.enemies:
		enemy.pos = position
		enemy.velocity = Vector2(32, 0)
	game.update_enemy_visual_offsets(1)
	check(game.enemies.all(func(enemy): return game.enemy_visual_position(enemy) == enemy.pos), "Moving enemies passing through a shared tile are not spread")
	game.enemies[0].velocity = Vector2.ZERO
	game.update_enemy_visual_offsets(1)
	check(game.enemy_visual_position(game.enemies[0]) == position, "One stationary enemy sharing a tile with moving enemies is not spread")
	game.enemies[1].velocity = Vector2.ZERO
	game.update_enemy_visual_offsets(2)
	check(is_equal_approx(game.enemy_visual_position(game.enemies[0]).distance_to(position), 16) and game.enemy_visual_position(game.enemies[2]) == position, "Only the stationary pair spreads while the passing enemy stays centered")
	print("STACKED ENEMY VISUAL CHECKS: %d passed, %d failed" % [passed, failed])
	game.free()
	quit(1 if failed else 0)
