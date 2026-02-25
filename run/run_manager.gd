extends Node
class_name RunManagerNode

signal run_started
signal fight_requested(enemy_data: Dictionary)
signal reward_requested(options: Array)
signal run_ended(summary: Dictionary)

const BASE_PLAYER_STATS := {
	"max_hp": 140.0,
	"hp": 140.0,
	"max_stamina": 100.0,
	"stamina": 100.0,
	"stamina_regen": 13.0,
	"max_guard": 70.0,
	"guard": 70.0,
	"guard_regen": 5.5,
	"poise": 45.0,
	"damage_multiplier": 1.0,
	"punish_bonus": 1.0,
	"recovery_reduction_light": 0,
	"recovery_reduction_heavy": 0,
	"heavy_armor_chance": 0.0,
	"light_damage_bonus": 0.0,
	"heavy_damage_bonus": 0.0
}

var player_stats: Dictionary = BASE_PLAYER_STATS.duplicate(true)
var run_depth := 0
var wins := 0
var available_moves: Array = []
var selected_combos := {
	"default": ["jab", "step_slash", "gut_punch", "rising_kick"],
	"punish": ["shoulder_bash", "crusher", "sunder", "execute"],
	"guard_break": ["jab", "hook", "anvil_breaker", "shield_splitter"]
}
var behavior_rules: Array = []

var all_moves: Dictionary = {}
var enemies: Array = []
var upgrades: Array = []

func _ready() -> void:
	randomize()
	load_data()
	reset_run()

func load_data() -> void:
	all_moves = _load_json_dict("res://data/json/moves.json")
	enemies = _load_json_array("res://data/json/enemies.json")
	upgrades = _load_json_array("res://data/json/upgrades.json")
	if all_moves.is_empty():
		push_error("RunManager: moves.json is empty or unreadable. Using fallback move set.")
		all_moves = {
			"jab": {"name":"Jab", "damage":8.0, "range":75.0, "stamina_cost":10.0, "startup_frames":6, "active_frames":3, "recovery_frames":8, "tags":["light"]}
		}
	if enemies.is_empty():
		push_warning("RunManager: enemies.json is empty or unreadable. Using training dummy fallback.")
		enemies = [{
			"id": "training_dummy",
			"name": "Training Dummy",
			"style": "bruiser",
			"move_pool": ["jab"],
			"stats": {"max_hp": 120.0, "max_stamina": 80.0, "max_guard": 50.0, "poise": 30.0}
		}]
	if upgrades.is_empty():
		push_warning("RunManager: upgrades.json is empty or unreadable. Rewards fallback will be used.")
	available_moves = all_moves.keys()
	behavior_rules = [
		{"id":"low_stamina", "enabled":true, "threshold":35.0, "action":"recover"},
		{"id":"enemy_recovery", "enabled":true, "action":"punish_combo"},
		{"id":"enemy_telegraph", "enabled":true, "action":"dodge_or_block"},
		{"id":"enemy_low_guard", "enabled":true, "threshold":25.0, "action":"guard_break_combo"},
		{"id":"gap_close", "enabled":true, "threshold":160.0, "action":"gap_closer"},
		{"id":"low_hp", "enabled":true, "threshold":40.0, "action":"defensive"},
		{"id":"default", "enabled":true, "action":"default_combo"}
	]

func reset_run() -> void:
	run_depth = 0
	wins = 0
	player_stats = BASE_PLAYER_STATS.duplicate(true)
	run_started.emit()

func start_next_fight() -> void:
	if enemies.is_empty():
		push_error("RunManager.start_next_fight: no enemies available.")
		return
	run_depth += 1
	var enemy_index := randi() % enemies.size()
	var enemy_data: Dictionary = enemies[enemy_index].duplicate(true)
	enemy_data["scale"] = 1.0 + float(run_depth - 1) * 0.12
	fight_requested.emit(enemy_data)

func on_fight_finished(victory: bool) -> void:
	if victory:
		wins += 1
		var options: Array = _roll_reward_options(3)
		reward_requested.emit(options)
	else:
		run_ended.emit({"wins": wins, "depth": run_depth})

func _roll_reward_options(count: int) -> Array:
	if upgrades.is_empty():
		return [
			{"id": "fallback_damage", "name": "Sharpen", "desc": "+8% damage", "effect": "damage_tag", "value": 0.08},
			{"id": "fallback_guard", "name": "Guard Mesh", "desc": "+8 max guard", "effect": "guard_meter", "value": 8.0},
			{"id": "fallback_regen", "name": "Breathing", "desc": "+1 stamina regen", "effect": "stamina_regen", "value": 1.0}
		]
	var pool: Array = upgrades.duplicate()
	pool.shuffle()
	var options: Array = []
	for up in pool:
		if not (up is Dictionary):
			continue
		if not up.has("id"):
			continue
		options.append(up)
		if options.size() >= count:
			break
	if options.is_empty():
		push_warning("RunManager._roll_reward_options: upgrade pool contains no valid entries.")
		return [{"id": "fallback_damage", "name": "Sharpen", "desc": "+8% damage", "effect": "damage_tag", "value": 0.08}]
	while options.size() < count:
		options.append(options[options.size() % max(1, options.size())].duplicate(true))
	return options

func apply_upgrade(upgrade: Dictionary) -> void:
	match upgrade.get("effect", ""):
		"damage_tag":
			var bonus := float(upgrade.get("value", 0.08))
			player_stats["light_damage_bonus"] = float(player_stats.get("light_damage_bonus", 0.0)) + bonus
			player_stats["heavy_damage_bonus"] = float(player_stats.get("heavy_damage_bonus", 0.0)) + bonus
		"stamina_regen":
			player_stats["stamina_regen"] = float(player_stats.get("stamina_regen", 10.0)) + float(upgrade.get("value", 1.0))
		"guard_meter":
			player_stats["max_guard"] = float(player_stats.get("max_guard", 50.0)) + float(upgrade.get("value", 8.0))
			player_stats["guard"] = player_stats["max_guard"]
		"poise":
			player_stats["poise"] = float(player_stats.get("poise", 30.0)) + float(upgrade.get("value", 6.0))
		"stunned_damage":
			player_stats["punish_bonus"] = float(player_stats.get("punish_bonus", 1.0)) + float(upgrade.get("value", 0.2))
		"recovery_reduction":
			if upgrade.get("tag", "light") == "light":
				player_stats["recovery_reduction_light"] = int(player_stats.get("recovery_reduction_light", 0)) + int(upgrade.get("value", 2))
			else:
				player_stats["recovery_reduction_heavy"] = int(player_stats.get("recovery_reduction_heavy", 0)) + int(upgrade.get("value", 3))
		"heavy_armor":
			player_stats["heavy_armor_chance"] = float(player_stats.get("heavy_armor_chance", 0.0)) + float(upgrade.get("value", 0.08))
		"unlock_move":
			var m := String(upgrade.get("move_id", ""))
			if m != "" and not available_moves.has(m):
				available_moves.append(m)

func _load_json_dict(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func _load_json_array(path: String) -> Array:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Array else []
