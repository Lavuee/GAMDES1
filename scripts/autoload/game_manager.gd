extends Node
## Central run state for ABANTE (autoload "Game").
##
## Holds everything that must survive level changes: hearts, coins, score,
## weapon, time survived and the current game state. Gameplay nodes call into
## this script; UI listens to its signals.

enum State { MAIN_MENU, PLAYING, PAUSED, WEAPON_SHOP, LEVEL_TRANSITION, GAME_OVER, VICTORY }

signal state_changed(new_state: State)
signal health_changed(half_hearts: int, max_half_hearts: int)
signal player_damaged(amount_half_hearts: int)
signal player_died
signal coins_changed(coins: int)
signal score_changed(score: int)
signal score_popup(amount: int, world_position: Vector2)
signal weapon_changed(weapon_id: String, uses: int)
signal weapon_broken
signal shop_requested(from_weapon_break: bool)
signal level_started(level_number: int)
signal enemies_remaining_changed(remaining: int, total: int)
signal level_cleared(level_number: int)
signal run_won
signal toast(message: String)

const GAME_SCENE := "res://scenes/game/game.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LEVEL_SCENES: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]

## Hearts are stored as half-heart units: 10 hearts = 20 halves.
const MAX_HALF_HEARTS := 20
const STARTING_COINS := 0
const SURVIVAL_INTERVAL := 5.0
const SURVIVAL_POINTS := 5
const LEVEL_CLEAR_BONUS := 50
## Small delay after the 7th swing so the final hit lands before the shop opens.
const WEAPON_BREAK_DELAY := 0.3

var state: State = State.MAIN_MENU

var half_hearts := MAX_HALF_HEARTS
var coins := STARTING_COINS
var score := 0
var total_coins_collected := 0
var time_survived := 0.0
var current_level := 1
var highest_level := 1

var weapon_id := WeaponCatalog.UNARMED
var weapon_uses := 0

var enemies_total := 0
var enemies_remaining := 0

var _survival_accumulator := 0.0
var _state_before_pause: State = State.PLAYING
var _run_started := false


func _ready() -> void:
	# Run-state bookkeeping must keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_survived += delta
	_survival_accumulator += delta
	while _survival_accumulator >= SURVIVAL_INTERVAL:
		_survival_accumulator -= SURVIVAL_INTERVAL
		add_score(SURVIVAL_POINTS)


# ---------------------------------------------------------------------------
# Run lifecycle
# ---------------------------------------------------------------------------

## Resets every piece of run data. Does not change scenes.
func reset_run() -> void:
	half_hearts = MAX_HALF_HEARTS
	coins = STARTING_COINS
	score = 0
	total_coins_collected = 0
	time_survived = 0.0
	_survival_accumulator = 0.0
	current_level = 1
	highest_level = 1
	weapon_id = WeaponCatalog.DEFAULT_WEAPON
	weapon_uses = WeaponCatalog.get_info(WeaponCatalog.DEFAULT_WEAPON).uses
	enemies_total = 0
	enemies_remaining = 0
	_run_started = true
	_emit_all()


## Starts a brand-new run from Level 1 (used by Start, Restart and Play Again).
func start_new_run() -> void:
	reset_run()
	_set_paused(false)
	_change_scene(GAME_SCENE)


func go_to_main_menu() -> void:
	_run_started = false
	set_state(State.MAIN_MENU)
	_change_scene(MAIN_MENU_SCENE)


func get_level_scene_path(level_number: int) -> String:
	var index := clampi(level_number, 1, LEVEL_SCENES.size()) - 1
	return LEVEL_SCENES[index]


func is_last_level() -> bool:
	return current_level >= LEVEL_SCENES.size()


## Called by a level once it is ready. `ground_enemy_count` excludes birds.
func begin_level(level_number: int, ground_enemy_count: int) -> void:
	if not _run_started:
		# Level scene launched directly from the editor (F6): make a fresh run.
		reset_run()
	current_level = level_number
	highest_level = maxi(highest_level, level_number)
	enemies_total = ground_enemy_count
	enemies_remaining = ground_enemy_count
	set_state(State.PLAYING)
	level_started.emit(current_level)
	enemies_remaining_changed.emit(enemies_remaining, enemies_total)


## Moves to the next level number. Returns false when the run is complete.
func advance_level() -> bool:
	if is_last_level():
		return false
	current_level += 1
	highest_level = maxi(highest_level, current_level)
	return true


func on_ground_enemy_defeated() -> void:
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	enemies_remaining = maxi(enemies_remaining - 1, 0)
	enemies_remaining_changed.emit(enemies_remaining, enemies_total)
	if enemies_remaining == 0:
		add_score(LEVEL_CLEAR_BONUS)
		level_cleared.emit(current_level)


func finish_run_victory() -> void:
	highest_level = LEVEL_SCENES.size()
	set_state(State.VICTORY)
	run_won.emit()


