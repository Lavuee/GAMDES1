class_name DisappearingPlatform
extends StaticBody2D
## Upper platform that crumbles after the player lands on it.
## Idle -> (player lands) Warning: shakes & blinks for `warning_time`
## -> Gone: no collision, faded out -> reappears after `respawn_time`.

enum PlatformState { IDLE, WARNING, GONE, RESPAWNING }

@export var warning_time := 1.0
@export var respawn_time := 3.5

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var state := PlatformState.IDLE
var _timer := 0.0
var _sprite_base := Vector2.ZERO


func _ready() -> void:
	_sprite_base = sprite.position


## Called by the player whenever they stand on this platform.
func on_player_landed() -> void:
	if state != PlatformState.IDLE:
		return
	state = PlatformState.WARNING
	_timer = warning_time
	Audio.play("crumble", 0.1)


func _physics_process(delta: float) -> void:
	match state:
		PlatformState.WARNING:
			_timer -= delta
			var urgency := 1.0 - clampf(_timer / warning_time, 0.0, 1.0)
			# Shake harder and flash faster as the platform is about to go.
			sprite.position = _sprite_base + Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * (1.0 + urgency * 2.0)
			var blink := sin(urgency * urgency * 40.0) > 0.0
			sprite.modulate = Color(1.0, 0.75, 0.75) if blink else Color.WHITE
			if _timer <= 0.0:
				_vanish()
		PlatformState.GONE:
			_timer -= delta
			if _timer <= 0.0:
				_reappear()


func _vanish() -> void:
	state = PlatformState.GONE
	_timer = respawn_time
	sprite.position = _sprite_base
	collision.set_deferred("disabled", true)
	Audio.play("crumble")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_property(sprite, "position:y", _sprite_base.y + 14.0, 0.25)


func _reappear() -> void:
	state = PlatformState.RESPAWNING
	sprite.position = _sprite_base
	collision.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	tween.tween_callback(func() -> void: state = PlatformState.IDLE)
