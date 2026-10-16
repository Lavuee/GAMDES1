extends Control
## In-game HUD: hearts (half-heart precision), level, enemies left, time,
## coins, score, current weapon + uses, and short toast messages.

const HEART_FULL := preload("res://assets/sprites/abante/heart_full.png")
const HEART_HALF := preload("res://assets/sprites/abante/heart_half.png")
const HEART_SLOT_SIZE := Vector2(24, 24)
const EMPTY_HEART_COLOR := Color(0.15, 0.15, 0.2, 0.55)
const USE_PIP_ON := Color(1.0, 0.82, 0.3)
const USE_PIP_OFF := Color(0.25, 0.27, 0.3)

@onready var hearts_row: HBoxContainer = %Hearts
@onready var hearts_label: Label = %HeartsLabel
@onready var level_label: Label = %LevelLabel
@onready var info_label: Label = %InfoLabel
@onready var coins_label: Label = %CoinsLabel
@onready var score_label: Label = %ScoreLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_name_label: Label = %WeaponName
@onready var uses_row: HBoxContainer = %UsesRow
@onready var uses_label: Label = %UsesLabel
@onready var weapon_hint: Label = %WeaponHint
@onready var toast_label: Label = %Toast
@onready var damage_flash: ColorRect = %DamageFlash

var _heart_slots: Array[TextureRect] = []
var _toast_tween: Tween
var _enemies_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_heart_slots()
	toast_label.modulate.a = 0.0
	damage_flash.color.a = 0.0

	Game.health_changed.connect(_on_health_changed)
	Game.player_damaged.connect(_on_player_damaged)
	Game.coins_changed.connect(_on_coins_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.weapon_changed.connect(_on_weapon_changed)
	Game.level_started.connect(_on_level_started)
	Game.enemies_remaining_changed.connect(_on_enemies_changed)
	Game.toast.connect(show_toast)
	Cheats.cheat_toggled.connect(func(_on: bool) -> void: _on_health_changed(Game.half_hearts, Game.MAX_HALF_HEARTS))

	_on_health_changed(Game.half_hearts, Game.MAX_HALF_HEARTS)
	_on_coins_changed(Game.coins)
	_on_score_changed(Game.score)
	_on_weapon_changed(Game.weapon_id, Game.weapon_uses)
	_on_level_started(Game.current_level)


func _process(_delta: float) -> void:
	info_label.text = "%s   %s" % [_enemies_text, Game.format_time(Game.time_survived)]


func _build_heart_slots() -> void:
	for child in hearts_row.get_children():
		child.queue_free()
	_heart_slots.clear()
	for i in Game.MAX_HALF_HEARTS / 2:
		var slot := TextureRect.new()
		slot.custom_minimum_size = HEART_SLOT_SIZE
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hearts_row.add_child(slot)
		_heart_slots.append(slot)


func _on_health_changed(half_hearts: int, max_half_hearts: int) -> void:
	for i in _heart_slots.size():
		var slot := _heart_slots[i]
		var remaining := half_hearts - i * 2
		if remaining >= 2:
			slot.texture = HEART_FULL
			slot.modulate = Color.WHITE
		elif remaining == 1:
			slot.texture = HEART_HALF
			slot.modulate = Color.WHITE
		else:
			slot.texture = HEART_FULL
			slot.modulate = EMPTY_HEART_COLOR
	hearts_label.text = "HEARTS  %s / %d" % [Game.format_hearts(half_hearts), max_half_hearts / 2]
	if Cheats.enabled:
		hearts_label.text += "   [CHEAT]"



func _on_player_damaged(amount_half_hearts: int) -> void:
	damage_flash.color.a = 0.35
	create_tween().tween_property(damage_flash, "color:a", 0.0, 0.4)
	# Shake the heart row.
	var tween := create_tween()
	var base := hearts_row.position
	for i in 4:
		tween.tween_property(hearts_row, "position", base + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.04)
	tween.tween_property(hearts_row, "position", base, 0.04)
	show_toast("-%s HEARTS" % Game.format_hearts(amount_half_hearts), Color(1.0, 0.45, 0.4))


func _on_coins_changed(coins: int) -> void:
	coins_label.text = "x %d" % coins
	_pulse(coins_label)
	_refresh_weapon_hint()


func _on_score_changed(score: int) -> void:
	score_label.text = "SCORE  %d" % score
	_pulse(score_label)


func _on_weapon_changed(weapon_id: String, uses: int) -> void:
	var armed := weapon_id != WeaponCatalog.UNARMED
	weapon_icon.texture = WeaponCatalog.get_icon(weapon_id) if armed else null
	weapon_name_label.text = WeaponCatalog.get_display_name(weapon_id)
	weapon_name_label.modulate = Color.WHITE if armed else Color(1.0, 0.5, 0.45)
	var max_uses: int = WeaponCatalog.get_info(weapon_id).get("uses", 7) if armed else 7
	for child in uses_row.get_children():
		child.queue_free()
	for i in max_uses:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 8)
		pip.color = USE_PIP_ON if (armed and i < uses) else USE_PIP_OFF
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		uses_row.add_child(pip)
	if armed:
		var hits: int = WeaponCatalog.get_info(weapon_id).get("hits", 0)
		uses_label.text = "USES %d / %d   ·   %d HITS / ENEMY" % [uses, max_uses, hits]
	else:
		uses_label.text = "NO WEAPON"
	_refresh_weapon_hint()


func _refresh_weapon_hint() -> void:
	if Game.is_armed():
		weapon_hint.text = ""
		return
	var cheapest := WeaponCatalog.cheapest_cost()
	if Game.coins >= cheapest:
		weapon_hint.text = "Press B to buy a weapon!"
		weapon_hint.modulate = Color(0.6, 1.0, 0.6)
	else:
		weapon_hint.text = "Collect %d more coins, then press B" % (cheapest - Game.coins)
		weapon_hint.modulate = Color(1.0, 0.75, 0.5)


func _on_level_started(level_number: int) -> void:
	level_label.text = "LEVEL %d" % level_number


func _on_enemies_changed(remaining: int, total: int) -> void:
	_enemies_text = "ENEMIES %d / %d" % [remaining, total]


func show_toast(message: String, color: Color = Color(1.0, 0.95, 0.75)) -> void:
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	toast_label.scale = Vector2(1.15, 1.15)
	toast_label.pivot_offset = toast_label.size * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "scale", Vector2.ONE, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.15)
