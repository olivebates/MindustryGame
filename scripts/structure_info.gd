extends RefCounted
const DESCRIPTIONS := {
	"teleporter": "Teleports incoming resources to its paired node and distributes them to nearby buildings.",
	"core": "Defend at all costs.",
	"belt": "Moves one material at a time toward its next destination.",
	"drill": "Extracts ore and shares it equally among adjacent outgoing belts.",
	"splitter": "Splits incomming resources onto outgoing belts.",
	"solar": "Fires low-damage shots without needing ammunition.",
	"turret": "Uses iron ammunition to fire heavy slugs at nearby enemies.",
	"repeater": "Uses copper ammunition to fire rapid shots at nearby enemies.",
	"cannon": "Uses iron ammunition to fire powerful long-range shots.",
	"wall_iron": "A fish scale barrier with three times the health of a nugget barrier.",
	"wall": "Absorbs enemy damage to protect the buildings behind it.",
	"refinery": "Turns Chicken Nuggets and Fish Scales into Pink Stuff.",
	"iron_store": "Increases your fish scales storage.",
	"forge": "Combines copper and iron into repair alloy.",
	"healer": "Uses Pink Stuff to heal nearby buildings."
}
static func description(game: Node2D, kind: String) -> String:
	if DESCRIPTIONS.has(kind): return DESCRIPTIONS[kind]
	return "Increases your maximum %s storage." % game.BUILDINGS[kind].stores
static func stats(game: Node2D, kind: String, building: Dictionary = {}) -> String:
	var data: Dictionary = {} if kind == "core" else game.BUILDINGS[kind]
	var health: float = (200.0 if kind == "core" else float(data.hp)) * (1.25 if game.researched.has("armor") else 1.0)
	if kind == "solar" and game.researched.has("solar_health"): health += 10.0
	var lines: Array[String] = []
	lines.append("Health: %s / %s" % [number(building.hp), number(building.max_hp)] if not building.is_empty() else "Health: %s" % number(health))
	if game.is_turret(kind):
		if kind == "turret" and game.researched.has("slugger_shield"):
			lines.append("Shield: " + ("Ready (blocks one hit)" if building.is_empty() or building.get("shield", false) else "Spent"))
		var damage: float = data.damage * (1.25 if game.researched.has("damage") else 1.0)
		var boost: float = preload("res://scripts/pink_production.gd").speed_multiplier(building)
		var reload_time: float = game.turret_reload(kind)
		var interval := number(reload_time) + "s"
		var dps := number(damage / reload_time)
		if boost > 1:
			interval = boosted_value(interval, number(reload_time / boost) + "s")
			dps = boosted_value(dps, number(damage / reload_time * boost))
		lines.append("Damage: %s   Shot interval: %s" % [number(damage), interval])
		lines.append("DPS: " + dps)


		lines.append("Range: %s tiles" % number(game.turret_range(kind) / game.TILE))
		if not data.get("ammo_free", false):
			var capacity: int = game.turret_ammo_capacity(kind)
			lines.append("Ammo: %s%s" % [data.ammo.capitalize(), "  %s / %s" % [number(building.ammo), number(capacity)] if not building.is_empty() else "  (%s capacity)" % number(capacity)])
		lines.append("[img=14x14]res://assets/items/pink.svg[/img] Booster: %s / 10" % number(building.get("booster_count", 0)))
	elif kind == "drill": lines.append("Extraction: 1 every %ss" % number(5.0 / (1.3 if game.researched.has("mining") else 1.0)))
	elif kind in ["belt", "splitter"]: lines.append("Transport: 1 item every %ss" % number(game.FLOW_INTERVAL / game.conveyor_items_per_second(kind)))
	elif kind == "forge":
		lines.append("Recipe: 2 copper + 2 iron -> 1 repair alloy")
		lines.append("Cycle: 3s   Footprint: 2 x 2")
	elif kind == "healer":
		lines.append("Range: 1 tile (square)")
		lines.append("Healing: 1 HP / second")
	elif kind == "refinery":
		lines.append("Produces: 1 per 10s")
		if not building.is_empty(): lines.append("Stored: [img=14x14]res://assets/items/copper.svg[/img] %s / [img=14x14]res://assets/items/iron.svg[/img] %s" % [number(building.buffer.copper), number(building.buffer.iron)])
	elif kind == "iron_store":
		lines.append("Extra capacity: 40 fish scales (while fueled)")
		lines.append("Pink Stuff: %s / 10   Fuel: 1 / 30s" % number(building.get("buffer", {}).get("pink", 0)))
	elif kind == "copper_store":
		lines.append("Extra capacity: 50 chicken nuggets (while fueled)")
		lines.append("Pink Stuff: %s / 10   Fuel: 1 / 30s" % number(building.get("buffer", {}).get("pink", 0)))
	elif data.has("stores"): lines.append("Extra capacity: %s %s" % [number(50 if data.stores == "copper" else 500), data.stores])
	if not building.is_empty():
		if kind == "forge": lines.append("Inputs: %s copper / %s iron" % [number(building.buffer.copper), number(building.buffer.iron)])
		if building.item != "" and kind != "refinery": lines.append("Cargo: " + building.item.capitalize())
		if building.tunnel_role != "": lines.append("Tunnel: " + building.tunnel_role.capitalize())
	return "\n".join(lines)

static func number(value: float) -> String:
	return preload("res://scripts/display_numbers.gd").format(value)
static func boosted_value(base: String, improved: String) -> String:
	return "[s][base_stat]%s[/base_stat][/s] [color=#83d780]%s[/color]" % [base, improved]
static func enemy_stats(game: Node2D, enemy: Dictionary) -> String:
	var data: Dictionary = game.Content.ENEMY_TYPES[enemy.kind]
	return "Health: %s / %s\nDamage: %s   Shot interval: %ss\nDPS: %s\nRange: %s tiles\nSpeed: %s tiles / second" % [number(enemy.hp), number(enemy.max_hp), number(data.damage), number(data.reload), number(data.damage / data.reload), number(data.reach / game.TILE), number(enemy.speed / game.TILE)]






