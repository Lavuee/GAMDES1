extends Node
## Automated gameplay validation. Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 when every check passes, 1 otherwise.

var _passed := 0
var _failed := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run_all()
	print("\n==== RESULT: %d passed, %d failed ====" % [_passed, _failed])
	get_tree().paused = false
	get_tree().quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


func _run_all() -> void:
	_test_run_reset()
	_test_health()
	_test_coins_and_score()
	await _test_weapons()
	_test_shop_rules()
	_test_enemy_hits()
	_test_survival_score()
	await _test_levels_content()
	await _test_disappearing_platform()
	await _test_full_game_loop()
	await _test_game_over_and_restart_state()


func _test_run_reset() -> void:
	print("[Run reset]")
	Game.reset_run()
	check(Game.half_hearts == 20, "starts with 10 hearts (20 halves)")
	check(Game.weapon_id == "default" and Game.weapon_uses == 7, "starts with default weapon, 7 uses")
	check(Game.coins == 0 and Game.score == 0, "starts with 0 coins / 0 score")
	check(Game.current_level == 1, "starts on level 1")


func _test_health() -> void:
	print("[Health]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	Game.damage_player(3)
	check(Game.half_hearts == 17, "crocodile = -1.5 hearts")
	Game.damage_player(6)
	check(Game.half_hearts == 11, "snake = -3 hearts")
	Game.damage_player(10)
	check(Game.half_hearts == 1, "bird = -5 hearts")
	check(Game.state == Game.State.PLAYING, "still alive at 0.5 hearts")
	Game.damage_player(3)
	check(Game.half_hearts == 0 and Game.state == Game.State.GAME_OVER, "game over when hearts reach 0")
	Game.damage_player(3)
	check(Game.half_hearts == 0, "no further damage after game over")


func _test_coins_and_score() -> void:
	print("[Coins & score]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	Game.collect_coin(1)
	check(Game.coins == 1 and Game.score == 1, "ground coin = +1 coin, +1 score")
	Game.collect_coin(2)
	check(Game.coins == 2 and Game.score == 3, "upper coin = +1 coin, +2 score")
	for i in 8:
		Game.collect_coin(1)
	var score_before := Game.score
	Game.weapon_id = WeaponCatalog.UNARMED
	Game.weapon_uses = 0
	check(Game.buy_weapon("weapon_1"), "buy weapon 1 with 10 coins")
	check(Game.coins == 5, "coins reduced by 5")
	check(Game.score == score_before, "spending coins does not reduce score")
	check(Game.total_coins_collected == 10, "total coins collected tracked separately")


func _test_weapons() -> void:
	print("[Weapons]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	var broken := [false]
	var on_broken := func() -> void: broken[0] = true
	Game.weapon_broken.connect(on_broken)
	for i in 6:
		Game.consume_weapon_use()
	check(Game.weapon_uses == 1 and Game.is_armed(), "6 swings leave 1 use")
	Game.consume_weapon_use()
	check(not Game.is_armed() and Game.weapon_id == WeaponCatalog.UNARMED, "weapon breaks exactly after 7 uses")
	await get_tree().create_timer(Game.WEAPON_BREAK_DELAY + 0.1).timeout
	check(broken[0], "weapon_broken signal fires")
	check(not Game.consume_weapon_use(), "unarmed: no swing possible")
	check(Game.weapon_id != "default", "default weapon not restored automatically")
	Game.weapon_broken.disconnect(on_broken)

	for id in ["weapon_1", "weapon_2", "weapon_best"]:
		var info := WeaponCatalog.get_info(id)
		check(info.uses == 7, "%s has 7 uses" % id)
	check(WeaponCatalog.get_info("weapon_1").cost == 5 and WeaponCatalog.get_info("weapon_1").hits == 4, "weapon 1 = 5 coins / 4 hits")
	check(WeaponCatalog.get_info("weapon_2").cost == 10 and WeaponCatalog.get_info("weapon_2").hits == 3, "weapon 2 = 10 coins / 3 hits")
	check(WeaponCatalog.get_info("weapon_best").cost == 15 and WeaponCatalog.get_info("weapon_best").hits == 2, "best = 15 coins / 2 hits")
	check(WeaponCatalog.get_info("default").hits == 5, "default = 5 hits")


func _test_shop_rules() -> void:
	print("[Shop rules]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	Game.weapon_id = WeaponCatalog.UNARMED
	Game.weapon_uses = 0
	check(not Game.buy_weapon("default"), "default weapon cannot be bought")
	check(not Game.buy_weapon("weapon_1"), "cannot buy with 0 coins")
	check(not Game.buy_weapon("nonexistent"), "invalid weapon rejected")
	check(not Game.can_afford_any(), "nothing affordable at 0 coins")
	Game.coins = 15
	check(Game.can_afford("weapon_1") and Game.can_afford("weapon_2") and Game.can_afford("weapon_best"), "15 coins: all three affordable")
	check(Game.buy_weapon("weapon_best"), "buy best first (no upgrade order)")
	check(Game.coins == 0 and Game.weapon_uses == 7, "best weapon equipped with 7 uses")
	for i in 7:
		Game.consume_weapon_use()
	Game.coins = 15
	check(Game.buy_weapon("weapon_best"), "same weapon can be bought again")
	Game.coins = 4
	check(not Game.can_afford("weapon_1"), "4 coins: weapon 1 unaffordable")


func _test_enemy_hits() -> void:
	print("[Enemy health vs weapon]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	var croc_scene := load("res://scenes/enemies/crocodile.tscn") as PackedScene
	for id in ["default", "weapon_1", "weapon_2", "weapon_best"]:
		var croc := croc_scene.instantiate() as GroundEnemy
		add_child(croc)
		var damage := WeaponCatalog.get_damage(id)
		var hits := 0
		while not croc.is_dead and hits < 20:
			croc.take_hit(damage, croc.global_position.x - 10.0)
			hits += 1
		check(hits == WeaponCatalog.get_info(id).hits, "%s defeats enemy in %d hits" % [id, hits])
		croc.queue_free()
	var bird := (load("res://scenes/enemies/bird.tscn") as PackedScene).instantiate()
	var has_hurtbox := false
	for area in bird.find_children("*", "Area2D", true, false):
		if (area as Area2D).get_collision_layer_value(6):
			has_hurtbox = true
	check(not has_hurtbox and not bird.has_method("take_hit"), "bird cannot be attacked")
	check(bird.get_node("DamageArea").damage_half_hearts == 10, "bird deals 5 hearts")
	bird.free()


func _test_survival_score() -> void:
	print("[Survival score]")
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	Game._process(4.9)
	check(Game.score == 0, "no survival points before 5 s")
	Game._process(0.2)
	check(Game.score == 5, "+5 score after 5 s alive")
	Game._process(10.0)
	check(Game.score == 15, "+5 for every further 5 s")
	Game.set_state(Game.State.PAUSED)
	Game._process(10.0)
	check(Game.score == 15, "timer stops while paused")
	Game.set_state(Game.State.PLAYING)


func _test_levels_content() -> void:
	print("[Level content]")
	var expectations := {
		1: {"croc": true, "snake": false, "bird": false},
		2: {"croc": true, "snake": true, "bird": false},
		3: {"croc": true, "snake": true, "bird": true},
	}
	var croc_speeds := []
	var snake_speeds := []
	for level_number in [1, 2, 3]:
		var level := (load(Game.get_level_scene_path(level_number)) as PackedScene).instantiate()
		var crocs := 0
		var snakes := 0
		var birds := level.get_node("Hazards").get_child_count()
		for enemy in level.get_node("Enemies").get_children():
			if enemy.name.begins_with("Crocodile"):
				crocs += 1
			elif enemy.name.begins_with("Snake"):
				snakes += 1
		var expected: Dictionary = expectations[level_number]
		check((crocs > 0) == expected.croc and (snakes > 0) == expected.snake and (birds > 0) == expected.bird,
			"level %d: %d crocodiles, %d snakes, %d birds" % [level_number, crocs, snakes, birds])
		var stable := 0
		var crumble := 0
		for p in level.get_node("Platforms").get_children():
			if p is DisappearingPlatform:
				crumble += 1
			else:
				stable += 1
		check(stable > 0 and crumble > 0, "level %d has stable (%d) and disappearing (%d) platforms" % [level_number, stable, crumble])
		var coin_count := level.get_node("Coins").get_child_count()
		check(coin_count >= 20, "level %d has %d coins" % [level_number, coin_count])
		Game.current_level = level_number
		add_child(level) # runs Level._ready -> begin_level
		await get_tree().physics_frame
		check(Game.enemies_total == crocs + snakes, "level %d clear counter = %d ground enemies (birds excluded)" % [level_number, Game.enemies_total])
		for enemy in level.get_node("Enemies").get_children():
			if enemy.name.begins_with("Crocodile"):
				croc_speeds.append(enemy._speed)
				break
		for enemy in level.get_node("Enemies").get_children():
			if enemy.name.begins_with("Snake"):
				snake_speeds.append(enemy._speed)
				break
		var health_ok := true
		for enemy in level.get_node("Enemies").get_children():
			health_ok = health_ok and enemy.health == WeaponCatalog.ENEMY_MAX_HEALTH
		check(health_ok, "level %d enemy health unchanged (%d)" % [level_number, WeaponCatalog.ENEMY_MAX_HEALTH])
		remove_child(level)
		level.queue_free()
	check(croc_speeds[0] < croc_speeds[1] and croc_speeds[1] < croc_speeds[2], "crocodiles faster each level %s" % [croc_speeds])
	check(snake_speeds[0] < snake_speeds[1], "snakes faster in level 3 %s" % [snake_speeds])


func _test_disappearing_platform() -> void:
	print("[Disappearing platform]")
	Game.set_state(Game.State.PLAYING)
	var platform := (load("res://scenes/world/disappearing_platform.tscn") as PackedScene).instantiate() as DisappearingPlatform
	add_child(platform)
	var shape := platform.get_node("CollisionShape2D") as CollisionShape2D
	platform.on_player_landed()
	await get_tree().create_timer(0.8).timeout
	check(not shape.disabled, "still solid after 0.8 s")
	await get_tree().create_timer(0.35).timeout
	await get_tree().physics_frame
	check(shape.disabled, "gone ~1 s after landing")
	var stable := (load("res://scenes/world/stable_platform.tscn") as PackedScene).instantiate()
	check(not stable.has_method("on_player_landed"), "stable platform never disappears")
	stable.free()
	platform.queue_free()


func _press(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _test_full_game_loop() -> void:
	print("[Full game loop]")
	Game.reset_run()
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	check(Game.state == Game.State.PLAYING and Game.current_level == 1, "game scene starts level 1 in PLAYING")

	var level: Level = game.get_node("LevelContainer").get_child(0)
	var player: Player = level.player
	# Let the player land.
	for i in 30:
		await get_tree().physics_frame
	check(player.is_on_floor(), "player stands on ground")
	var x0 := player.global_position.x
	await _press("move_right", 30)
	check(player.global_position.x > x0 + 50.0, "move right works (%.0f -> %.0f)" % [x0, player.global_position.x])
	var x1 := player.global_position.x
	await _press("move_left", 20)
	check(player.global_position.x < x1, "move left works")
	for i in 20:
		await get_tree().physics_frame
	var y0 := player.global_position.y
	Input.action_press("jump")
	for i in 12:
		await get_tree().physics_frame
	check(player.global_position.y < y0 - 60.0, "jump rises (%.0f px)" % (y0 - player.global_position.y))
	Input.action_release("jump")
	for i in 60:
		await get_tree().physics_frame
	check(player.is_on_floor(), "player lands after jumping")

	var uses_before := Game.weapon_uses
	await _press("attack", 2)
	check(Game.weapon_uses == uses_before - 1, "attack consumes exactly 1 use")
	await _press("move_right", 5)
	await _press("jump", 5)
	check(Game.weapon_uses == uses_before - 1, "moving/jumping does not consume uses")
	for i in 30:
		await get_tree().physics_frame

	# Real combat: place a crocodile in front of the player and swing at it.
	var croc: GroundEnemy = level.get_node("Enemies").get_child(0)
	Game.weapon_id = "weapon_best"
	Game.weapon_uses = 7
	croc.global_position = player.global_position + Vector2(40, 0)
	croc.set_physics_process(false)
	await get_tree().physics_frame
	player.facing = 1
	player.hurtbox.monitoring = false # ignore contact damage for this check
	for i in 2:
		await _press("attack", 2)
		for f in 25:
			await get_tree().physics_frame
	check(croc.is_dead, "best weapon kills crocodile in 2 real swings")
	for i in 40:
		await get_tree().physics_frame
	check(level.get_node("Pickups").get_child_count() > 0, "defeated enemy drops a coin")
	player.hurtbox.monitoring = true

	# Weapon shop opens and freezes the world when the weapon breaks.
	Game.weapon_id = "weapon_1"
	Game.weapon_uses = 1
	await _press("attack", 2)
	await get_tree().create_timer(0.6).timeout
	var shop: Control = game.get_node("UI/WeaponShop")
	check(Game.state == Game.State.WEAPON_SHOP and shop.visible and get_tree().paused, "shop opens + game paused on weapon break")
	Game.coins = 6
	shop._refresh()
	var buy_w1: Button = shop._buttons["weapon_1"].button
	var buy_w2: Button = shop._buttons["weapon_2"].button
	var buy_def: Button = shop._buttons["default"].button
	check(not buy_w1.disabled and buy_w2.disabled and buy_def.disabled, "affordable enabled, unaffordable + default disabled")
	buy_w1.pressed.emit()
	await get_tree().process_frame
	check(Game.state == Game.State.PLAYING and not get_tree().paused and Game.weapon_id == "weapon_1" and Game.weapon_uses == 7 and Game.coins == 1, "purchase equips weapon, resumes game")

	# Pause works.
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.state == Game.State.PAUSED and get_tree().paused, "ESC pauses the game")
	var t_paused := Game.time_survived
	await get_tree().create_timer(0.3).timeout
	check(is_equal_approx(Game.time_survived, t_paused), "time frozen while paused")
	game.get_node("UI/PauseMenu").resume_requested.emit()
	await get_tree().process_frame
	check(Game.state == Game.State.PLAYING and not get_tree().paused, "resume unpauses")

	# Clear every level by defeating all ground enemies.
	var hearts_before := Game.half_hearts
	for level_number in [1, 2, 3]:
		level = game.get_node("LevelContainer").get_child(0)
		check(level.level_number == level_number, "on level %d" % level_number)
		player = level.player
		player.hurtbox.monitoring = false
		for enemy in level.get_node("Enemies").get_children():
			if enemy is GroundEnemy and not enemy.is_dead:
				enemy.take_hit(999, enemy.global_position.x - 5.0)
		await get_tree().physics_frame
		check(Game.enemies_remaining == 0, "level %d: all ground enemies defeated (birds ignored)" % level_number)
		# Wait for grace period + transition.
		var waited := 0.0
		while waited < 8.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
			if level_number < 3 and Game.current_level == level_number + 1 and Game.state == Game.State.PLAYING:
				break
			if level_number == 3 and Game.state == Game.State.VICTORY:
				break
		if level_number < 3:
			check(Game.current_level == level_number + 1, "advanced to level %d" % (level_number + 1))
			check(Game.half_hearts == hearts_before, "hearts carried over, not refilled")
	check(Game.state == Game.State.VICTORY, "victory after level 3")
	check(game.get_node("UI/ResultsScreen").visible, "victory results screen visible")
	check(Game.highest_level == 3, "highest level = 3")
	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_game_over_and_restart_state() -> void:
	print("[Game over / restart]")
	Game.reset_run()
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(0.3).timeout
	Game.coins = 9
	Game.damage_player(20)
	check(Game.state == Game.State.GAME_OVER and get_tree().paused, "hearts 0 -> GAME_OVER, gameplay stopped")
	await get_tree().create_timer(1.3).timeout
	var results: Control = game.get_node("UI/ResultsScreen")
	check(results.visible, "game over results screen shown")
	check(results.get_node("%ScoreValue").text == str(Game.score), "results show final score")
	game.queue_free()
	get_tree().paused = false
	Game.reset_run()
	check(Game.half_hearts == 20 and Game.coins == 0 and Game.score == 0 and Game.weapon_id == "default" and Game.current_level == 1 and Game.time_survived == 0.0, "restart resets hearts/coins/score/weapon/level/timer")
