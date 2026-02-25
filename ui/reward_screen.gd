extends Control

var current_options: Array = []

func _ready() -> void:
	RunManager.reward_requested.connect(_on_reward_requested)
	_on_reward_requested(_fallback_options())

func _fallback_options() -> Array:
	var options: Array = []
	while options.size() < 3:
		var u: Dictionary = RunManager.upgrades[randi() % RunManager.upgrades.size()]
		if not options.any(func(x): return x["id"] == u["id"]):
			options.append(u)
	return options

func _on_reward_requested(options: Array) -> void:
	current_options = options
	for i in range(3):
		var button: Button = get_node("Upgrade%d" % (i + 1))
		var up: Dictionary = options[i]
		button.text = "%s\n%s" % [up.get("name", "Upgrade"), up.get("desc", "")]
		button.pressed.connect(_pick.bind(i), CONNECT_ONE_SHOT)

func _pick(index: int) -> void:
	RunManager.apply_upgrade(current_options[index])
	get_tree().change_scene_to_file("res://scenes/PreparationScreen.tscn")
