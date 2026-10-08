class_name DamageArea
extends Area2D
## Hurts the player on contact. The player's hurtbox polls overlapping
## DamageAreas, so the damage amount lives here (in half-heart units).

## 3 = 1.5 hearts (crocodile), 6 = 3 hearts (snake), 10 = 5 hearts (bird).
@export var damage_half_hearts := 3
@export var active := true


func is_active() -> bool:
	return active and monitorable
