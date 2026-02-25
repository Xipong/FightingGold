extends Control

func _ready() -> void:
	%StartButton.pressed.connect(_on_start)
	%QuitButton.pressed.connect(func(): get_tree().quit())

func _on_start() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/PreparationScreen.tscn")
