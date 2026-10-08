class_name Level
extends Node2D
## Base script for every level scene.
##
## Builds invisible side walls, sets camera limits, counts ground enemies
## (crocodiles + snakes; birds are not counted), drops a coin when an enemy
## is defeated and reports progress to Game.

const COIN_SCENE := preload("res://scenes/world/coin.tscn")
const WORLD_LAYER := 1

@export var level_number := 1
@export var level_title := "The Jungle Path"
@export var level_width := 3200.0
## Y of the walkable ground surface.
@export var ground_y := 480.0
@export var view_top := 0.0
@export var view_bottom := 540.0

@onready var player: Player = $Player
@onready var enemies_root: Node = $Enemies
@onready var pickups_root: Node = $Pickups


func _ready() -> void:
	add_to_group("level")
	_build_side_walls()
	player.setup_bounds(0.0, level_width, view_top, view_bottom)

	var ground_enemies := 0
	for enemy in enemies_root.get_children():
		if enemy is GroundEnemy:
			ground_enemies += 1
			enemy.defeated.connect(_on_enemy_defeated)
	if not Game.score_popup.is_connected(_on_score_popup):
		Game.score_popup.connect(_on_score_popup)
	Game.begin_level(level_number, ground_enemies)
	if ground_enemies == 0:
		push_warning("Level %d has no ground enemies; it will clear immediately." % level_number)
		Game.on_ground_enemy_defeated.call_deferred()


func _build_side_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "SideWalls"
	walls.collision_layer = 0
	walls.set_collision_layer_value(WORLD_LAYER, true)
	walls.collision_mask = 0
	add_child(walls)
	for x in [-20.0, level_width + 20.0]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40.0, 2000.0)
		shape.shape = rect
		shape.position = Vector2(x, ground_y - 900.0)
		walls.add_child(shape)


func _on_enemy_defeated(enemy: GroundEnemy) -> void:
	var coin := COIN_SCENE.instantiate() as Coin
	coin.score_value = 1
	pickups_root.add_child.call_deferred(coin)
	var start := enemy.global_position + Vector2(0, -24)
	var land_y := ground_y - 16.0
	coin.ready.connect(func() -> void: coin.pop_from(start, land_y), CONNECT_ONE_SHOT)
	Game.on_ground_enemy_defeated()


func _on_score_popup(amount: int, world_position: Vector2) -> void:
	if world_position != Vector2.ZERO:
		FloatingText.spawn(pickups_root, "+%d" % amount, world_position)
