extends Node

enum Kind {
	SOLDIER_SQUAD,
	JEEP,
	IFV,
	REPAIR_TRUCK,
	TANK,
	ARTILLERY,
	MLRS,
	HELICOPTER,
}

const STARTING_CREDITS := 1000
const BASE_INCOME := 6.0
const REGION_INCOME := 4.0
const MAX_ARMY := 28
const HOLD_WIN_SECONDS := 4.0

var defs: Dictionary = {}


func _ready() -> void:
	defs = {
		Kind.SOLDIER_SQUAD: {
			"name": "Soldier Squad",
			"short": "Squad",
			"cost": 100,
			"value": 100,
			"hp": 80.0,
			"speed": 4.4,
			"range": 18.0,
			"min_range": 0.0,
			"damage": 9.0,
			"fire_interval": 0.55,
			"armor": 0.0,
			"splash": 0.0,
			"wall_damage": 0.0,
			"building_damage": 4.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": true,
			"projectile_speed": 0.0,
			"extent": Vector3(2.4, 1.8, 2.4),
			"blurb": "Slow infantry. Can seize buildings.",
		},
		Kind.JEEP: {
			"name": "Jeep",
			"short": "Jeep",
			"cost": 150,
			"value": 150,
			"hp": 90.0,
			"speed": 13.5,
			"range": 20.0,
			"min_range": 0.0,
			"damage": 11.0,
			"fire_interval": 0.42,
			"armor": 1.0,
			"splash": 0.0,
			"wall_damage": 2.0,
			"building_damage": 6.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 0.0,
			"extent": Vector3(2.2, 1.6, 3.4),
			"blurb": "Fast scout. Can crush infantry.",
		},
		Kind.IFV: {
			"name": "IFV",
			"short": "IFV",
			"cost": 250,
			"value": 250,
			"hp": 180.0,
			"speed": 8.8,
			"range": 24.0,
			"min_range": 0.0,
			"damage": 16.0,
			"fire_interval": 0.5,
			"armor": 3.0,
			"splash": 0.0,
			"wall_damage": 10.0,
			"building_damage": 12.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 0.0,
			"extent": Vector3(2.6, 2.1, 4.6),
			"blurb": "All-rounder. Can crush infantry.",
		},
		Kind.REPAIR_TRUCK: {
			"name": "Repair Truck",
			"short": "Repair",
			"cost": 220,
			"value": 220,
			"hp": 130.0,
			"speed": 9.6,
			"range": 16.0,
			"min_range": 0.0,
			"damage": 7.0,
			"fire_interval": 0.7,
			"armor": 2.0,
			"splash": 0.0,
			"wall_damage": 0.0,
			"building_damage": 3.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 0.0,
			"repair_rate": 24.0,
			"repair_range": 14.0,
			"extent": Vector3(2.5, 2.2, 4.4),
			"blurb": "Repairs nearby friendly vehicles. Light MG.",
		},
		Kind.TANK: {
			"name": "Tank",
			"short": "Tank",
			"cost": 400,
			"value": 400,
			"hp": 340.0,
			"speed": 5.0,
			"range": 28.0,
			"min_range": 0.0,
			"damage": 42.0,
			"fire_interval": 1.35,
			"armor": 6.5,
			"splash": 3.5,
			"wall_damage": 28.0,
			"building_damage": 32.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 55.0,
			"extent": Vector3(3.4, 2.4, 5.4),
			"blurb": "Heavy armor. Crushes infantry, punches walls.",
		},
		Kind.ARTILLERY: {
			"name": "Artillery",
			"short": "Arty",
			"cost": 350,
			"value": 350,
			"hp": 120.0,
			"speed": 3.2,
			"range": 58.0,
			"min_range": 14.0,
			"damage": 55.0,
			"fire_interval": 2.6,
			"armor": 2.0,
			"splash": 8.0,
			"wall_damage": 40.0,
			"building_damage": 48.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 28.0,
			"extent": Vector3(3.0, 2.2, 5.0),
			"blurb": "Slowest unit. Arcing howitzer shells.",
		},
		Kind.MLRS: {
			"name": "MLRS",
			"short": "MLRS",
			"cost": 500,
			"value": 500,
			"hp": 140.0,
			"speed": 6.4,
			"range": 70.0,
			"min_range": 16.0,
			"damage": 68.0,
			"fire_interval": 5.6,
			"armor": 2.0,
			"splash": 12.0,
			"wall_damage": 48.0,
			"building_damage": 58.0,
			"air": false,
			"fly_height": 0.0,
			"can_garrison": false,
			"projectile_speed": 34.0,
			"rocket": true,
			"extent": Vector3(3.1, 2.4, 5.2),
			"blurb": "Slow rocket salvo. Heavy splash and wall damage.",
		},
		Kind.HELICOPTER: {
			"name": "Helicopter",
			"short": "Heli",
			"cost": 450,
			"value": 450,
			"hp": 160.0,
			"speed": 16.0,
			"range": 30.0,
			"min_range": 0.0,
			"damage": 62.0,
			"fire_interval": 2.5,
			"armor": 2.0,
			"splash": 7.0,
			"wall_damage": 22.0,
			"building_damage": 32.0,
			"air": true,
			"fly_height": 12.0,
			"can_garrison": false,
			"projectile_speed": 46.0,
			"rocket": true,
			"extent": Vector3(3.2, 2.0, 4.8),
			"blurb": "Fast air unit. Fires explosive rockets.",
		},
	}


func data(kind: int) -> Dictionary:
	return defs[kind]


func display_name(kind: int) -> String:
	return String(defs[kind]["name"])


func cost(kind: int) -> int:
	return int(defs[kind]["cost"])


func value(kind: int) -> int:
	return int(defs[kind]["value"])


func all_kinds() -> Array[int]:
	var out: Array[int] = []
	for k in defs.keys():
		out.append(int(k))
	out.sort()
	return out
