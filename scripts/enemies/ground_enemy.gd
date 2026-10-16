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
## Where the health hearts float, relative to the enemy's feet.
@export var hearts_offset := Vector2(0, -64)
## Sound prefix: plays "<voice>_idle / _alert / _attack / _hurt / _die"
## from the Audio library ("croc", "snake"). Empty = generic sounds only.
@export var voice := ""

const HIT_STUN_TIME := 0.22
const HIT_KNOCKBACK := 170.0
const CHASE_DEADZONE := 10.0
## Distance at which the (purely visual) attack animation plays.
const ATTACK_ANIM_RANGE := 60.0
## Enemies further than this from the player stay quiet.
const HEARING_RANGE := 520.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
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
var _chasing := false
var _was_chasing := false
var _idle_call_timer := 0.0
var _alert_cooldown := 0.0
var _player: Node2D
var _hearts: EnemyHealthHearts


func _ready() -> void:
	add_to_group("ground_enemy")
	_spawn_x = global_position.x
	_speed = _speed_for_level(Game.current_level)
	damage_area.damage_half_hearts = damage_half_hearts
	_anim_time = randf() * 10.0
	_lunge_cooldown_timer = randf_range(0.3, lunge_cooldown)
	_idle_call_timer = randf_range(2.0, 6.0)
	_hearts = EnemyHealthHearts.new()
	_hearts.position = hearts_offset
	add_child(_hearts)
	_hearts.set_health(health, WeaponCatalog.ENEMY_MAX_HEALTH)


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
	_update_voice(delta)
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
	_chasing = false
	if _player_is_targetable():
		var dx := _player.global_position.x - global_position.x
		# Only chase inside the patrol zone so enemies don't bunch up.
		if absf(dx) < aggro_range and _player.global_position.x > left_limit - 40.0 and _player.global_position.x < right_limit + 40.0:
			chasing = true
			_chasing = true
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
	_play_anim(&"hurt", true)
	_hearts.set_health(health, WeaponCatalog.ENEMY_MAX_HEALTH)
	_hearts.pulse()
	Audio.play("hit", 0.08)
	if health == 0:
		_die()
	else:
		_say("hurt")


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	damage_area.active = false
	damage_area.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitorable", false)
	body_shape.set_deferred("disabled", true)
	Audio.play("enemy_die")
	_say("die", true)
	_hearts.fade_out()
	defeated.emit(self)
	# Death animation from the spritesheet. Keep it running if the last kill
	# pauses the tree for the level transition.
	_flash = 0.0
	visual.modulate = Color.WHITE
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_anim(&"death", true)
	sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	_anim_time += delta
	var flip := direction < 0 if sprite_faces_right else direction > 0
	visual.scale.x = -1.0 if flip else 1.0
	_play_anim(_pick_animation())
	# Faster gaits play their cycle a bit quicker (level speed scaling).
	sprite.speed_scale = clampf(absf(velocity.x) / _speed, 0.8, 1.6) if sprite.animation in [&"walk", &"chase"] else 1.0

	_flash = move_toward(_flash, 0.0, delta * 5.0)
	visual.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), _flash) if _flash > 0.0 else Color.WHITE


func _pick_animation() -> StringName:
	if _stun_timer > 0.0:
		return &"hurt"
	if _lunge_timer > 0.0 or (_chasing and _player and absf(_player.global_position.x - global_position.x) < ATTACK_ANIM_RANGE):
		return &"attack"
	if absf(velocity.x) > 5.0:
		return &"chase" if _chasing else &"walk"
	return &"idle"


## Changes animation only when it differs; `restart` replays a one-shot.
## A finished bite repeats while the player stays in range.
func _play_anim(anim: StringName, restart := false) -> void:
	if restart or sprite.animation != anim or (anim == &"attack" and not sprite.is_playing()):
		sprite.play(anim)
		sprite.frame = 0
		if anim == &"attack":
			_say("attack")


# ---------------------------------------------------------------------------
# Voice
# ---------------------------------------------------------------------------

## Growl / hiss when the enemy spots the player, plus an occasional idle call
## while the player is within earshot.
func _update_voice(delta: float) -> void:
	_alert_cooldown = maxf(_alert_cooldown - delta, 0.0)
	if _chasing and not _was_chasing and _alert_cooldown <= 0.0:
		_say("alert")
		_alert_cooldown = 3.0
	_was_chasing = _chasing
	_idle_call_timer -= delta
	if _idle_call_timer <= 0.0:
		_idle_call_timer = randf_range(4.0, 8.0)
		if not _chasing:
			_say("idle")


## Plays "<voice>_<what>" if the player can hear this enemy. `always` skips
## the distance check (death cries).
func _say(what: String, always := false) -> void:
	if voice.is_empty():
		return
	if not always and (_player == null or _player.global_position.distance_to(global_position) > HEARING_RANGE):
		return
	Audio.play("%s_%s" % [voice, what], 0.08)
