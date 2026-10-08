extends Node
## Visual check: renders key screens and saves PNGs.
## Run (windowed, not headless):
##   godot --path . res://tests/screenshot_tour.tscn -- <output_dir>

var _out_dir := "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await _tour()
	get_tree().paused = false
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(name + ".png"))
	print("saved ", name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _tour() -> void:
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _wait(0.6)
	await _shot("01_main_menu")
	menu.get_node("%SettingsMenu").open()
	await _wait(0.4)
	await _shot("02_settings")
	menu.queue_free()

	Game.reset_run()
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _wait(0.6)
	await _shot("03_level1_intro")
	await _wait(2.0)
	var level: Level = game.get_node("LevelContainer").get_child(0)
	await _shot("04_level1_start")
	level.player.global_position = Vector2(640, 470)
	level.player.camera.reset_smoothing()
	await _wait(0.8)
	await _shot("05_level1_platforms")
	level.player.global_position = Vector2(1500, 360)
	level.player.camera.reset_smoothing()
	Input.action_press("attack")
	await get_tree().physics_frame
	Input.action_release("attack")
	await _wait(0.08)
	await _shot("06_level1_attack_crumble")

	Game.coins = 12
	Game.weapon_uses = 1
	Game.consume_weapon_use()
	await _wait(0.7)
	await _shot("07_weapon_shop")
	game.get_node("UI/WeaponShop")._on_buy_pressed("weapon_2")
	await _wait(0.3)
	await _shot("08_after_purchase")
	Game.toggle_pause()
	game.get_node("UI/PauseMenu").open()
	await _wait(0.3)
	await _shot("09_pause")
	game.get_node("UI/PauseMenu").resume_requested.emit()
	game.queue_free()
	await get_tree().process_frame

	for level_number in [2, 3]:
		Game.reset_run()
		Game.current_level = level_number
		game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
		add_child(game)
		await _wait(2.6)
		level = game.get_node("LevelContainer").get_child(0)
		level.player.hurtbox.monitoring = false
		var spot := 900.0 if level_number == 2 else 1250.0
		level.player.global_position = Vector2(spot, 470)
		level.player.camera.reset_smoothing()
		await _wait(0.7)
		await _shot("1%d_level%d" % [level_number, level_number])
		game.queue_free()
		await get_tree().process_frame

	Game.reset_run()
	game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _wait(0.5)
	Game.damage_player(20)
	await _wait(1.6)
	await _shot("20_game_over")
	game.queue_free()
