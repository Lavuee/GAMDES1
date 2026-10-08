extends Control
## End-of-run results, used for both GAME OVER and ABANTE COMPLETE!

@onready var title_label: Label = %ResultTitle
@onready var subtitle_label: Label = %ResultSubtitle
@onready var score_value: Label = %ScoreValue
@onready var coins_value: Label = %CoinsValue
@onready var time_value: Label = %TimeValue
@onready var level_value: Label = %LevelValue
@onready var primary_button: Button = %PrimaryButton
@onready var menu_button: Button = %MenuButton
@onready var panel: Control = %ResultPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	primary_button.pressed.connect(Game.start_new_run)
	menu_button.pressed.connect(Game.go_to_main_menu)
	UIFx.wire_buttons(self)


func show_game_over() -> void:
	title_label.text = "GAME OVER"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	subtitle_label.text = "Your hearts ran out."
	primary_button.text = "RESTART"
	_show()


func show_victory() -> void:
	title_label.text = "ABANTE COMPLETE!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	subtitle_label.text = "You conquered all three levels!"
	primary_button.text = "PLAY AGAIN"
	_show()


func _show() -> void:
	score_value.text = str(Game.score)
	coins_value.text = str(Game.total_coins_collected)
	time_value.text = Game.format_time(Game.time_survived)
	level_value.text = "%d / %d" % [Game.highest_level, Game.LEVEL_SCENES.size()]
	UIFx.fade_in(self, 0.3)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	primary_button.grab_focus()
