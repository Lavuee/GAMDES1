extends Node
## Audio playback (autoload "Audio").
##
## The project ships without audio files, so every sound effect and the music
## loop are synthesized at startup as simple chiptune waveforms (no external or
## copyrighted audio). To replace a sound, drop a file named after the effect
## into res://assets/audio/sfx/ (e.g. "coin.ogg" or "coin.wav"), or
## res://assets/audio/music/theme.ogg for the music — it is picked up
## automatically.

const MIX_RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_PATH_CANDIDATES := ["res://assets/audio/music/theme.ogg", "res://assets/audio/music/theme.wav"]
const PLAYER_POOL_SIZE := 12

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _music_stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_build_sound_library()


## Creates the Music and SFX buses if the bus layout is missing them.
static func ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func play(sound_name: String, pitch_variation: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(sound_name)
	if stream == null or _players.is_empty():
		return
	var player := _find_free_player()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music() -> void:
	if _music_player == null:
		return
	if _music_stream == null:
		_music_stream = _load_music()
	if _music_player.playing and _music_player.stream == _music_stream:
		return
	_music_player.stream = _music_stream
	_music_player.play()


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


func _find_free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	# All busy: recycle round-robin.
	_next_player = (_next_player + 1) % _players.size()
	return _players[_next_player]


# ---------------------------------------------------------------------------
# Sound library
# ---------------------------------------------------------------------------

func _build_sound_library() -> void:
	# Each entry: list of segments [wave, start_hz, end_hz, seconds, volume]
	var recipes := {
		"jump": [["square", 280, 620, 0.12, 0.35]],
		"coin": [["square", 988, 988, 0.06, 0.3], ["square", 1319, 1319, 0.14, 0.3]],
		"attack": [["noise", 1800, 400, 0.11, 0.35]],
		"hit": [["square", 220, 90, 0.09, 0.45], ["noise", 900, 200, 0.05, 0.3]],
		"enemy_die": [["square", 440, 110, 0.25, 0.4], ["noise", 600, 100, 0.12, 0.25]],
		"hurt": [["square", 330, 140, 0.2, 0.45], ["square", 160, 90, 0.12, 0.4]],
		"weapon_break": [["noise", 3000, 600, 0.08, 0.45], ["square", 600, 200, 0.18, 0.35], ["square", 200, 120, 0.15, 0.3]],
		"purchase": [["square", 523, 523, 0.07, 0.3], ["square", 659, 659, 0.07, 0.3], ["square", 784, 784, 0.07, 0.3], ["square", 1047, 1047, 0.18, 0.3]],
		"level_complete": [["square", 523, 523, 0.1, 0.3], ["square", 659, 659, 0.1, 0.3], ["square", 784, 784, 0.1, 0.3], ["square", 1047, 1047, 0.1, 0.3], ["triangle", 784, 784, 0.1, 0.45], ["triangle", 1047, 1047, 0.35, 0.45]],
		"game_over": [["square", 392, 392, 0.2, 0.3], ["square", 330, 330, 0.2, 0.3], ["square", 262, 262, 0.2, 0.3], ["triangle", 196, 120, 0.6, 0.5]],
		"victory": [["square", 523, 523, 0.12, 0.3], ["square", 523, 523, 0.12, 0.3], ["square", 784, 784, 0.12, 0.3], ["square", 1047, 1047, 0.3, 0.3], ["square", 880, 880, 0.12, 0.3], ["square", 1047, 1047, 0.5, 0.3]],
		"click": [["square", 900, 700, 0.05, 0.25]],
		"hover": [["triangle", 1200, 1200, 0.03, 0.2]],
		"crumble": [["noise", 500, 150, 0.25, 0.3]],
		"land": [["noise", 300, 120, 0.05, 0.15]],
		"denied": [["square", 160, 140, 0.15, 0.3]],
		# Enemy voices (GroundEnemy.voice + "_idle/_alert/_attack/_hurt/_die").
		"croc_idle": [["noise", 260, 180, 0.3, 0.16], ["square", 70, 60, 0.25, 0.1]],
		"croc_alert": [["square", 95, 70, 0.3, 0.3], ["noise", 380, 160, 0.25, 0.26]],
		"croc_attack": [["noise", 2600, 900, 0.05, 0.45], ["square", 180, 70, 0.1, 0.4]],
		"croc_hurt": [["square", 210, 120, 0.16, 0.36], ["noise", 500, 200, 0.08, 0.2]],
		"croc_die": [["square", 160, 55, 0.5, 0.36], ["noise", 300, 80, 0.25, 0.2]],
		"snake_idle": [["noise", 5200, 4200, 0.35, 0.1]],
		"snake_alert": [["noise", 6500, 4000, 0.45, 0.2]],
		"snake_attack": [["noise", 7500, 2500, 0.1, 0.3], ["square", 520, 220, 0.07, 0.24]],
		"snake_hurt": [["noise", 5500, 2000, 0.12, 0.26], ["square", 640, 320, 0.08, 0.2]],
		"snake_die": [["noise", 5000, 700, 0.55, 0.22], ["square", 320, 80, 0.3, 0.18]],
		"bird_caw": [["square", 900, 700, 0.09, 0.18], ["square", 820, 620, 0.12, 0.18]],
		"bird_screech": [["square", 1300, 2300, 0.08, 0.22], ["square", 2300, 1000, 0.2, 0.22]],
	}
	for sound_name in recipes:
		var override := _load_override(sound_name)
		_sfx[sound_name] = override if override else _synthesize(recipes[sound_name])


func _load_override(sound_name: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s%s.%s" % [SFX_DIR, sound_name, ext]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				return stream
	return null


func _load_music() -> AudioStream:
	for path in MUSIC_PATH_CANDIDATES:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				return stream
	return _synthesize_music()


## Renders a list of segments into a 16-bit mono AudioStreamWAV.
func _synthesize(segments: Array) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for seg in segments:
		_render_segment(samples, seg[0], float(seg[1]), float(seg[2]), float(seg[3]), float(seg[4]))
	return _to_wav(samples, false)


func _render_segment(out: PackedFloat32Array, wave: String, start_hz: float, end_hz: float, seconds: float, volume: float) -> void:
	var count := int(seconds * MIX_RATE)
	var phase := 0.0
	var noise_value := 0.0
	var noise_counter := 0.0
	for i in count:
		var t := float(i) / maxf(count - 1, 1.0)
		var hz := lerpf(start_hz, end_hz, t)
		phase = fmod(phase + hz / MIX_RATE, 1.0)
		var value := 0.0
		match wave:
			"square":
				value = 1.0 if phase < 0.5 else -1.0
			"triangle":
				value = 4.0 * absf(phase - 0.5) - 1.0
			"noise":
				# Sample-and-hold noise; hz controls how "bright" it sounds.
				noise_counter += hz / MIX_RATE
				if noise_counter >= 1.0:
					noise_counter = 0.0
					noise_value = randf_range(-1.0, 1.0)
				value = noise_value
			_:
				value = sin(phase * TAU)
		# Short attack + linear release envelope avoids clicks.
		var envelope := minf(1.0, i / (0.004 * MIX_RATE)) * (1.0 - t * 0.85)
		out.append(value * volume * envelope)


func _synthesize_music() -> AudioStreamWAV:
	# Simple looping adventure groove: Am - F - C - G, 2 seconds per chord.
	var bpm := 120.0
	var beat := 60.0 / bpm
	var chords := [
		[110.0, [220.0, 261.63, 329.63]],
		[87.31, [174.61, 220.0, 261.63]],
		[130.81, [261.63, 329.63, 392.0]],
		[98.0, [196.0, 246.94, 293.66]],
	]
	var melody := [659.25, 0, 523.25, 587.33, 659.25, 0, 783.99, 659.25,
		698.46, 0, 659.25, 587.33, 523.25, 0, 440.0, 0,
		523.25, 0, 587.33, 659.25, 783.99, 0, 659.25, 523.25,
		587.33, 0, 493.88, 0, 392.0, 440.0, 493.88, 0]
	var total := int(beat * 4 * chords.size() * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total)
	var eighth := beat / 2.0
	for i in total:
		var time := float(i) / MIX_RATE
		var chord_index := int(time / (beat * 4)) % chords.size()
		var chord: Array = chords[chord_index]
		var step := int(time / eighth)
		var step_t := fmod(time, eighth) / eighth
		# Bass: triangle on eighth notes, octave bounce.
		var bass_hz: float = chord[0] * (2.0 if step % 2 == 1 else 1.0)
		var bass := (4.0 * absf(fmod(time * bass_hz, 1.0) - 0.5) - 1.0) * 0.32 * (1.0 - step_t * 0.6)
		# Arpeggio: quiet square cycling through the chord.
		var arp_hz: float = chord[1][step % 3] * 2.0
		var arp := (1.0 if fmod(time * arp_hz, 1.0) < 0.25 else -1.0) * 0.05 * (1.0 - step_t)
		# Lead melody.
		var lead := 0.0
		var note: float = melody[step % melody.size()]
		if note > 0.0:
			lead = (1.0 if fmod(time * note, 1.0) < 0.5 else -1.0) * 0.07 * (1.0 - step_t * 0.7)
		samples[i] = bass + arp + lead
	return _to_wav(samples, true)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
