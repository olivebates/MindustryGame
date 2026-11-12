extends "res://tests/iron_supply_zoom.gd"
const Art = preload("res://scripts/enemy_art.gd")
func run() -> void:
	fresh()
	var rasters: Dictionary = game.sprite_rasters(64)
	for kind in game.Content.ENEMY_TYPES:
		var red: Image = rasters[kind + "_red"].get_image()
		var blue: Image = rasters[kind + "_blue"].get_image()
		var natural: Image = Art.assemble(rasters[kind + "_body"],rasters[kind + "_gun"]).get_image()
		var changed := 0
		var retained := 0
		var shades := {}
		var same_silhouette := true
		for y in 64:
			for x in 64:
				var a := red.get_pixel(x,y)
				var b := blue.get_pixel(x,y)
				var original := natural.get_pixel(x,y)
				if a.a != original.a or b.a != original.a: same_silhouette = false
				if original.a <= 0: continue
				if a != b:
					changed += 1
					shades[a.to_rgba32()] = true
				else: retained += 1
		check(changed > 150 and retained > changed * 0.4, "%s uses broad wave-colored body parts and retains natural fur or skin" % kind)
		check(shades.size() >= 3 and same_silhouette, "%s colored parts retain shaded detail and do not add floating marks" % kind)
		var head: Image = rasters[kind + "_gun_red"].get_image()
		var plain_head: Image = rasters[kind + "_gun"].get_image()
		check(head.get_pixel(43,32) == plain_head.get_pixel(43,32) and head.get_pixel(49,32) == plain_head.get_pixel(49,32), "%s no longer has a colored forehead dot" % kind)
	print("ENEMY COLORED PART CHECKS: %d passed, %d failed" % [passed,failed])
	game.free()
	quit(1 if failed else 0)
