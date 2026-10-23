extends Node

# Plays short sound effects. Autoloaded as "Sfx".
#   Sfx.play("block")                       at the listener (UI, the player's own sounds)
#   Sfx.play_at("wolf_growl", position)     in the world: quieter with distance
#
# Each name is a file in res://assets/sfx/ (name.wav or name.ogg). Missing files
# are skipped silently, so code can ask for sounds that don't exist yet.
# The current .wav files are synthesised placeholders (tools/make_placeholder_sfx.py):
# drop a real recording in with the same name to replace one.

const FOLDER := "res://assets/sfx/"
## Every play is pitched up or down by up to this much, so repeats don't sound identical.
const PITCH_VARIATION := 0.08
const VOICES := 8   # how many non-positional sounds can play at once

var _cache: Dictionary = {}    # name -> AudioStream (or null if missing)
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menu clicks while paused, later
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, volume_db: float = 0.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	player.play()


func play_at(sound: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream := _stream(sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 4.0
	player.max_distance = 40.0
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = null
		for extension in [".wav", ".ogg"]:
			if ResourceLoader.exists(FOLDER + sound + extension):
				_cache[sound] = load(FOLDER + sound + extension)
				break
	return _cache[sound]
