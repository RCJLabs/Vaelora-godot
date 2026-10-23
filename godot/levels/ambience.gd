extends Node

# Background sound for a level. Outdoors, a day loop and a night loop crossfade
# with the time of day (WorldClock); indoors, one room-tone loop plays.
# Add one to each level. The loops are in assets/sfx/ (placeholders for now).

@export var indoor := false
@export var indoor_sound := "ambience_cellar"
@export var volume_db := -12.0
## Seconds for a full crossfade, so a jump in time (sleeping) doesn't snap.
@export var fade_time := 3.0

var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _mix := -1.0   # 0 = night, 1 = day


func _ready() -> void:
	if indoor:
		_day = _player(indoor_sound)
		return
	_day = _player("ambience_day")
	_night = _player("ambience_night")


func _process(delta: float) -> void:
	if indoor or _day == null or _night == null:
		return
	var target := clampf(WorldClock.daylight() * 1.5, 0.0, 1.0)   # birds from early dawn
	_mix = target if _mix < 0.0 else move_toward(_mix, target, delta / fade_time)
	_day.volume_db = volume_db + linear_to_db(maxf(_mix, 0.001))
	_night.volume_db = volume_db + linear_to_db(maxf(1.0 - _mix, 0.001))


func _player(sound: String) -> AudioStreamPlayer:
	var stream := Sfx.loop(sound)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play(randf() * stream.get_length())   # start somewhere random in the loop
	return player
