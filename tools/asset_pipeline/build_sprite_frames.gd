extends SceneTree
## Builds the SpriteFrames resources for the player (one per weapon) and
## the enemies from their spritesheets. Re-run after editing a sheet or the tables below:
##   godot --headless --path . --script <abs path>/tools/asset_pipeline/build_sprite_frames.gd
##
## Each row of a sheet is one animation; frames are read left to right.
## Entry: [animation, row, frame_count, fps, loop]

const OUT_DIR := "res://assets/sprites/abante/frames/"

## One player sheet per held weapon (8x8 grid, same rows), so the weapon is
## always drawn in the hero's hands. Saved as player_<id>_frames. The cell
## size is read from each sheet (the battle axe sheet has taller 112x98 cells
## for its low swing); frames are drawn centred, so the feet still line up.
const PLAYER_WEAPONS := ["unarmed", "dagger", "short_sword", "battle_axe", "enchanted_blade"]
const PLAYER_ANIMS := [
	["idle", 0, 8, 8.0, true],
	["walk", 1, 8, 10.0, true],
	["run", 2, 8, 13.0, true],
	["jump", 3, 4, 12.0, false],
	["fall", 4, 4, 8.0, true],
	# No landing row: hold the crouched first jump frame briefly.
	["land", 3, 1, 6.0, false],
	# Plays a little past Player.attack_duration; the player keeps the
	# attack animation until it finishes.
	["attack", 5, 8, 24.0, false],
	["hurt", 6, 4, 16.0, false],
	["death", 7, 6, 9.0, false],
]

const SHEETS := {
	# Enemy sheets: 8 columns, rows = idle, move, attack, hurt, death.
	# They have no separate chase row, so "chase" replays the move row faster.
	"crocodile": {
		"texture": "res://assets/sprites/abante/crocodile_spritesheet.png",
		"cell": Vector2i(144, 80),
		"default": "idle",
		"anims": [
			["idle", 0, 8, 7.0, true],
			["walk", 1, 8, 10.0, true],
			["chase", 1, 8, 15.0, true],
			["attack", 2, 8, 14.0, false],
			["hurt", 3, 4, 16.0, false],
			["death", 4, 6, 9.0, false],
		],
	},
	"snake": {
		"texture": "res://assets/sprites/abante/snake_spritesheet.png",
		"cell": Vector2i(144, 80),
		"default": "idle",
		"anims": [
			["idle", 0, 8, 7.0, true],
			["walk", 1, 8, 10.0, true],
			["chase", 1, 8, 15.0, true],
			["attack", 2, 8, 18.0, false],
			["hurt", 3, 4, 16.0, false],
			["death", 4, 6, 9.0, false],
		],
	},
	# Row 0 is an upright, wings-folded idle; the flying hazard uses fly and
	# attack (hurt / death exist for completeness: birds cannot be hit).
	"bird": {
		"texture": "res://assets/sprites/abante/bird_spritesheet.png",
		"cell": Vector2i(96, 96),
		"default": "fly",
		"anims": [
			["idle", 0, 8, 7.0, true],
			["fly", 1, 8, 12.0, true],
			["attack", 2, 8, 12.0, false],
			["hurt", 3, 4, 12.0, false],
			["death", 4, 6, 10.0, false],
		],
	},
}


func _init() -> void:
	var sheets := SHEETS.duplicate()
	for weapon: String in PLAYER_WEAPONS:
		sheets["player_" + weapon] = {
			"texture": "res://assets/sprites/abante/player/player_%s.png" % weapon,
			"cell": Vector2i.ZERO, # derived from the texture: 8 x 8 grid
			"default": "idle",
			"anims": PLAYER_ANIMS,
		}
	for key in sheets:
		var info: Dictionary = sheets[key]
		var texture := load(info.texture) as Texture2D
		if texture == null:
			push_error("Missing texture %s (import the project first)" % info.texture)
			quit(1)
			return
		var cell: Vector2i = info.cell
		if cell == Vector2i.ZERO:
			cell = Vector2i(texture.get_width() / 8, texture.get_height() / 8)
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for anim: Array in info.anims:
			var anim_name: String = anim[0]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, anim[3])
			frames.set_animation_loop(anim_name, anim[4])
			for i in int(anim[2]):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(i * cell.x, int(anim[1]) * cell.y, cell.x, cell.y)
				frames.add_frame(anim_name, atlas)
		var path: String = OUT_DIR + str(key) + "_frames.tres"
		var err := ResourceSaver.save(frames, path)
		print(path, " -> ", error_string(err), "  ", frames.get_animation_names())
	quit()
