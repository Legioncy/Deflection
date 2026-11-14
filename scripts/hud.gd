class_name Hud
extends CanvasLayer

@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var balls_label: Label = $Margin/VBox/BallsLabel
@onready var message_label: Label = $Margin/VBox/MessageLabel


func show_state(s: GameState, level_name: String, selected: String, message: String) -> void:
	level_label.text = "Level %s" % level_name
	health_label.text = "Health: %d / %d" % [s.health, s.max_health]

	var parts: PackedStringArray = []
	for k: String in s.inventory:
		var txt := "%s x%d" % [k, s.inventory[k]]
		parts.append("[%s]" % txt if k == selected else txt)
	balls_label.text = "Balls: " + "   ".join(parts)

	message_label.text = message
