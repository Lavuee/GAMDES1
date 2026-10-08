class_name FloatingText
extends Label
## Small "+2" style popup that rises and fades in world space.

static func spawn(parent: Node, text_value: String, world_position: Vector2, color: Color = Color(1.0, 0.9, 0.35)) -> void:
	if parent == null:
		return
	var label := FloatingText.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 16)
	label.z_index = 50
	parent.add_child(label)
	label.global_position = world_position + Vector2(-12, -30)


func _ready() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 28.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
