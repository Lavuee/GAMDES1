extends Control
## Full-screen fades and banners between levels.
## Everything here runs while the tree is paused.

@onready var fade: ColorRect = %Fade
@onready var banner: Control = %Banner
@onready var big_label: Label = %BigLabel
@onready var small_label: Label = %SmallLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color.a = 0.0
	banner.modulate.a = 0.0


## "LEVEL 2" intro banner shown over gameplay (does not block input).
func show_intro(level_number: int, title: String) -> void:
	big_label.text = "LEVEL %d" % level_number
	small_label.text = title
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.5)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.4)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)


## Level-complete sequence. Await it; the screen ends fully black so the
## caller can swap levels behind it, then call reveal().
func play_level_complete(level_number: int) -> void:
	big_label.text = "LEVEL %d COMPLETE!" % level_number
	small_label.text = "Hearts %s / 10   ·   Coins %d   ·   Score %d" % [Game.format_hearts(Game.half_hearts), Game.coins, Game.score]
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.7, 0.4)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.tween_property(fade, "color:a", 1.0, 0.3)
	await tween.finished


func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.4)
	await tween.finished

