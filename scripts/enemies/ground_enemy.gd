class_name GroundEnemy
extends CharacterBody2D
## Shared behaviour for crocodiles and snakes: ground patrol, short-range
## chase, contact damage, hit reactions and death.
##
## Health never scales with level; only speed does (speed_by_level).
## Hits needed = WeaponCatalog.ENEMY_MAX_HEALTH / weapon damage.

signal defeated(enemy: GroundEnemy)

@export var enemy_name := "Enemy"
## Contact damage in half hearts (3 = 1.5 hearts).
@export var damage_half_hearts := 3
## Patrol speed for level 1, 2, 3. Missing entries reuse the last value.
@export var speed_by_level: Array[float] = [55.0, 80.0, 105.0]
## Chase speed relative to patrol speed when the player is close on the ground.
@export var chase_multiplier := 1.35
@export var aggro_range := 240.0
@export var aggro_height := 70.0
## Patrol limits relative to the spawn position.
@export var patrol_left := -180.0
@export var patrol_right := 180.0
@export var gravity := 1500.0
## Optional quick lunge toward a nearby player (used by snakes).
@export var lunge_enabled := false
@export var lunge_speed_multiplier := 2.6
@export var lunge_duration := 0.28
@export var lunge_cooldown := 1.6
@export var lunge_range := 120.0
## Art faces right when true; flip handled automatically.
@export var sprite_faces_right := true

const HIT_STUN_TIME := 0.22
const HIT_KNOCKBACK := 170.0
const CHASE_DEADZONE := 10.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var damage_area: DamageArea = $DamageArea
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var health := WeaponCatalog.ENEMY_MAX_HEALTH
var direction := -1
var is_dead := false

var _spawn_x := 0.0
var _speed := 60.0
var _stun_timer := 0.0
var _lunge_timer := 0.0
var _lunge_cooldown_timer := 0.0
var _anim_time := 0.0
var _flash := 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group("ground_enemy")
	_spawn_x = global_position.x
	_speed = _speed_for_level(Game.current_level)
	damage_area.damage_half_hearts = damage_half_hearts
	_anim_time = randf() * 10.0
	_lunge_cooldown_timer = randf_range(0.3, lunge_cooldown)


func _speed_for_level(level: int) -> float:
	if speed_by_level.is_empty():
		return 60.0
	return speed_by_level[clampi(level - 1, 0, speed_by_level.size() - 1)]


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_lunge_cooldown_timer = maxf(_lunge_cooldown_timer - delta, 0.0)

	if _stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	else:
		velocity.x = _choose_horizontal_velocity(delta)

	move_and_slide()
	if is_on_wall() and _stun_timer <= 0.0:
		direction = -direction
	_update_visuals(delta)


func _choose_horizontal_velocity(delta: float) -> float:
	var left_limit := _spawn_x + patrol_left
	var right_limit := _spawn_x + patrol_right

	# Lunge in progress.
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		if (direction < 0 and global_position.x <= left_limit) or (direction > 0 and global_position.x >= right_limit):
			_lunge_timer = 0.0
		return direction * _speed * lunge_speed_multiplier

	var chasing := false
	if _player_is_targetable():
		var dx := _player.global_position.x - global_position.x
		# Only chase inside the patrol zone so enemies don't bunch up.
		if absf(dx) < aggro_range and _player.global_position.x > left_limit - 40.0 and _player.global_position.x < right_limit + 40.0:
			chasing = true
			if absf(dx) > CHASE_DEADZONE:
				direction = 1 if dx > 0.0 else -1
			else:
				return 0.0
			if lunge_enabled and _lunge_cooldown_timer <= 0.0 and absf(dx) < lunge_range:
				_lunge_timer = lunge_duration
				_lunge_cooldown_timer = lunge_cooldown
				return direction * _speed * lunge_speed_multiplier

	if not chasing:
		if global_position.x <= left_limit:
			direction = 1
		elif global_position.x >= right_limit:
			direction = -1

	var speed := _speed * (chase_multiplier if chasing else 1.0)
	var next_x := global_position.x + direction * speed * delta
	if (direction < 0 and next_x < left_limit) or (direction > 0 and next_x > right_limit):
		# Stop at the patrol edge instead of jittering across it.
		return 0.0 if chasing else direction * speed
	return direction * speed


func _player_is_targetable() -> bool:
	if _player == null or not Game.is_playing():
		return false
	if _player.get("is_dead"):
		return false
	# Ignore the player while they're up on platforms: that's the escape route.
	return absf(_player.global_position.y - global_position.y) < aggro_height


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Called by the player's attack hitbox. `source_x` is the attacker position.
func take_hit(damage: int, source_x: float) -> void:
	if is_dead or damage <= 0:
		return
	health = maxi(health - damage, 0)
	_flash = 1.0
	_stun_timer = HIT_STUN_TIME
	_lunge_timer = 0.0
	var push := signf(global_position.x - source_x)
	velocity.x = (push if push != 0.0 else 1.0) * HIT_KNOCKBACK
	Audio.play("hit", 0.08)
	if health == 0:
		_die()


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	damage_area.active = false
	damage_area.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitorable", false)
	body_shape.set_deferred("disabled", true)
	Audio.play("enemy_die")
	defeated.emit(self)
	# Death animation: pop up, flip over and fade out.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "position:y", visual.position.y - 18.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation", PI * 0.5 * -direction, 0.4)
	tween.tween_property(visual, "modulate", Color(1, 1, 1, 0), 0.45).set_delay(0.1)
	tween.chain().tween_callback(queue_free)


# ---------------------------------------------------------------------------
# Procedural animation
# ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	_anim_time += delta
	var moving := absf(velocity.x) > 5.0
	var flip := direction < 0 if sprite_faces_right else direction > 0
	visual.scale.x = -1.0 if flip else 1.0
	var speed_factor := clampf(absf(velocity.x) / 60.0, 0.5, 3.0)
	if moving:
		_animate_walk(speed_factor)
	else:
		sprite.position.y = _sprite_base_y()
		sprite.scale = Vector2(1.0, 1.0 + sin(_anim_time * 2.5) * 0.015)

	_flash = move_toward(_flash, 0.0, delta * 5.0)
	visual.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), _flash) if _flash > 0.0 else Color.WHITE


## Override in subclasses for a different gait.
func _animate_walk(speed_factor: float) -> void:
	sprite.position.y = _sprite_base_y() - absf(sin(_anim_time * 9.0 * speed_factor)) * 2.0
	sprite.rotation = sin(_anim_time * 9.0 * speed_factor) * 0.03
	sprite.scale = Vector2.ONE


func _sprite_base_y() -> float:
	return -sprite.texture.get_height() * 0.5 if sprite.texture else 0.0
