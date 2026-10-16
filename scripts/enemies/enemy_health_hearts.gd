class_name EnemyHealthHearts
extends Node2D
## Row of mini hearts floating above a ground enemy, showing how much life it
## has left in the same full / half / empty style as the player's HUD hearts.
## Each heart is an equal share of the enemy's max health; partial damage is
## rounded up to the next half heart, so a living enemy never shows 0 hearts.

const HEART_FULL := preload("res://assets/sprites/abante/heart_full.png")
const HEART_HALF := preload("res://assets/sprites/abante/heart_half.png")
const EMPTY_COLOR := Color(0.12, 0.08, 0.1, 0.6)

@export var hearts := 5
@export var spacing := 11.0
@export var heart_scale := 0.5

var _fronts: Array[Sprite2D] = []


func _ready() -> void:
	z_index = 5
	for i in hearts:
		var x := (i - (hearts - 1) * 0.5) * spacing
		# Dark full heart behind every slot = the "empty" container.
		var back := Sprite2D.new()
		back.texture = HEART_FULL
		back.modulate = EMPTY_COLOR
		back.scale = Vector2.ONE * heart_scale
		back.position = Vector2(roundf(x), 0)
		add_child(back)
		var front := Sprite2D.new()
		front.scale = back.scale
		add_child(front)
		_fronts.append(front)


func set_health(current: int, maximum: int) -> void:
	var per_half := float(maximum) / (hearts * 2)
	var halves := clampi(ceili(current / per_half - 0.001), 0, hearts * 2)
	for i in hearts:
		var front := _fronts[i]
		var slot_x := roundf((i - (hearts - 1) * 0.5) * spacing)
		var remaining := halves - i * 2
		if remaining >= 2:
			front.texture = HEART_FULL
			front.position = Vector2(slot_x, 0)
			front.visible = true
		elif remaining == 1:
			# The half-heart art is the left half; keep its left edge aligned.
			front.texture = HEART_HALF
			var offset := (HEART_FULL.get_width() - HEART_HALF.get_width()) * 0.5 * heart_scale
			front.position = Vector2(slot_x - offset, 0)
			front.visible = true
		else:
			front.visible = false


## Quick bump so the player notices the hearts drop.
func pulse() -> void:
	scale = Vector2.ONE * 1.35
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func fade_out() -> void:
	create_tween().tween_property(self, "modulate:a", 0.0, 0.25)
