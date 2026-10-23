extends CanvasLayer

# On-screen crosshair, interaction prompt, short messages and the
# Magicka / Health / Stamina bars (left / centre / right, like Skyrim).

@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message
@onready var health_bar: ProgressBar = $Bars/Health
@onready var stamina_bar: ProgressBar = $Bars/Stamina
@onready var magicka_bar: ProgressBar = $Bars/Magicka
@onready var crosshair: Label = $Crosshair
@onready var damage_flash: ColorRect = $DamageFlash
@onready var enemy_bar: ProgressBar = $EnemyBar
@onready var notices: VBoxContainer = $Notices

var _message_time_left := 0.0
var _stats: Stats
var _enemy_stats: Stats
var _enemy_bar_time_left := 0.0


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""
	if _enemy_bar_time_left > 0.0:
		_enemy_bar_time_left -= delta
		if is_instance_valid(_enemy_stats):
			enemy_bar.max_value = _enemy_stats.max_health
			enemy_bar.value = _enemy_stats.health
		enemy_bar.visible = _enemy_bar_time_left > 0.0


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


## Red edge flash when the player is hurt.
func flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(damage_flash, "color:a", 0.35, 0.05)
	tween.tween_property(damage_flash, "color:a", 0.0, 0.4)


## Crosshair turns red briefly when a swing connects.
func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(crosshair, "modulate", Color(1, 0.2, 0.2), 0.03)
	tween.tween_property(crosshair, "modulate", Color.WHITE, 0.25)


## Shows the health of whatever you just hit, at the top of the screen.
func show_enemy_health(stats: Stats) -> void:
	_enemy_stats = stats
	_enemy_bar_time_left = 4.0
	enemy_bar.max_value = stats.max_health
	enemy_bar.value = stats.health
	enemy_bar.visible = true


## Short top-left notice that fades out by itself, e.g. a skill increase.
func notify(text: String) -> void:
	while notices.get_child_count() >= 5:   # keep the newest few
		var oldest := notices.get_child(0)
		notices.remove_child(oldest)
		oldest.queue_free()
	var label := Label.new()
	label.text = text
	label.label_settings = prompt_label.label_settings
	notices.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
