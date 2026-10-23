extends CanvasLayer

# On-screen crosshair, interaction prompt and short messages.

@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message

var _message_time_left := 0.0


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_message(text: String, seconds: float = 4.0) -> void:
	message_label.text = text
	_message_time_left = seconds
