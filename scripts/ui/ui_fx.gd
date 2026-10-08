class_name UIFx
extends RefCounted
## Shared UI feedback: hover/press sounds and a small scale bounce on buttons.

const HOVER_SCALE := Vector2(1.05, 1.05)


## Connects feedback to every Button under `root` (call once after building UI).
static func wire_buttons(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		wire_button(node as Button)


static func wire_button(button: Button) -> void:
	if button == null or button.has_meta("ui_fx_wired"):
		return
	button.set_meta("ui_fx_wired", true)
	button.mouse_entered.connect(_on_hover.bind(button, true))
	button.mouse_exited.connect(_on_hover.bind(button, false))
	button.focus_entered.connect(_on_hover.bind(button, true))
	button.focus_exited.connect(_on_hover.bind(button, false))
	button.button_down.connect(_on_down.bind(button))
	button.pressed.connect(func() -> void: Audio.play("click"))


static func _on_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if hovered and button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	if hovered and button.scale == Vector2.ONE:
		Audio.play("hover")
	var tween := button.create_tween()
	tween.tween_property(button, "scale", HOVER_SCALE if hovered else Vector2.ONE, 0.08)


static func _on_down(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(button, "scale", HOVER_SCALE, 0.08)


## Fades a full-screen control in from transparent.
static func fade_in(control: CanvasItem, duration: float = 0.2) -> void:
	control.modulate.a = 0.0
	control.visible = true
	control.create_tween().tween_property(control, "modulate:a", 1.0, duration)
