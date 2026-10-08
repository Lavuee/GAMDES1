class_name Player
extends CharacterBody2D
## Side-view platformer hero: run, jump, drop through platforms, swing the
## current weapon and take damage from DamageAreas.
##
## The player art is a single frame, so idle / run / jump / fall / attack /
## hurt "animations" are done procedurally (bob, lean, squash & stretch,
## weapon swing arc, damage flash).

@export_group("Movement")
@export var max_speed := 230.0
@export var ground_acceleration := 2200.0
@export var ground_deceleration := 2800.0
@export var air_acceleration := 1500.0
@export var gravity := 1500.0
@export var fall_gravity_multiplier := 1.3
@export var max_fall_speed := 900.0
@export var jump_velocity := -620.0
## Releasing jump early multiplies upward velocity by this (variable jump height).
@export var jump_cut_multiplier := 0.45
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var drop_through_time := 0.25

@export_group("Combat")
@export var attack_cooldown := 0.34
@export var attack_duration := 0.24
@export var attack_active_start := 0.04
@export var attack_active_end := 0.17
@export var invincibility_time := 1.2
@export var hurt_stun_time := 0.25
@export var knockback := Vector2(260, -300)

const PLATFORM_LAYER := 2
const SWING_START_ANGLE := deg_to_rad(-75.0)
const SWING_END_ANGLE := deg_to_rad(105.0)
const WEAPON_REST_ANGLE := deg_to_rad(8.0)

@onready var visual: Node2D = $Visual
@onready var body_sprite: Sprite2D = $Visual/Body
@onready var weapon_pivot: Node2D = $Visual/WeaponPivot
@onready var weapon_sprite: Sprite2D = $Visual/WeaponPivot/Weapon
@onready var slash: Line2D = $Visual/Slash
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var camera: Camera2D = $Camera2D

var facing := 1
var is_dead := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_elapsed := -1.0
var _invincible_timer := 0.0
var _hurt_stun_timer := 0.0
var _drop_timer := 0.0
var _shake_timer := 0.0
var _shake_strength := 0.0
var _anim_time := 0.0
var _was_on_floor := true
var _landing_squash := 0.0
var _hit_this_swing: Array[Node] = []
var _attack_damage := 0
var _hitbox_base_x := 0.0
var _bounds := Rect2(-INF, -INF, INF, INF)


func _ready() -> void:
	add_to_group("player")
	_hitbox_base_x = absf(attack_hitbox.position.x)
	slash.visible = false
	Game.weapon_changed.connect(_on_weapon_changed)
	Game.player_died.connect(_on_player_died)
	_on_weapon_changed(Game.weapon_id, Game.weapon_uses)


## Called by the level: horizontal limits and camera limits.
func setup_bounds(left: float, right: float, top: float, bottom: float) -> void:
	_bounds = Rect2(left, top, right - left, bottom - top)
	camera.limit_left = int(left)
	camera.limit_right = int(right)
	camera.limit_top = int(top)
	camera.limit_bottom = int(bottom)
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	if is_dead:
		_physics_dead(delta)
		return

	_tick_timers(delta)
	var input_dir := Input.get_axis("move_left", "move_right")
	if _hurt_stun_timer > 0.0:
		input_dir = 0.0

	_apply_gravity(delta)
	_apply_horizontal(input_dir, delta)
	_handle_jump()

	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("open_shop"):
		Game.request_shop()

	move_and_slide()
	_clamp_to_bounds()
	_notify_landed_platforms()
	_update_attack(delta)
	_check_damage()
	_update_visuals(delta, input_dir)


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	_hurt_stun_timer = maxf(_hurt_stun_timer - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)


func _apply_gravity(delta: float) -> void:
	var g := gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _apply_horizontal(input_dir: float, delta: float) -> void:
	var target := input_dir * max_speed
	var rate: float
	if is_on_floor():
		rate = ground_acceleration if absf(target) > 0.01 else ground_deceleration
	else:
		rate = air_acceleration
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if input_dir != 0.0 and _attack_elapsed < 0.0:
		facing = 1 if input_dir > 0.0 else -1


func _handle_jump() -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		if Input.is_action_pressed("move_down") and _is_on_platform():
			_drop_through()
		else:
			velocity.y = jump_velocity
			Audio.play("jump", 0.05)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _drop_through() -> void:
	set_collision_mask_value(PLATFORM_LAYER, false)
	_drop_timer = drop_through_time
	position.y += 2.0


func _is_on_platform() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is CollisionObject2D and (collider as CollisionObject2D).get_collision_layer_value(PLATFORM_LAYER):
			return true
	return false


func _clamp_to_bounds() -> void:
	var half_width := 14.0
	var clamped_x := clampf(global_position.x, _bounds.position.x + half_width, _bounds.end.x - half_width)
	if clamped_x != global_position.x:
		global_position.x = clamped_x
		velocity.x = 0.0


