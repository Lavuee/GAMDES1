extends Control
## Pause overlay: Resume / Settings / Restart / Main Menu.

signal resume_requested
signal settings_requested

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	restart_button.pressed.connect(Game.start_new_run)
	menu_button.pressed.connect(Game.go_to_main_menu)
	UIFx.wire_buttons(self)


func open() -> void:
	UIFx.fade_in(self, 0.12)
	resume_button.grab_focus()


func close() -> void:
	visible = false


func focus_default() -> void:
	settings_button.grab_focus()
