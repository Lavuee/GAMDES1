extends Control
## Weapon shop overlay. Opens automatically when a weapon breaks (world is
## frozen) or when an unarmed player presses B. Any affordable weapon can be
## bought in any order; the default weapon is only free at the start of a run.

signal closed(purchased_weapon_id: String)

const AFFORDABLE_BORDER := Color(0.95, 0.75, 0.3)
const UNAFFORDABLE_BORDER := Color(0.3, 0.32, 0.36)

@onready var title_label: Label = %ShopTitle
@onready var subtitle_label: Label = %ShopSubtitle
@onready var cards_row: HBoxContainer = %Cards
@onready var coins_label: Label = %ShopCoins
@onready var message_label: Label = %ShopMessage
@onready var leave_button: Button = %LeaveButton

var _buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	leave_button.pressed.connect(_on_leave_pressed)
	_build_cards()
	UIFx.wire_buttons(self)


## `from_weapon_break` changes the heading text.
func open(from_weapon_break: bool) -> void:
	title_label.text = "WEAPON BROKEN!" if from_weapon_break else "WEAPON SHOP"
	if from_weapon_break:
		Audio.play("weapon_break")
	_refresh()
	UIFx.fade_in(self, 0.15)
	_focus_first_available()


func _build_cards() -> void:
	for child in cards_row.get_children():
		child.queue_free()
	_buttons.clear()
	for weapon_id in WeaponCatalog.ORDER:
		var info := WeaponCatalog.get_info(weapon_id)
		var card := PanelContainer.new()
		card.name = "Card_" + weapon_id
		card.theme_type_variation = &"CardPanel"
		card.custom_minimum_size = Vector2(170, 0)
		cards_row.add_child(card)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)

		var icon := TextureRect.new()
		icon.texture = WeaponCatalog.get_icon(weapon_id)
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)

		box.add_child(_make_label(info.name, 18, Color(1.0, 0.9, 0.6)))
		var price_text := "FREE" if info.cost == 0 else "%d COINS" % info.cost
		box.add_child(_make_label(price_text, 16, Color(1.0, 0.82, 0.3)))
		box.add_child(_make_label("%d HITS / ENEMY" % info.hits, 14, Color(0.85, 0.9, 0.9)))
		box.add_child(_make_label("%d USES" % info.uses, 14, Color(0.85, 0.9, 0.9)))

		var button := Button.new()
		button.name = "Buy_" + weapon_id
		button.custom_minimum_size = Vector2(130, 0)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_buy_pressed.bind(weapon_id))
		box.add_child(button)
		_buttons[weapon_id] = {"button": button, "card": card}


func _make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh() -> void:
	coins_label.text = "YOUR COINS: %d" % Game.coins
	message_label.text = ""
	var any_affordable := false
	for weapon_id in _buttons:
		var info := WeaponCatalog.get_info(weapon_id)
		var button: Button = _buttons[weapon_id].button
		var card: PanelContainer = _buttons[weapon_id].card
		var affordable := Game.can_afford(weapon_id)
		any_affordable = any_affordable or affordable
		if not info.purchasable:
			button.text = "START ONLY"
			button.disabled = true
		elif affordable:
			button.text = "BUY"
			button.disabled = false
		else:
			button.text = "NEED %d" % (info.cost - Game.coins)
			button.disabled = true
		card.modulate = Color.WHITE if affordable else Color(0.6, 0.6, 0.65)
		var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style:
			style.border_color = AFFORDABLE_BORDER if affordable else UNAFFORDABLE_BORDER
			card.add_theme_stylebox_override("panel", style)

	if any_affordable:
		subtitle_label.text = "Choose your next weapon"
		leave_button.text = "STAY UNARMED"
	else:
		subtitle_label.text = "Not enough coins for any weapon."
		message_label.text = "You are UNARMED. Collect coins, then press B to buy a weapon."
		leave_button.text = "CONTINUE UNARMED"


func _focus_first_available() -> void:
	for weapon_id in WeaponCatalog.ORDER:
		var button: Button = _buttons[weapon_id].button
		if not button.disabled:
			button.grab_focus()
			return
	leave_button.grab_focus()


func _on_buy_pressed(weapon_id: String) -> void:
	if not Game.buy_weapon(weapon_id):
		# Guard against invalid / unaffordable picks.
		Audio.play("denied")
		message_label.text = "You can't afford that weapon."
		_refresh()
		return
	Audio.play("purchase")
	_close(weapon_id)


func _on_leave_pressed() -> void:
	_close(WeaponCatalog.UNARMED)


func _close(purchased_weapon_id: String) -> void:
	visible = false
	closed.emit(purchased_weapon_id)
