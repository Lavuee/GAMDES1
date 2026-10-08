class_name WeaponCatalog
extends RefCounted
## Static weapon table for ABANTE. Every weapon has the same number of uses;
## weapon strength only changes how many hits an enemy needs.

const UNARMED := ""
const DEFAULT_WEAPON := "default"

## Enemies all share this health pool. 60 divides evenly by 5, 4, 3 and 2,
## so damage per hit is always a whole number (60 / hits_required).
const ENEMY_MAX_HEALTH := 60

const WEAPONS := {
	"default": {
		"name": "DEFAULT SWORD",
		"cost": 0,
		"uses": 7,
		"hits": 5,
		"purchasable": false,
		"icon": "res://assets/sprites/abante/weapon_default.png",
	},
	"weapon_1": {
		"name": "WEAPON 1",
		"cost": 5,
		"uses": 7,
		"hits": 4,
		"purchasable": true,
		"icon": "res://assets/sprites/abante/weapon_1.png",
	},
	"weapon_2": {
		"name": "WEAPON 2",
		"cost": 10,
		"uses": 7,
		"hits": 3,
		"purchasable": true,
		"icon": "res://assets/sprites/abante/weapon_2.png",
	},
	"weapon_best": {
		"name": "BEST WEAPON",
		"cost": 15,
		"uses": 7,
		"hits": 2,
		"purchasable": true,
		"icon": "res://assets/sprites/abante/weapon_best.png",
	},
}

## Display order in the shop.
const ORDER := ["default", "weapon_1", "weapon_2", "weapon_best"]


static func has_weapon(weapon_id: String) -> bool:
	return WEAPONS.has(weapon_id)


static func get_info(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, {})


static func get_display_name(weapon_id: String) -> String:
	if weapon_id == UNARMED:
		return "UNARMED"
	return get_info(weapon_id).get("name", "???")


static func get_damage(weapon_id: String) -> int:
	var hits: int = get_info(weapon_id).get("hits", 0)
	if hits <= 0:
		return 0
	return ENEMY_MAX_HEALTH / hits


static func get_icon(weapon_id: String) -> Texture2D:
	var path: String = get_info(weapon_id).get("icon", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


## Cheapest weapon the shop can sell (used for "you can afford a weapon" hints).
static func cheapest_cost() -> int:
	var best := -1
	for id in ORDER:
		var info: Dictionary = WEAPONS[id]
		if info.purchasable and (best < 0 or info.cost < best):
			best = info.cost
	return best
