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
## Within this distance of the player the bird shows its swoop animation
## (visual only; the flight path is unchanged).
@export var swoop_anim_range := Vector2(150, 110)

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var damage_area: DamageArea = $DamageArea

var direction := 1
var _origin := Vector2.ZERO
var _offset_x := 0.0
var _time := 0.0
var _pause_timer := 0.0
var _speed := 100.0
var _player: Node2D
var _caw_timer := randf_range(3.0, 7.0)

## The bird is only heard while the player is this close.
const HEARING_RANGE := 600.0


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

	_update_animation()
	var flip := direction < 0 if sprite_faces_right else direction > 0
	visual.scale.x = -1.0 if flip else 1.0
	visual.rotation = 0.08 * direction if _pause_timer <= 0.0 else 0.0


## Flap along the route (a bit slower while hovering at a turn); swoop
## when the player is close.
func _update_animation() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var anim := &"fly"
	sprite.speed_scale = 0.7 if _pause_timer > 0.0 else 1.0
	if _player and not _player.get("is_dead"):
		var d := (_player.global_position + Vector2(0, -30)) - global_position
		if absf(d.x) < swoop_anim_range.x and absf(d.y) < swoop_anim_range.y:
			anim = &"attack"
	if sprite.animation != anim or (anim == &"attack" and not sprite.is_playing()):
		if anim == &"attack" and sprite.animation != &"attack":
			_call("bird_screech")
		sprite.play(anim)
	_caw_timer -= get_physics_process_delta_time()
	if _caw_timer <= 0.0:
		_caw_timer = randf_range(4.0, 9.0)
		_call("bird_caw")


func _call(sound: String) -> void:
	if _player and _player.global_position.distance_to(global_position) <= HEARING_RANGE:
		Audio.play(sound, 0.1)
