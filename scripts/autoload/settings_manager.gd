extends Node
## Player settings (autoload "Settings"): bus volumes and fullscreen.
## Settings are saved to user://settings.cfg (this is not run progression).

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]

var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8}
var fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_all()


func get_volume(bus_name: String) -> float:
	return volumes.get(bus_name, 1.0)


func set_volume(bus_name: String, linear: float) -> void:
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus_name)
	_save()
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_save()
	settings_changed.emit()


func apply_all() -> void:
	for bus_name in BUSES:
		_apply_bus(bus_name)
	_apply_fullscreen()


func _apply_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = volumes.get(bus_name, 1.0)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for bus_name in BUSES:
		volumes[bus_name] = clampf(float(config.get_value("audio", bus_name, volumes[bus_name])), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", false))


func _save() -> void:
	var config := ConfigFile.new()
	for bus_name in BUSES:
		config.set_value("audio", bus_name, volumes[bus_name])
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SAVE_PATH)
