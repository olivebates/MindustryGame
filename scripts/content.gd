extends RefCounted
const SCRAP_PER_CREDIT := 3
const STARTER_TANK_CREDITS := 1
const BARRIER_UNLOCK_SCRAP := 3
const RESOURCES := ["copper", "iron", "verdite", "alloy", "scrap"]
const BUILDINGS := {
 "belt": {"name": "Belt", "category": "Logistics", "cost": {"copper": 1}, "hp": 65, "size": 1, "tech": ""},
 "splitter": {"name": "Splitter", "category": "Logistics", "cost": {"copper": 5}, "hp": 120, "size": 1, "tech": "splitter"},
 "drill": {"name": "Extractor", "category": "Extraction", "cost": {"copper": 5}, "hp": 150, "size": 1, "tech": ""},
 "solar": {"name": "Solar turret", "category": "Defense", "cost": {"copper": 10}, "hp": 40, "size": 1, "tech": "", "ammo": "", "ammo_free": true, "damage": 1.0, "range": 96.0, "reload": 1.0},
 "turret": {"name": "Iron Slugger", "category": "Defense", "cost": {"copper": 35, "iron": 12}, "hp": 150, "size": 2, "tech": "weapons", "ammo": "iron", "damage": 20.0, "range": 256.0, "reload": 4.0},
 "repeater": {"name": "Copper repeater", "category": "Defense", "cost": {"copper": 65, "iron": 25}, "hp": 200, "size": 1, "tech": "repeater", "ammo": "copper", "damage": 12.0, "range": 224.0, "reload": 0.02},
 "cannon": {"name": "Iron cannon", "category": "Defense", "cost": {"copper": 50, "iron": 65}, "hp": 380, "size": 1, "tech": "cannon", "ammo": "iron", "damage": 100.0, "range": 320.0, "reload": 0.27},
 "wall": {"name": "Barrier", "category": "Defense", "cost": {"copper": 3}, "hp": 40, "size": 1, "tech": "barriers"},
 "forge": {"name": "Repair-alloy forge", "category": "Production", "cost": {"copper": 80, "iron": 50}, "hp": 500, "size": 2, "tech": "forge"},
 "healer": {"name": "Healing beacon", "category": "Support", "cost": {"copper": 50, "iron": 30, "alloy": 15}, "hp": 260, "size": 1, "tech": "healer"},
 "copper_store": {"name": "Copper silo", "category": "Storage", "cost": {"scrap": 10, "copper": 2}, "hp": 320, "size": 2, "tech": "copper_storage", "stores": "copper"},
 "iron_store": {"name": "Iron silo", "category": "Storage", "cost": {"copper": 25, "iron": 40, "scrap": 25}, "hp": 320, "size": 1, "tech": "industry", "stores": "iron"},
 "verdite_store": {"name": "Verdite silo", "category": "Storage", "cost": {"copper": 40, "iron": 30, "scrap": 40}, "hp": 320, "size": 1, "tech": "industry", "stores": "verdite"},
 "alloy_store": {"name": "Alloy silo", "category": "Storage", "cost": {"copper": 60, "iron": 50, "alloy": 10, "scrap": 60}, "hp": 380, "size": 1, "tech": "industry", "stores": "alloy"},
 "scrap_store": {"name": "Scrap depot", "category": "Storage", "cost": {"copper": 30, "iron": 25, "scrap": 20}, "hp": 320, "size": 1, "tech": "industry", "stores": "scrap"}
}
const TECH := {
 "barriers": {"name": "Barriers", "parent": "", "cost": {"scrap": BARRIER_UNLOCK_SCRAP}, "icon": "wall", "pos": Vector2(366, 20)},
 "conveyor_speed": {"name": "Conveyor speed", "parent": "barriers", "cost": {"scrap": 5, "copper": 25}, "icon": "belt", "pos": Vector2(252, 175)},
 "turret_range": {"name": "Solar turret range", "parent": "barriers", "cost": {"scrap": 7, "copper": 5}, "icon": "solar", "pos": Vector2(480, 175)},
 "copper_storage": {"name": "Copper storage", "parent": "turret_range", "cost": {"scrap": 7, "copper": 10}, "icon": "copper_store", "pos": Vector2(252, 330)},
 "auto_scrap": {"name": "Auto pickup scraps", "parent": "turret_range", "cost": {"copper": 10}, "icon": "scrap_item", "pos": Vector2(480, 330)},
 "build_hotkeys": {"name": "Build Menu Hotkeys", "parent": "turret_range", "cost": {"copper": 10}, "icon": "drill", "pos": Vector2(708, 330)},
 "industry": {"name": "Industrial structures", "parent": "turret_range", "cost": {"copper": 40, "iron": 20}, "icon": "splitter", "pos": Vector2(24, 175)},
 "splitter": {"name": "Conveyor splitter", "parent": "copper_storage", "cost": {"copper": 35}, "icon": "splitter", "pos": Vector2(24, 485)},
 "time_speed": {"name": "Time acceleration", "parent": "copper_storage", "cost": {"iron": 5}, "icon": "speed3", "pos": Vector2(252, 485)},
 "weapons": {"name": "Iron Slugger", "parent": "copper_storage", "cost": {"iron": 5, "scrap": 10}, "icon": "turret", "pos": Vector2(252, 175)},
 "slugger_shield": {"name": "Slugger shield", "parent": "weapons", "cost": {"iron": 20, "scrap": 10}, "icon": "turret", "pos": Vector2(492, 640)},
 "iron_barriers": {"name": "Iron barriers", "parent": "weapons", "cost": {"iron": 35, "scrap": 20}, "icon": "wall_iron", "pos": Vector2(252, 640)},
 "forge": {"name": "Alloy fabrication", "parent": "turret_range", "cost": {"copper": 60, "iron": 40}, "icon": "forge", "pos": Vector2(480, 175)},
 "armor": {"name": "Reinforced structures", "parent": "turret_range", "cost": {"copper": 100, "iron": 80}, "icon": "wall", "pos": Vector2(708, 175)},
 "repeater": {"name": "Rapid ballistics", "parent": "weapons", "cost": {"copper": 60, "iron": 20}, "icon": "repeater", "pos": Vector2(252, 340)},
 "healer": {"name": "Restoration", "parent": "forge", "cost": {"copper": 80, "iron": 40, "alloy": 5}, "icon": "healer", "pos": Vector2(480, 340)},
 "mining": {"name": "Precision extraction", "parent": "forge", "cost": {"copper": 100, "iron": 60}, "icon": "drill", "pos": Vector2(708, 340)},
 "cannon": {"name": "Heavy ballistics", "parent": "repeater", "cost": {"copper": 80, "iron": 60}, "icon": "cannon", "pos": Vector2(252, 505)},
 "damage": {"name": "Hardened rounds", "parent": "cannon", "cost": {"copper": 120, "iron": 100, "alloy": 10}, "icon": "turret", "pos": Vector2(252, 670)}
}
const ENEMY_TYPES := {
 "scout": {"credits": STARTER_TANK_CREDITS, "scrap": 1, "name": "Small tank", "hp": 5.0, "speed": 128, "reach": 64.0, "damage": 1.0, "reload": 1.0, "unlock": 1, "size": 27.0},
 "heavy": {"credits": 8, "scrap": 4, "name": "Heavy", "hp": 20.0, "speed": 96.0, "reach": 96.0, "damage": 4.0, "reload": 2.0, "unlock": 3, "size": 36.0},
 "runner": {"credits": 2, "name": "Runner", "hp": 9.0, "speed": 240, "reach": 32.0, "damage": 3.0, "reload": 0.24, "unlock": 2, "size": 24.0},
 "skirmisher": {"credits": 5, "name": "Skirmisher", "hp": 70.0, "speed": 260, "reach": 128.0, "damage": 10.0, "reload": 0.08, "unlock": 3, "size": 29.0},
 "bulwark": {"credits": 40, "scrap": 12, "name": "Bulwark", "hp": 50.0, "speed": 64.0, "reach": 64.0, "damage": 12.0, "reload": 3.0, "unlock": 4, "size": 41.0},
 "siege": {"credits": 240, "scrap": 70, "name": "Siege crawler", "hp": 140.0, "speed": 32.0, "reach": 96.0, "damage": 60.0, "reload": 7.0, "unlock": 5, "size": 56.0},
 "mender": {"credits": 10, "name": "Field mender", "hp": 100.0, "speed": 180, "reach": 128.0, "damage": 7.0, "reload": 0.3, "unlock": 6, "size": 30.0}
}
static func enemy_scrap(kind: String) -> int:
	return int(ENEMY_TYPES[kind].get("scrap", ENEMY_TYPES[kind].credits * SCRAP_PER_CREDIT))












