extends SceneTree
## Boots the real main scene, presses START GAME, and confirms Level 1 loads.
## godot --headless --path . --script res://tests/launch_check.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(main_path)
	for i in 30:
		await process_frame
	print("main scene: ", current_scene.name if current_scene else "<none>")
	var start: Button = current_scene.get_node("%StartButton")
	start.pressed.emit()
	for i in 90:
		await physics_frame
	var game_manager := root.get_node("Game")
	print("after start: scene=", current_scene.name, " state=", game_manager.State.keys()[game_manager.state], " level=", game_manager.current_level, " hearts=", game_manager.half_hearts / 2.0, " weapon=", game_manager.weapon_id, " uses=", game_manager.weapon_uses)
	quit(0 if current_scene.name == "GameScene" and game_manager.state == game_manager.State.PLAYING else 1)
