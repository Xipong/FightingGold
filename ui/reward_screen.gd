extends Control

var current_options: Array = []

func _ready() -> void:
	if not RunManager.reward_requested.is_connected(_on_reward_requested):
		RunManager.reward_requested.connect(_on_reward_requested)
	_on_reward_requested(RunManager._roll_reward_options(3))

func _on_reward_requested(options: Array) -> void:
	current_options = options.duplicate(true)
	if current_options.is_empty():
		push_warning("RewardScreen: received empty reward options, regenerating fallback set.")
		current_options = RunManager._roll_reward_options(3)
	for i in range(3):
		var button: Button = get_node("Upgrade%d" % (i + 1))
		var safe_index := min(i, current_options.size() - 1)
		var up: Dictionary = current_options[safe_index]
		button.text = "%s\n%s" % [up.get("name", "Upgrade"), up.get("desc", "")]
		var action := Callable(self, "_pick").bind(safe_index)
		if button.pressed.is_connected(action):
			button.pressed.disconnect(action)
		button.pressed.connect(action, CONNECT_ONE_SHOT)

func _pick(index: int) -> void:
	if index < 0 or index >= current_options.size():
		push_warning("RewardScreen: invalid reward index %d" % index)
		return
	RunManager.apply_upgrade(current_options[index])
	get_tree().change_scene_to_file("res://scenes/PreparationScreen.tscn")