# ---------------------------------------------------------------------------
# State / pausing
# ---------------------------------------------------------------------------

func set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.PLAYING, State.MAIN_MENU:
			_set_paused(false)
		State.PAUSED, State.WEAPON_SHOP, State.LEVEL_TRANSITION, State.GAME_OVER, State.VICTORY:
			_set_paused(true)
	state_changed.emit(state)


func is_playing() -> bool:
	return state == State.PLAYING


func toggle_pause() -> void:
	if state == State.PLAYING:
		_state_before_pause = state
		set_state(State.PAUSED)
	elif state == State.PAUSED:
		set_state(_state_before_pause)


func _set_paused(value: bool) -> void:
	if is_inside_tree():
		get_tree().paused = value


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

## Applies damage in half-heart units. Hearts never regenerate during a run.
func damage_player(amount_half_hearts: int) -> void:
	if state != State.PLAYING or amount_half_hearts <= 0:
		return
	half_hearts = maxi(half_hearts - amount_half_hearts, 0)
	player_damaged.emit(amount_half_hearts)
	health_changed.emit(half_hearts, MAX_HALF_HEARTS)
	if half_hearts == 0:
		set_state(State.GAME_OVER)
		player_died.emit()


func get_hearts() -> float:
	return half_hearts / 2.0


## "7.5" style text for a half-heart amount.
static func format_hearts(amount_half_hearts: int) -> String:
	if amount_half_hearts % 2 == 0:
		return str(amount_half_hearts / 2)
	return "%d.5" % (amount_half_hearts / 2)


# ---------------------------------------------------------------------------
# Coins & score (kept separate: spending coins never lowers the score)
# ---------------------------------------------------------------------------

func collect_coin(score_value: int, world_position: Vector2 = Vector2.ZERO) -> void:
	coins += 1
	total_coins_collected += 1
	coins_changed.emit(coins)
	add_score(score_value)
	score_popup.emit(score_value, world_position)


func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount
	score_changed.emit(score)


# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

func is_armed() -> bool:
	return weapon_id != WeaponCatalog.UNARMED and weapon_uses > 0


func get_weapon_damage() -> int:
	return WeaponCatalog.get_damage(weapon_id) if is_armed() else 0


func can_afford(weapon_id_to_check: String) -> bool:
	var info := WeaponCatalog.get_info(weapon_id_to_check)
	return not info.is_empty() and info.purchasable and coins >= info.cost


func can_afford_any() -> bool:
	for id in WeaponCatalog.ORDER:
		if can_afford(id):
			return true
	return false


## Spends one use for a swing that was actually performed.
## Returns false if no swing is possible (unarmed / not playing).
func consume_weapon_use() -> bool:
	if state != State.PLAYING or not is_armed():
		return false
	weapon_uses -= 1
	weapon_changed.emit(weapon_id, weapon_uses)
	if weapon_uses <= 0:
		_break_weapon()
	return true


func _break_weapon() -> void:
	weapon_id = WeaponCatalog.UNARMED
	weapon_uses = 0
	weapon_changed.emit(weapon_id, weapon_uses)
	# Timer respects pause, so the shop never opens over another menu.
	var timer := get_tree().create_timer(WEAPON_BREAK_DELAY, false)
	timer.timeout.connect(func() -> void:
		if state == State.PLAYING:
			weapon_broken.emit()
			shop_requested.emit(true)
	)


## Player asked to open the shop while unarmed (B key / attack with no weapon).
func request_shop() -> void:
	if state != State.PLAYING:
		return
	if is_armed():
		toast.emit("You already have a weapon (%d uses left)." % weapon_uses)
		return
	shop_requested.emit(false)


## Attempts to buy a weapon. Returns true on success.
func buy_weapon(id: String) -> bool:
	if not WeaponCatalog.has_weapon(id):
		push_warning("buy_weapon: unknown weapon '%s'" % id)
		return false
	var info := WeaponCatalog.get_info(id)
	if not info.purchasable:
		return false
	if coins < info.cost:
		return false
	coins -= info.cost
	coins_changed.emit(coins)
	weapon_id = id
	weapon_uses = info.uses
	weapon_changed.emit(weapon_id, weapon_uses)
	return true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _emit_all() -> void:
	health_changed.emit(half_hearts, MAX_HALF_HEARTS)
	coins_changed.emit(coins)
	score_changed.emit(score)
	weapon_changed.emit(weapon_id, weapon_uses)


func _change_scene(path: String) -> void:
	# Deferred so we never swap scenes in the middle of a physics callback.
	get_tree().call_deferred("change_scene_to_file", path)


## Safety net: guarantees the gameplay actions exist even if project.godot
## input settings were lost or edited.
func _ensure_input_actions() -> void:
	var defaults := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"attack": [KEY_J, KEY_K],
		"pause": [KEY_ESCAPE, KEY_P],
		"open_shop": [KEY_B],
	}
	for action in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in defaults[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
