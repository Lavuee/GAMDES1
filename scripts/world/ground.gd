@tool
class_name Ground
extends StaticBody2D
## Lower ground strip. Tiles the ground texture across `width` and builds a
## matching collision box. The node origin is the left edge of the walkable
## surface (top of the grass).

@export var width := 3200.0:
	set(value):
		width = maxf(value, 64.0)
		_rebuild()
## Pixels from the top of the texture down to the walkable grass surface.
@export var surface_offset := 12.0:
	set(value):
		surface_offset = value
		_rebuild()
@export var fill_color := Color(0.23, 0.14, 0.09)

const COLLISION_DEPTH := 200.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("Sprite") as Sprite2D
	var fill := get_node_or_null("Fill") as ColorRect
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sprite and sprite.texture:
		var tex_height := sprite.texture.get_height()
		sprite.centered = false
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, width, tex_height)
		sprite.position = Vector2(0, -surface_offset)
		if fill:
			fill.position = Vector2(0, tex_height - surface_offset - 4.0)
			fill.size = Vector2(width, COLLISION_DEPTH)
			fill.color = fill_color
	if shape_node:
		var rect := shape_node.shape as RectangleShape2D
		if rect == null:
			rect = RectangleShape2D.new()
			shape_node.shape = rect
		rect.size = Vector2(width, COLLISION_DEPTH)
		shape_node.position = Vector2(width * 0.5, COLLISION_DEPTH * 0.5)
