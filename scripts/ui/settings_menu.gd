extends Control
## Settings overlay used by both the main menu and the pause menu:
## master / music / SFX volume, fullscreen, controls and gameplay tips
## (the tips that used to be shown as signs inside the levels).

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_bind_slider(master_slider, master_value, "Master")
	_bind_slider(music_slider, music_value, "Music")
	_bind_slider(sfx_slider, sfx_value, "SFX")
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	back_button.pressed.connect(close)
	UIFx.wire_buttons(self)


func _bind_slider(slider: HSlider, value_label: Label, bus_name: String) -> void:
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = Settings.get_volume(bus_name) * 100.0
	value_label.text = "%d%%" % slider.value
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_volume(bus_name, value / 100.0)
		value_label.text = "%d%%" % value
		if bus_name != "Music":
			Audio.play("hover")
	)


func open() -> void:
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	UIFx.fade_in(self, 0.15)
	master_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
