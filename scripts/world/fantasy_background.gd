extends Node2D
## Fantasy parallax backdrop shared by all levels.
##
## Layers (back to front) are Parallax2D nodes in the scene; clouds and the
## river use Parallax2D.autoscroll, waterfalls / river / foliage animate via
## shaders. This script adds the slow island bob, pulsing light shafts, the
## breathing waterfall mist and sizes the particle emitters to the level width.

@export var island_bob_pixels := 4.0
@export var island_bob_speed := 0.5
@export var ray_pulse_speed := 0.6
## Used when the background is not inside a Level (e.g. previews).
@export var fallback_width := 3200.0

@onready var islands: Sprite2D = $FloatingIslands/Sprite
@onready var rays: Node2D = $LightRays
@onready var mist: Sprite2D = $WaterMist/Sprite
@onready var motes: CPUParticles2D = $Magic/Motes
@onready var fireflies: CPUParticles2D = $Magic/Fireflies

var _time := 0.0
var _island_base_y := 0.0


func _ready() -> void:
	_island_base_y = islands.position.y
	var level := get_parent() as Level
	var width := level.level_width if level else fallback_width
	for emitter: CPUParticles2D in [motes, fireflies]:
		emitter.position.x = width * 0.5
		emitter.emission_rect_extents.x = width * 0.5
		# Keep density per screen constant across level lengths.
		emitter.amount = maxi(int(emitter.amount * width / fallback_width), 1)
		emitter.restart()


func _process(delta: float) -> void:
	_time += delta
	# Whole-pixel bob keeps the scaled pixel art crisp.
	islands.position.y = _island_base_y + roundf(sin(_time * island_bob_speed) * island_bob_pixels)
	var index := 0
	for ray in rays.get_children():
		(ray as CanvasItem).modulate.a = lerpf(0.15, 0.55, 0.5 + 0.5 * sin(_time * ray_pulse_speed + index * 2.1))
		index += 1
	# Waterfall spray breathing above the river.
	mist.modulate.a = 0.75 + 0.25 * sin(_time * 0.7)
