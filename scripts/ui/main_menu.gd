extends Control
## Title screen: Start Game / Settings / Exit over a slowly panning jungle.

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_menu: Control = %SettingsMenu
@onready var background: TextureRect = %Background
@onready var title: Control = %Title
@onready var parade: Node2D = %Parade

var _time := 0.0


func _ready() -> void:
	Game.set_state(Game.State.MAIN_MENU)
	start_button.pressed.connect(Game.start_new_run)
	settings_button.pressed.connect(settings_menu.open)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	settings_menu.closed.connect(func() -> void: settings_button.grab_focus())
	UIFx.wire_buttons(self)
	start_button.grab_focus()
	Audio.play_music()
	var index := 0
	for child in parade.get_children():
		child.set_meta("base_y", child.position.y)
		child.set_meta("phase", index * 1.3)
		index += 1


func _process(delta: float) -> void:
	_time += delta
	# Slow back-and-forth pan of the background + floating title.
	var overflow := background.size.x - size.x
	background.position.x = -overflow * (0.5 + 0.5 * sin(_time * 0.08))
	title.position.y = sin(_time * 1.6) * 4.0
	for child in parade.get_children():
		if child is Node2D:
			var phase: float = child.get_meta("phase", 0.0)
			child.position.y = child.get_meta("base_y") - absf(sin(_time * 5.0 + phase)) * 3.0
