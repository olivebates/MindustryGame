extends RefCounted
const SCRAP_PER_CREDIT := 3
const STARTER_TANK_CREDITS := 1
const BARRIER_UNLOCK_SCRAP := 3
const RESOURCES := ["copper", "iron", "verdite", "alloy", "pink"]
const BOOSTERS := {"pink": 2.0}
const BUILDINGS := {
 "teleporter": {"name":"Teleporter", "category":"Logistics", "cost":{"iron":5,"copper":30}, "hp":120, "size":1, "tech":"teleporters"},
 "belt": {"name": "Belt", "category": "Logistics", "cost": {"copper": 1}, "hp": 65, "size": 1, "tech": ""},
 "splitter": {"name": "Splitter", "category": "Logistics", "cost": {"copper": 5}, "hp": 120, "size": 1, "tech": "splitter"},
 "drill": {"name": "Extractor", "category": "Extraction", "cost": {"copper": 5}, "hp": 150, "size": 1, "tech": ""},
 "solar": {"name": "Solar turret", "category": "Defense", "cost": {"copper": 10}, "hp": 30, "size": 1, "tech": "", "ammo": "", "ammo_free": true, "damage": 1.0, "range": 96.0, "reload": 2.0},
 "turret": {"name": "Iron Slugger", "category": "Defense", "cost": {"copper": 35, "iron": 12}, "hp": 150, "size": 2, "tech": "weapons", "ammo": "iron", "damage": 20.0, "range": 256.0, "reload": 4.0},
 "repeater": {"name": "Copper repeater", "category": "Defense", "cost": {"copper": 65, "iron": 25}, "hp": 200, "size": 1, "tech": "repeater", "ammo": "copper", "damage": 12.0, "range": 224.0, "reload": 0.02},
 "cannon": {"name": "Iron cannon", "category": "Defense", "cost": {"copper": 50, "iron": 65}, "hp": 380, "size": 1, "tech": "cannon", "ammo": "iron", "damage": 100.0, "range": 320.0, "reload": 0.27},
 "wall": {"name": "Barrier", "category": "Defense", "cost": {"copper": 3}, "hp": 40, "size": 1, "tech": "barriers"},
 "wall_iron": {"name": "Fish scale barrier", "category": "Defense", "cost": {"iron": 4}, "hp": 120, "size": 1, "tech": "iron_barriers"},
 "refinery": {"name": "Distillery", "category": "Production", "cost": {"copper": 35, "iron": 20}, "hp": 350, "size": 2, "tech": "refining"},
 "forge": {"name": "Repair-alloy forge", "category": "Production", "cost": {"copper": 80, "iron": 50}, "hp": 500, "size": 2, "tech": "forge"},
 "healer": {"name": "Heal Beacon", "category": "Support", "cost": {"iron": 15, "pink": 8}, "hp": 260, "size": 1, "tech": "healer"},
 "copper_store": {"name": "Copper silo", "category": "Storage", "cost": {"pink": 6, "copper": 100}, "hp": 320, "size": 2, "tech": "copper_storage", "stores": "copper"},
 "iron_store": {"name": "Iron silo", "category": "Storage", "cost": {"iron": 40}, "hp": 320, "size": 2, "tech": "iron_storage", "stores": "iron"},
 "verdite_store": {"name": "Verdite silo", "category": "Storage", "cost": {"copper": 40, "iron": 30}, "hp": 320, "size": 1, "tech": "industry", "stores": "verdite"},
 "alloy_store": {"name": "Alloy silo", "category": "Storage", "cost": {"copper": 60, "iron": 50, "alloy": 10}, "hp": 380, "size": 1, "tech": "industry", "stores": "alloy"},
}
const TECH := {
 "teleporters": {"name":"Teleporters", "parent":"splitter", "core":3, "cost":{"iron":30}, "icon":"teleporter", "pos":Vector2(24,640)},
 "solar_speed": {"name": "Solar attack speed", "parent": "barriers", "cost": {"copper": 10}, "icon": "solar", "pos": Vector2(24, 175)},
 "solar_health": {"name": "Solar health", "parent": "barriers", "cost": {"copper": 30}, "icon": "solar", "pos": Vector2(708, 175)},
 "barriers": {"name": "Barriers", "parent": "", "cost": {}, "icon": "wall", "pos": Vector2(366, 20)},
 "conveyor_speed": {"name": "Conveyor speed", "parent": "barriers", "cost": {"copper": 25}, "icon": "belt", "pos": Vector2(252, 175)},
 "turret_range": {"name": "Solar turret range", "parent": "barriers", "cost": {"copper": 15}, "icon": "solar", "pos": Vector2(480, 175)},
 "copper_storage": {"name": "Copper storage", "parent": "refining", "core": 3, "cost": {"copper": 80}, "icon": "copper_store", "pos": Vector2(252, 330)},
 "build_hotkeys": {"name": "Build Menu Hotkeys", "parent": "turret_range", "cost": {"copper": 10}, "icon": "drill", "pos": Vector2(708, 330)},
 "industry": {"name": "Industrial structures", "parent": "turret_range", "cost": {"copper": 40, "iron": 20}, "icon": "splitter", "pos": Vector2(24, 175)},
 "splitter": {"name": "Conveyor splitter", "parent": "turret_range", "core": 2, "cost": {"copper": 35}, "icon": "splitter", "pos": Vector2(24, 485)},
 "time_speed": {"name": "Time acceleration", "parent": "barriers", "cost": {"copper": 20}, "icon": "speed3", "pos": Vector2(252, 485)},
 "weapons": {"name": "Iron Slugger", "parent": "turret_range", "core": 2, "cost": {"iron": 5}, "icon": "turret", "pos": Vector2(252, 175)},
 "refining": {"name": "Distillery", "parent": "weapons", "core": 3, "cost": {"iron": 35}, "icon": "refinery", "pos": Vector2(732, 640)},
 "iron_storage": {"name": "Iron silo", "parent": "refining", "core": 3, "cost": {"iron": 20}, "icon": "iron_store", "pos": Vector2(732, 795)},
 "slugger_shield": {"name": "Slugger shield", "parent": "weapons", "cost": {"iron": 20}, "icon": "turret", "pos": Vector2(492, 640)},
 "iron_barriers": {"name": "Iron barriers", "parent": "weapons", "cost": {"iron": 35}, "icon": "wall_iron", "pos": Vector2(252, 640)},
 "forge": {"name": "Alloy fabrication", "parent": "turret_range", "cost": {"copper": 60, "iron": 40}, "icon": "forge", "pos": Vector2(480, 175)},
 "armor": {"name": "Reinforced structures", "parent": "turret_range", "cost": {"copper": 100, "iron": 80}, "icon": "wall", "pos": Vector2(708, 175)},
 "repeater": {"name": "Rapid ballistics", "parent": "weapons", "cost": {"copper": 60, "iron": 20}, "icon": "repeater", "pos": Vector2(252, 340)},
 "healer": {"name": "Heal Beacon", "parent": "refining", "core": 3, "cost": {"iron": 55}, "icon": "healer", "pos": Vector2(480, 340)},
 "mining": {"name": "Precision extraction", "parent": "forge", "cost": {"copper": 100, "iron": 60}, "icon": "drill", "pos": Vector2(708, 340)},
 "cannon": {"name": "Heavy ballistics", "parent": "repeater", "cost": {"copper": 80, "iron": 60}, "icon": "cannon", "pos": Vector2(252, 505)},
 "damage": {"name": "Hardened rounds", "parent": "cannon", "cost": {"copper": 120, "iron": 100, "alloy": 10}, "icon": "turret", "pos": Vector2(252, 670)}
}
const TECH_DESCRIPTIONS := {
 "teleporters": "Links two nodes to teleport resources between them.",
 "solar_speed": "Makes solar turrets fire twice as fast.",
 "solar_health": "Gives solar turrets ten more health.",
 "barriers": "Unlocks barriers to shield your buildings.",
 "conveyor_speed": "Doubles the transport speed of conveyors.",
 "turret_range": "Lets solar turrets reach two tiles farther.",
 "copper_storage": "+50 chicken nuggets capacity per silo when powered",
 "build_hotkeys": "Lets number keys select buildings and menus.",
 "industry": "Unlocks storage for additional materials.",
 "splitter": "Splits incomming resources onto outgoing belts.",
 "time_speed": "Lets E switch the game to five times normal speed.",
 "weapons": "Unlocks a turret that fires heavy slugs.",
 "refining": "Turns Chicken Nuggets and Fish Scales into Pink Stuff.",
 "iron_storage": "+40 fish scales capacity per silo when powered",
 "slugger_shield": "Shields sluggers against one hit each wave.",
 "iron_barriers": "Unlocks fish scale barriers with three times the health of nugget barriers.",
 "forge": "Unlocks a forge that produces repair alloy.",
 "armor": "Increases the health of your structures.",
 "repeater": "Unlocks a turret that fires rapid shots.",
 "healer": "Unlocks a beacon that heals nearby buildings.",
 "mining": "Improves extractor production speed.",
 "cannon": "Unlocks a cannon for powerful long-range shots.",
 "damage": "Makes turret shots deal more damage."
}
const ENEMY_TYPES := {
 "scout": {"credits": STARTER_TANK_CREDITS, "name": "Squirrel", "hp": 5.0, "speed": 128, "reach": 64.0, "damage": 1.0, "reload": 1.0, "unlock": 1, "size": 27.0},
 "heavy": {"credits": 8, "name": "Tapir", "hp": 20.0, "speed": 96.0, "reach": 96.0, "damage": 4.0, "reload": 2.0, "unlock": 3, "size": 36.0},
 "runner": {"credits": 5, "name": "Bunny", "hp": 20.0, "speed": 160, "reach": 32.0, "damage": 1.0, "reload": 1.0, "unlock": 2, "size": 27.0},
 "gazelle": {"credits": 25, "name": "Gazelle", "hp": 100.0, "speed": 192, "reach": 32.0, "damage": 1.0, "reload": 1.0, "unlock": 3, "size": 32.0},
 "horse": {"credits": 125, "name": "Horse", "hp": 500.0, "speed": 160, "reach": 32.0, "damage": 1.0, "reload": 1.0, "unlock": 4, "size": 42.0},
 "skirmisher": {"credits": 5, "name": "Deer", "hp": 70.0, "speed": 260, "reach": 128.0, "damage": 10.0, "reload": 0.08, "unlock": 3, "size": 29.0},
 "bulwark": {"credits": 40, "name": "Bison", "hp": 50.0, "speed": 64.0, "reach": 64.0, "damage": 12.0, "reload": 3.0, "unlock": 4, "size": 41.0},
 "siege": {"credits": 240, "name": "Elephant", "hp": 210.0, "speed": 32.0, "reach": 96.0, "damage": 40.0, "reload": 7.0, "unlock": 5, "size": 56.0},
 "mender": {"credits": 10, "name": "Tortoise", "hp": 100.0, "speed": 180, "reach": 128.0, "damage": 7.0, "reload": 0.3, "unlock": 6, "size": 30.0}
}
static func enemy_scrap(kind: String) -> int:
	return int(ENEMY_TYPES[kind].get("scrap", ENEMY_TYPES[kind].credits * SCRAP_PER_CREDIT))












