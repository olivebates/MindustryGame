extends RefCounted
const DESCRIPTIONS := {
	"core": "Defend at all costs.",
	"belt": "Moves one material at a time toward its next destination.",
	"drill": "Extracts ore and shares it equally among adjacent outgoing belts.",
	"splitter": "Shares incoming materials equally among its outgoing belts.",
	"solar": "Fires low-damage shots without needing ammunition.",
	"turret": "Uses iron ammunition to fire heavy slugs at nearby enemies.",
	"repeater": "Uses copper ammunition to fire rapid shots at nearby enemies.",
	"cannon": "Uses iron ammunition to fire powerful long-range shots.",
	"wall": "Absorbs enemy damage to protect the buildings behind it.",
	"forge": "Combines copper and iron into repair alloy.",
	"healer": "Consumes verdite and repair alloy to heal nearby buildings."
}
static func description(game: Node2D, kind: String) -> String:
	if DESCRIPTIONS.has(kind): return DESCRIPTIONS[kind]
	return "Increases your maximum %s storage." % game.BUILDINGS[kind].stores
static func stats(game: Node2D, kind: String, building: Dictionary = {}) -> String:
	var data: Dictionary = {} if kind == "core" else game.BUILDINGS[kind]
	var health: float = (2000.0 if kind == "core" else float(data.hp)) * (1.25 if game.researched.has("armor") else 1.0)
	if kind == "wall" and game.researched.has("iron_barriers"): health *= 3.0
	var lines: Array[String] = []
	lines.append("Health: %s / %s" % [number(building.hp), number(building.max_hp)] if not building.is_empty() else "Health: %s" % number(health))
	if game.is_turret(kind):
		if kind == "turret" and game.researched.has("slugger_shield"):
			lines.append("Shield: " + ("Ready (blocks one hit)" if building.is_empty() or building.get("shield", false) else "Spent"))
		var damage: float = data.damage * (1.25 if game.researched.has("damage") else 1.0)
		lines.append("Damage: %s   Shot interval: %ss" % [number(damage), number(data.reload)])
		lines.append("DPS: " + number(damage / data.reload))
		lines.append("Range: %s tiles" % number(game.turret_range(kind) / game.TILE))
		if not data.get("ammo_free", false):
			var capacity: int = game.turret_ammo_capacity(kind)
			lines.append("Ammo: %s%s" % [data.ammo.capitalize(), "  %s / %s" % [number(building.ammo), number(capacity)] if not building.is_empty() else "  (%s capacity)" % number(capacity)])
	elif kind == "drill": lines.append("Extraction: %s / second" % number((1.3 if game.researched.has("mining") else 1.0) / 5.0))
	elif kind in ["belt", "splitter"]: lines.append("Transport: %s items / second" % number(game.conveyor_items_per_second(kind) / game.FLOW_INTERVAL))
	elif kind == "forge":
		lines.append("Recipe: 2 copper + 2 iron -> 1 repair alloy")
		lines.append("Cycle: 3s   Footprint: 2 x 2")
	elif kind == "healer":
		lines.append("Healing: 1% maximum health / second")
		lines.append("Radius: 2 tiles   Fuel: 1 verdite + 1 alloy / second")
	elif data.has("stores"): lines.append("Extra capacity: %s %s" % [number(50 if data.stores == "copper" else 500), data.stores])
	if not building.is_empty():
		if kind == "forge": lines.append("Inputs: %s copper / %s iron" % [number(building.buffer.copper), number(building.buffer.iron)])
		if kind == "healer": lines.append("Fuel: %s verdite / %s alloy" % [number(building.buffer.verdite), number(building.buffer.alloy)])
		if building.item != "": lines.append("Cargo: " + building.item.capitalize())
		if building.tunnel_role != "": lines.append("Tunnel: " + building.tunnel_role.capitalize())
	return "\n".join(lines)

static func number(value: float) -> String:
	return preload("res://scripts/display_numbers.gd").format(value)
static func enemy_stats(game: Node2D, enemy: Dictionary) -> String:
	var data: Dictionary = game.Content.ENEMY_TYPES[enemy.kind]
	return "Health: %s / %s\nDamage: %s   Shot interval: %ss\nDPS: %s\nRange: %s tiles\nSpeed: %s tiles / second\nScrap: %s" % [number(enemy.hp), number(enemy.max_hp), number(data.damage), number(data.reload), number(data.damage / data.reload), number(data.reach / game.TILE), number(enemy.speed / game.TILE), number(game.Content.enemy_scrap(enemy.kind))]






