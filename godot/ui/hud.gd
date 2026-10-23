extends CanvasLayer

# On-screen crosshair, interaction prompt, short messages and the
# Magicka / Health / Stamina bars (left / centre / right, like Skyrim).

@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message
@onready var health_bar: ProgressBar = $Bars/Health
@onready var stamina_bar: ProgressBar = $Bars/Stamina
@onready var magicka_bar: ProgressBar = $Bars/Magicka

var _message_time_left := 0.0
var _stats: Stats


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""


## Connects the bars to a Stats node so they update by themselves.
func track_stats(stats: Stats) -> void:
	_stats = stats
	stats.changed.connect(_refresh_bars)
	_refresh_bars()


func _refresh_bars() -> void:
	health_bar.max_value = _stats.max_health
	health_bar.value = _stats.health
	stamina_bar.max_value = _stats.max_stamina
	stamina_bar.value = _stats.stamina
	magicka_bar.max_value = _stats.max_magicka
	magicka_bar.value = _stats.magicka


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_message(text: String, seconds: float = 4.0) -> void:
	message_label.text = text
	_message_time_left = seconds
