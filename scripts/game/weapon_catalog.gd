class_name WeaponCatalog
extends RefCounted
## Static weapon table for ABANTE. Every weapon has the same number of uses;
## weapon strength only changes how many hits an enemy needs. Each weapon has
## its own player SpriteFrames so the hero visibly holds it.

const UNARMED := ""
const DEFAULT_WEAPON := "default"

## Enemies all share this health pool. 60 divides evenly by 5, 4, 3 and 2,
## so damage per hit is always a whole number (60 / hits_required).
const ENEMY_MAX_HEALTH := 60

const WEAPONS := {
	"default": {
		"name": "DAGGER",
		"cost": 0,
		"uses": 7,
		"hits": 5,
		"purchasable": false,
		"icon_region": Rect2(1, 8, 19, 7),
		"frames": "res://assets/sprites/abante/frames/player_dagger_frames.tres",
	},
	"weapon_1": {
		"name": "SHORT SWORD",
		"cost": 5,
		"uses": 7,
		"hits": 4,
		"purchasable": true,
		"icon_region": Rect2(36, 7, 26, 9),
		"frames": "res://assets/sprites/abante/frames/player_short_sword_frames.tres",
	},
	"weapon_2": {
		"name": "BATTLE AXE",
		"cost": 10,
		"uses": 7,
		"hits": 3,
		"purchasable": true,
		"icon_region": Rect2(71, 3, 29, 17),
		"frames": "res://assets/sprites/abante/frames/player_battle_axe_frames.tres",
	},
	"weapon_best": {
		"name": "ENCHANTED BLADE",
		"cost": 15,
		"uses": 7,
		"hits": 2,
		"purchasable": true,
		"icon_region": Rect2(106, 6, 32, 11),
		"frames": "res://assets/sprites/abante/frames/player_enchanted_blade_frames.tres",
	},
}

## All weapon icons (HUD "weapon in use" + shop cards) come from this strip;
## each weapon stores its tight region in it.
const ICON_SHEET := preload("res://assets/sprites/abante/weapons/weapons_spritesheet.png")

## Player animations while no weapon is held.
const UNARMED_FRAMES := "res://assets/sprites/abante/frames/player_unarmed_frames.tres"

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
	var info := get_info(weapon_id)
	if not info.has("icon_region"):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_SHEET
	atlas.region = info.icon_region
	return atlas


## Player SpriteFrames for a weapon (unarmed frames for "" / unknown ids).
static func get_frames(weapon_id: String) -> SpriteFrames:
	var path: String = get_info(weapon_id).get("frames", UNARMED_FRAMES)
	return load(path) as SpriteFrames


## Cheapest weapon the shop can sell (used for "you can afford a weapon" hints).
static func cheapest_cost() -> int:
	var best := -1
	for id in ORDER:
		var info: Dictionary = WEAPONS[id]
		if info.purchasable and (best < 0 or info.cost < best):
			best = info.cost
	return best
