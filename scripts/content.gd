extends RefCounted
const SCRAP_PER_CREDIT := 3
const STARTER_TANK_CREDITS := 1
const BARRIER_UNLOCK_SCRAP := 3
const RESOURCES := ["copper", "iron", "verdite", "pink"]
const BOOSTERS := {"pink": 2.0}
const REMOVED_NUCLEAR_KINDS := ["core_lifeboat", "scrap_reclaimer", "magnetic_funnel", "coolant_pump", "phase_barrier"]
const REMOVED_BUILDINGS := REMOVED_NUCLEAR_KINDS + ["forge", "alloy_store", "repeater", "cannon"]
const NUCLEAR_KINDS := ["reactor", "isotope_lance", "decay_mortar", "emergency_injector", "breach_beacon", "chrono_capacitor", "containment_engine"]
const BUILDINGS := {
 "reactor": {"name":"Reactor", "category":"Support", "size":3, "hp":500, "tech":"reactor", "cost":{"iron":50,"verdite":12}, "square":11, "inputs":{"verdite":20}},
 "isotope_lance": {"name":"Isotope Lance", "category":"Defense", "size":2, "hp":250, "tech":"isotope_lance", "cost":{"iron":40,"verdite":15}, "range":288.0,"damage":35.0,"reload":3.0,"ammo_free":true,"ammo":"verdite", "inputs":{"verdite":10}, "nuclear_turret":true},
 "decay_mortar": {"name":"Decay Mortar", "category":"Defense", "size":3, "hp":220, "tech":"decay_mortar", "cost":{"iron":55,"verdite":18}, "range":384.0,"minimum_range":96.0,"damage":15.0,"reload":6.0,"ammo_free":true,"ammo":"verdite", "inputs":{"verdite":10}, "nuclear_turret":true},
 "emergency_injector": {"name":"Emergency Injector", "category":"Support", "size":1, "hp":120, "tech":"emergency_injector", "cost":{"copper":25,"verdite":6}, "square":5, "charge_cost":5, "inputs":{"verdite":10}},
 "breach_beacon": {"name":"Breach Beacon", "category":"Defense", "size":2, "hp":600, "tech":"breach_beacon", "cost":{"iron":35,"verdite":8}, "range":256.0,"damage":1.0,"reload":1.0,"ammo_free":true,"ammo":"verdite", "inputs":{"verdite":10}, "nuclear_turret":true},
 "chrono_capacitor": {"name":"Chrono Capacitor", "category":"Support", "size":2, "hp":180, "tech":"chrono_capacitor", "cost":{"iron":50,"verdite":18}, "square":9, "charge_cost":2, "inputs":{"verdite":6}},
 "containment_engine": {"name":"Containment Engine", "category":"Defense", "size":3, "hp":400, "tech":"containment_engine", "cost":{"iron":90,"verdite":35}, "range":320.0,"damage":120.0,"reload":15.0,"ammo_free":true,"ammo":"verdite", "charge_cost":3, "inputs":{"verdite":9}, "nuclear_turret":true},
 "teleporter": {"name":"Teleporter", "category":"Logistics", "cost":{"iron":5,"copper":30}, "hp":120, "size":1, "tech":"teleporters"},
 "belt": {"name": "Belt", "category": "Logistics", "cost": {"copper": 1}, "hp": 65, "size": 1, "tech": ""},
 "splitter": {"name": "Splitter", "category": "Logistics", "cost": {"copper": 5}, "hp": 120, "size": 1, "tech": "splitter"},
 "drill": {"name": "Extractor", "category": "Extraction", "cost": {"copper": 5}, "hp": 150, "size": 1, "tech": ""},
 "solar": {"name": "Solar turret", "category": "Defense", "cost": {"copper": 10}, "hp": 30, "size": 1, "tech": "", "ammo": "", "ammo_free": true, "damage": 1.0, "range": 96.0, "reload": 2.0},
 "turret": {"name": "Iron Slugger", "category": "Defense", "cost": {"copper": 35, "iron": 12}, "hp": 150, "size": 2, "tech": "weapons", "ammo": "iron", "damage": 20.0, "range": 256.0, "reload": 4.0},
 "wall": {"name": "Barrier", "category": "Defense", "cost": {"copper": 3}, "hp": 40, "size": 1, "tech": "barriers"},
 "wall_iron": {"name": "Fish scale barrier", "category": "Defense", "cost": {"iron": 4}, "hp": 120, "size": 1, "tech": "iron_barriers"},
 "refinery": {"name": "Distillery", "category": "Production", "cost": {"copper": 35, "iron": 20}, "hp": 350, "size": 2, "tech": "refining"},
 "healer": {"name": "Heal Beacon", "category": "Support", "cost": {"iron": 15, "pink": 8}, "hp": 260, "size": 1, "tech": "healer"},
 "copper_store": {"name": "Copper silo", "category": "Storage", "cost": {"pink": 6, "copper": 100}, "hp": 320, "size": 2, "tech": "copper_storage", "stores": "copper"},
 "iron_store": {"name": "Iron silo", "category": "Storage", "cost": {"iron": 40}, "hp": 320, "size": 2, "tech": "iron_storage", "stores": "iron"},
 "verdite_store": {"name": "Plutonium silo", "category": "Storage", "cost": {"copper": 40, "iron": 30}, "hp": 320, "size": 1, "tech": "plutonium_storage", "stores": "verdite"},
}
const TECH := {
 "turret_color": {"name":"Turret Color", "parent":"healer", "core":4, "cost":{"iron":20,"verdite":10}, "icon":"turret_color", "pos":Vector2.ZERO, "description":"Unlocks all three colors for every turret."},
 "plutonium_storage": {"name":"Plutonium Silos", "parent":"turret_color", "core":4, "cost":{"iron":30,"verdite":10}, "icon":"verdite_store", "pos":Vector2.ZERO, "description":"Unlocks silos that store 500 additional plutonium."},
 "reactor": {"name":"Reactor", "parent":"turret_color", "core":4, "cost":{"iron":80,"verdite":20}, "icon":"reactor", "pos":Vector2.ZERO, "description":"Boosts nearby production by 50% using one plutonium every three seconds."},
 "isotope_lance": {"name":"Isotope Lance", "parent":"reactor", "core":4, "cost":{"iron":70,"verdite":20}, "icon":"isotope_lance", "pos":Vector2.ZERO, "description":"Fires a piercing beam with ten shots per plutonium."},
 "decay_mortar": {"name":"Decay Mortar", "parent":"isotope_lance", "core":4, "cost":{"copper":90,"verdite":25}, "icon":"decay_mortar", "pos":Vector2.ZERO, "description":"Long-range shells leave radioactive ground for six seconds."},
 "emergency_injector": {"name":"Emergency Injector", "parent":"reactor", "core":4, "cost":{"iron":45,"verdite":12}, "icon":"emergency_injector", "pos":Vector2.ZERO, "description":"Spends five plutonium to shield and boost a badly damaged turret."},
 "breach_beacon": {"name":"Breach Beacon", "parent":"reactor", "core":4, "cost":{"copper":70,"verdite":15}, "icon":"breach_beacon", "pos":Vector2.ZERO, "description":"Fires a laser dealing one percent of maximum enemy health per second."},
 "chrono_capacitor": {"name":"Chrono Capacitor", "parent":"emergency_injector", "core":4, "cost":{"iron":90,"verdite":25}, "icon":"chrono_capacitor", "pos":Vector2.ZERO, "description":"Spends two plutonium to slow unslowed enemies after a one-second delay."},
 "containment_engine": {"name":"Containment Engine", "parent":"decay_mortar", "requires":["chrono_capacitor"], "core":4, "cost":{"iron":150,"verdite":50}, "icon":"containment_engine", "pos":Vector2.ZERO, "description":"Charges an implosion that pulls enemies together and deals 120 damage."},
 "teleporters": {"name":"Teleporters", "parent":"splitter", "core":3, "cost":{"iron":30}, "icon":"teleporter", "pos":Vector2(24,640)},
 "solar_speed": {"name": "Solar attack speed", "parent": "barriers", "cost": {"copper": 10}, "icon": "solar", "pos": Vector2(24, 175)},
 "solar_health": {"name": "Solar health", "parent": "barriers", "cost": {"copper": 30}, "icon": "solar", "pos": Vector2(708, 175)},
 "barriers": {"name": "Barriers", "parent": "", "cost": {}, "icon": "wall", "pos": Vector2(366, 20)},
 "turret_range": {"name": "Solar turret range", "parent": "barriers", "cost": {"copper": 15}, "icon": "solar", "pos": Vector2(480, 175)},
 "copper_storage": {"name": "Copper storage", "parent": "refining", "core": 3, "cost": {"copper": 80}, "icon": "copper_store", "pos": Vector2(252, 330)},
 "splitter": {"name": "Conveyor splitter", "parent": "turret_range", "core": 2, "cost": {"copper": 35}, "icon": "splitter", "pos": Vector2(24, 485)},
 "time_speed": {"name": "Time acceleration", "parent": "barriers", "cost": {"copper": 20}, "icon": "speed3", "pos": Vector2(252, 485)},
 "weapons": {"name": "Iron Slugger", "parent": "turret_range", "core": 2, "cost": {"iron": 5}, "icon": "turret", "pos": Vector2(252, 175)},
 "refining": {"name": "Distillery", "parent": "weapons", "core": 3, "cost": {"iron": 35}, "icon": "refinery", "pos": Vector2(732, 640)},
 "iron_storage": {"name": "Iron silo", "parent": "refining", "core": 3, "cost": {"iron": 20}, "icon": "iron_store", "pos": Vector2(732, 795)},
 "slugger_shield": {"name": "Slugger shield", "parent": "weapons", "cost": {"iron": 20}, "icon": "turret", "pos": Vector2(492, 640)},
 "iron_barriers": {"name": "Iron barriers", "parent": "weapons", "cost": {"iron": 35}, "icon": "wall_iron", "pos": Vector2(252, 640)},
 "healer": {"name": "Heal Beacon", "parent": "refining", "core": 3, "cost": {"iron": 55}, "icon": "healer", "pos": Vector2(480, 340)},
}
const TECH_DESCRIPTIONS := {
 "teleporters": "Links two nodes to teleport resources between them.",
 "solar_speed": "Makes solar turrets fire twice as fast.",
 "solar_health": "Gives solar turrets ten more health.",
 "barriers": "Unlocks barriers to shield your buildings.",
 "turret_range": "Lets solar turrets reach two tiles farther.",
 "copper_storage": "+50 chicken nuggets capacity per silo when powered",
 "splitter": "Splits incomming resources onto outgoing belts.",
 "time_speed": "Lets E switch the game to five times normal speed.",
 "weapons": "Unlocks a turret that fires heavy slugs.",
 "refining": "Turns Chicken Nuggets and Fish Scales into Pink Stuff.",
 "iron_storage": "+40 fish scales capacity per silo when powered",
 "slugger_shield": "Shields sluggers against one hit each wave.",
 "iron_barriers": "Unlocks fish scale barriers with three times the health of nugget barriers.",
 "healer": "Unlocks a beacon that heals nearby buildings.",
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












