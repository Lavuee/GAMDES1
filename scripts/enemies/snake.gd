extends GroundEnemy
## Snake: lower-ground enemy (Level 2+). Uses GroundEnemy's lunge and a
## slithering squash animation instead of the crocodile's stomp.


func _animate_walk(speed_factor: float) -> void:
	var wave := sin(_anim_time * 12.0 * speed_factor)
	sprite.scale = Vector2(1.0 + wave * 0.06, 1.0 - wave * 0.05)
	sprite.position.y = _sprite_base_y() * sprite.scale.y
	sprite.rotation = wave * 0.04
