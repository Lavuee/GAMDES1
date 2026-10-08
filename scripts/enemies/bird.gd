class_name Bird
extends Node2D
## Flying hazard (Level 3). Cannot be attacked (it has no hurtbox, so the
## player's swings pass straight through) and does not count toward clearing
## the level. Flies back and forth along a wavy path near upper platforms.

@export var damage_half_hearts := 10
## Horizontal flight range relative to the spawn position.
@export var range_left := -220.0
@export var range_right := 220.0
## Flight speed for level 1, 2, 3 (birds normally only appear in level 3).
@export var speed_by_level: Array[float] = [90.0, 100.0, 110.0]
@export var wave_amplitude := 22.0
@export var wave_frequency := 1.6
## Pause at each end of the route, giving the player a readable window.
@export var turn_pause := 0.5
@export var sprite_faces_right := true

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var damage_area: DamageArea = $DamageArea

var direction := 1
var _origin := Vector2.ZERO
var _offset_x := 0.0
var _time := 0.0
var _pause_timer := 0.0
var _speed := 100.0


func _ready() -> void:
	_origin = global_position
	_speed = speed_by_level[clampi(Game.current_level - 1, 0, speed_by_level.size() - 1)] if not speed_by_level.is_empty() else 100.0
	damage_area.damage_half_hearts = damage_half_hearts
	_time = randf() * TAU
	direction = 1 if randf() < 0.5 else -1


func _physics_process(delta: float) -> void:
	_time += delta
	if _pause_timer > 0.0:
		_pause_timer -= delta
	else:
		_offset_x += direction * _speed * delta
		if _offset_x >= range_right:
			_offset_x = range_right
			direction = -1
			_pause_timer = turn_pause
		elif _offset_x <= range_left:
			_offset_x = range_left
			direction = 1
			_pause_timer = turn_pause
	global_position = _origin + Vector2(_offset_x, sin(_time * wave_frequency) * wave_amplitude)

	# Wing flap: quick vertical squash; face flight direction.
	var flap := sin(_time * 16.0)
	sprite.scale = Vector2(1.0 + flap * 0.04, 1.0 - flap * 0.12)
	var flip := direction < 0 if sprite_faces_right else direction > 0
	visual.scale.x = -1.0 if flip else 1.0
	visual.rotation = 0.08 * direction if _pause_timer <= 0.0 else 0.0
