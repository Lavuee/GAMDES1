extends Node
## Konami-code cheat (autoload "Cheats").
## Type  UP UP DOWN DOWN LEFT RIGHT LEFT RIGHT B A  at any time to toggle:
##   - unlimited health (player takes no damage)
##   - one-hit kills (every successful hit defeats a ground enemy)
## Typing the code again turns the cheat off.

signal cheat_toggled(enabled: bool)

const SEQUENCE: Array[Key] = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	KEY_B, KEY_A,
]

var enabled := false
var _progress := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_god_mode() -> bool:
	return enabled


func is_one_hit() -> bool:
	return enabled


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == SEQUENCE[_progress]:
		_progress += 1
		if _progress == SEQUENCE.size():
			_progress = 0
			set_enabled(not enabled)
	else:
		# Restart, but keep any UPs just typed (e.g. "UP UP UP DOWN..." still works).
		if code == KEY_UP:
			_progress = 2 if _progress >= 2 else 1
		else:
			_progress = 0


func set_enabled(value: bool) -> void:
	enabled = value
	cheat_toggled.emit(enabled)
	if enabled:
		Audio.play("victory")
		Game.toast.emit("CHEAT ON: UNLIMITED HEALTH + 1-HIT KILLS")
	else:
		Audio.play("denied")
		Game.toast.emit("CHEAT OFF")
