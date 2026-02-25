extends Control

func _ready() -> void:
	var summary = "Run ended. Wins: %d Depth: %d" % [RunManager.wins, RunManager.run_depth]
	%Summary.text = summary
	%RetryButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