## Lets disappearing platforms know the player is standing on them.
func _notify_landed_platforms() -> void:
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method("on_player_landed") and collision.get_normal().y < -0.7:
			collider.on_player_landed()


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _try_attack() -> void:
	if not Game.is_playing() or _attack_cooldown_timer > 0.0:
		return
	if not Game.is_armed():
		var cheapest := WeaponCatalog.cheapest_cost()
		if Game.coins >= cheapest:
			Game.request_shop()
		else:
			Audio.play("denied")
			Game.toast.emit("UNARMED! Collect %d coins to buy a weapon." % cheapest)
		return
	# Capture damage before consuming the use: the 7th swing still hits.
	var damage := Game.get_weapon_damage()
	if not Game.consume_weapon_use():
		return
	_attack_damage = damage
	_attack_cooldown_timer = attack_cooldown
	_attack_elapsed = 0.0
	_hit_this_swing.clear()
	attack_hitbox.position.x = _hitbox_base_x * facing
	slash.visible = true
	slash.modulate.a = 0.9
	weapon_sprite.visible = true
	Audio.play("attack", 0.1)



func _update_attack(delta: float) -> void:
	if _attack_elapsed < 0.0:
		return
	_attack_elapsed += delta
	var t := clampf(_attack_elapsed / attack_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	weapon_pivot.rotation = lerpf(SWING_START_ANGLE, SWING_END_ANGLE, eased)
	slash.modulate.a = 0.9 * (1.0 - t)

	if _attack_elapsed >= attack_active_start and _attack_elapsed <= attack_active_end:
		for area in attack_hitbox.get_overlapping_areas():
			var target := area.get_parent()
			if target in _hit_this_swing or not target.has_method("take_hit"):
				continue
			_hit_this_swing.append(target)
			target.take_hit(_attack_damage, global_position.x)

	if _attack_elapsed >= attack_duration:
		_attack_elapsed = -1.0
		slash.visible = false
		weapon_pivot.rotation = WEAPON_REST_ANGLE
		weapon_sprite.visible = Game.is_armed()


func _check_damage() -> void:
	if _invincible_timer > 0.0 or not Game.is_playing() or not hurtbox.monitoring:
		return
	for area in hurtbox.get_overlapping_areas():
		if area is DamageArea and (area as DamageArea).is_active():
			_take_damage(area as DamageArea)
			return


func _take_damage(source: DamageArea) -> void:
	_invincible_timer = invincibility_time
	_hurt_stun_timer = hurt_stun_time
	var direction := signf(global_position.x - source.global_position.x)
	if direction == 0.0:
		direction = -facing
	velocity = Vector2(direction * knockback.x, knockback.y)
	shake_camera(0.25, 6.0)
	Audio.play("hurt")
	# May trigger game over (handled through Game.player_died).
	Game.damage_player(source.damage_half_hearts)


func shake_camera(duration: float, strength: float) -> void:
	_shake_timer = duration
	_shake_strength = strength


func _on_weapon_changed(weapon_id: String, _uses: int) -> void:
	var icon := WeaponCatalog.get_icon(weapon_id)
	if icon:
		weapon_sprite.texture = icon
		# Anchor the handle (bottom-left of the diagonal sword art) on the hand.
		var size := icon.get_size()
		weapon_sprite.position = Vector2(size.x * 0.5 - 6.0, -size.y * 0.5 + 6.0)
	# Keep the weapon visible during the final swing; hide once it finishes.
	if _attack_elapsed < 0.0:
		weapon_sprite.visible = weapon_id != WeaponCatalog.UNARMED


func _on_player_died() -> void:
	is_dead = true
	slash.visible = false
	set_collision_mask_value(PLATFORM_LAYER, true)
	visual.visible = true
	visual.modulate = Color(1.0, 0.45, 0.45)
	shake_camera(0.4, 8.0)


func _physics_dead(delta: float) -> void:
	# Runs only if the tree is unpaused while dead (normally game over pauses).
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)
	move_and_slide()


# ---------------------------------------------------------------------------
# Procedural animation
# ---------------------------------------------------------------------------

func _update_visuals(delta: float, input_dir: float) -> void:
	_anim_time += delta
	visual.scale.x = facing

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_landing_squash = 1.0
		Audio.play("land", 0.1)
	_was_on_floor = on_floor
	_landing_squash = move_toward(_landing_squash, 0.0, delta * 6.0)

	var squash := Vector2.ONE
	var bob := 0.0
	var lean := 0.0
	if not on_floor:
		# Jump: stretch while rising, slight squash while falling.
		squash = Vector2(0.92, 1.08) if velocity.y < 0.0 else Vector2(1.04, 0.97)
	elif absf(velocity.x) > 20.0 and absf(input_dir) > 0.0:
		# Run: bouncy steps and a lean into the movement.
		bob = -absf(sin(_anim_time * 14.0)) * 3.0
		lean = 0.07
	else:
		# Idle: gentle breathing.
		squash = Vector2(1.0, 1.0 + sin(_anim_time * 3.0) * 0.02)
	squash += Vector2(0.12, -0.12) * _landing_squash

	body_sprite.scale = squash
	body_sprite.position.y = -29.0 * squash.y + bob
	body_sprite.rotation = lean
	weapon_pivot.position.y = -20.0 + bob

	# Damage flash / invincibility blink.
	if _invincible_timer > 0.0:
		var recently_hit := _invincible_timer > invincibility_time - 0.15
		visual.modulate = Color(1.0, 0.3, 0.3) if recently_hit else Color.WHITE
		visual.visible = recently_hit or int(_invincible_timer * 14.0) % 2 == 0
	else:
		visual.modulate = Color.WHITE
		visual.visible = true

	# Camera shake.
	if _shake_timer > 0.0:
		_shake_timer -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		camera.offset = Vector2.ZERO
