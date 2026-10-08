class_name Coin
extends Area2D
## Collectible coin. Every coin gives +1 coin currency; score depends on where
## it was placed (ground = 1, upper platform = 2). Enemy drops pop out of the
## enemy and land on the ground before they can be collected.

@export var score_value := 1

@onready var sprite: Sprite2D = $Sprite

var _collected := false
var _spin_time := 0.0
var _base_scale := Vector2.ONE
var _ready_to_collect := true


func _ready() -> void:
	_spin_time = randf() * TAU
	_base_scale = sprite.scale
	body_entered.connect(_on_body_entered)
	if score_value >= 2:
		# Upper-platform coins glint a little brighter.
		sprite.modulate = Color(1.15, 1.1, 0.9)


## Spawned by a defeated enemy: arc upward then settle at `land_y`.
func pop_from(start: Vector2, land_y: float) -> void:
	global_position = start
	_ready_to_collect = false
	var peak := start + Vector2(randf_range(-20.0, 20.0), -46.0)
	var land := Vector2(peak.x + (peak.x - start.x), land_y)
	var tween := create_tween()
	tween.tween_property(self, "global_position", peak, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", land, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_ready_to_collect = true
		for body in get_overlapping_bodies():
			_on_body_entered(body)
	)


func _process(delta: float) -> void:
	if _collected:
		return
	_spin_time += delta
	sprite.scale = Vector2(_base_scale.x * maxf(absf(cos(_spin_time * 2.4)), 0.2), _base_scale.y)
	sprite.position.y = sin(_spin_time * 3.0) * 2.0


func _on_body_entered(body: Node) -> void:
	if _collected or not _ready_to_collect or not body.is_in_group("player"):
		return
	if not Game.is_playing():
		return
	_collected = true
	set_deferred("monitoring", false)
	Game.collect_coin(score_value, global_position)
	Audio.play("coin", 0.06)
	# Collection effect: pop up, grow and fade.
	sprite.scale = _base_scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - 26.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", _base_scale * 1.5, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
