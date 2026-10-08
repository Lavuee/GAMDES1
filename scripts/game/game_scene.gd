extends Node
## Gameplay root. Loads the current level into LevelContainer and owns the
## in-game overlays (HUD, pause, settings, weapon shop, transitions, results).
## Run data lives in the Game autoload, so swapping levels never resets it.

## Grace period after the last ground enemy dies (lets the player grab the drop).
const LEVEL_CLEAR_GRACE := 1.5
const GAME_OVER_DELAY := 1.0

@onready var level_container: Node2D = $LevelContainer
@onready var hud: Control = $UI/HUD
@onready var pause_menu: Control = $UI/PauseMenu
@onready var settings_menu: Control = $UI/SettingsMenu
@onready var weapon_shop: Control = $UI/WeaponShop
@onready var transition: Control = $UI/LevelTransition
@onready var results: Control = $UI/ResultsScreen

var _level: Level


func _ready() -> void:
	# Must keep receiving the pause key while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_container.process_mode = Node.PROCESS_MODE_PAUSABLE

	Game.level_cleared.connect(_on_level_cleared)
	Game.shop_requested.connect(_on_shop_requested)
	Game.player_died.connect(_on_player_died)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.settings_requested.connect(_open_settings)
	settings_menu.closed.connect(_on_settings_closed)
	weapon_shop.closed.connect(_on_shop_closed)

	Audio.play_music()
	_load_level(Game.current_level)
	transition.show_intro(Game.current_level, _level.level_title if _level else "")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	match Game.state:
		Game.State.PLAYING:
			get_viewport().set_input_as_handled()
			Game.toggle_pause()
			pause_menu.open()
		Game.State.PAUSED:
			if settings_menu.visible:
				return # settings menu closes itself
			get_viewport().set_input_as_handled()
			_resume()


func _load_level(level_number: int) -> void:
	for child in level_container.get_children():
		# Remove right away so the old player/enemies never overlap the new level.
		level_container.remove_child(child)
		child.queue_free()
	_level = null
	var path := Game.get_level_scene_path(level_number)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not load level scene: %s" % path)
		Game.go_to_main_menu()
		return
	_level = packed.instantiate() as Level
	level_container.add_child(_level)


# ---------------------------------------------------------------------------
# Pause / settings
# ---------------------------------------------------------------------------

func _resume() -> void:
	pause_menu.close()
	settings_menu.visible = false
	if Game.state == Game.State.PAUSED:
		Game.toggle_pause()


func _open_settings() -> void:
	settings_menu.open()


func _on_settings_closed() -> void:
	if pause_menu.visible:
		pause_menu.focus_default()


# ---------------------------------------------------------------------------
# Weapon shop
# ---------------------------------------------------------------------------

func _on_shop_requested(from_weapon_break: bool) -> void:
	if Game.state != Game.State.PLAYING:
		return
	Game.set_state(Game.State.WEAPON_SHOP)
	weapon_shop.open(from_weapon_break)


func _on_shop_closed(purchased_weapon_id: String) -> void:
	if Game.state == Game.State.WEAPON_SHOP:
		Game.set_state(Game.State.PLAYING)
	if purchased_weapon_id != WeaponCatalog.UNARMED:
		hud.show_toast("EQUIPPED %s!  7 USES" % WeaponCatalog.get_display_name(purchased_weapon_id), Color(0.6, 1.0, 0.6))
	else:
		hud.show_toast("UNARMED - collect coins and press B", Color(1.0, 0.7, 0.5))


# ---------------------------------------------------------------------------
# Level flow
# ---------------------------------------------------------------------------

func _on_level_cleared(level_number: int) -> void:
	Audio.play("level_complete")
	hud.show_toast("LEVEL CLEAR!  +%d" % Game.LEVEL_CLEAR_BONUS, Color(0.6, 1.0, 0.6))
	# Pausable timer: freezes if the shop or pause menu opens meanwhile.
	await get_tree().create_timer(LEVEL_CLEAR_GRACE, false).timeout
	if Game.state == Game.State.GAME_OVER:
		return
	# Close any overlay that might have been left open.
	pause_menu.close()
	settings_menu.visible = false
	weapon_shop.visible = false
	Game.set_state(Game.State.LEVEL_TRANSITION)

	await transition.play_level_complete(level_number)
	if Game.advance_level():
		_load_level(Game.current_level)
		transition.show_intro(Game.current_level, _level.level_title if _level else "")
		Game.set_state(Game.State.PLAYING)
	else:
		Audio.stop_music()
		Audio.play("victory")
		Game.finish_run_victory()
		transition.reveal()
		results.show_victory()


func _on_player_died() -> void:
	Audio.stop_music()
	Audio.play("game_over")
	hud.show_toast("YOU FELL...", Color(1.0, 0.4, 0.35))
	await get_tree().create_timer(GAME_OVER_DELAY, true).timeout
	pause_menu.close()
	weapon_shop.visible = false
	results.show_game_over()
