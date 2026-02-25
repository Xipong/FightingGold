extends RefCounted
class_name PlayerAI

func pick_action(player: Fighter, enemy: Fighter, rules: Array, combos: Dictionary, moves: Dictionary, distance: float) -> Dictionary:
	for rule in rules:
		if not rule.get("enabled", true):
			continue
		var action = _rule_action(rule, player, enemy, distance)
		if action != "":
			return _build_action(action, combos, moves)
	return _build_action("default_combo", combos, moves)

func _rule_action(rule: Dictionary, player: Fighter, enemy: Fighter, distance: float) -> String:
	match rule.get("id", ""):
		"low_stamina":
			if player.stamina < float(rule.get("threshold", 30.0)):
				return "recover"
		"enemy_recovery":
			if enemy.state == Fighter.State.RECOVERY or enemy.just_whiffed_punishable:
				return "punish_combo"
		"enemy_telegraph":
			if enemy.telegraphing:
				return "dodge_or_block"
		"enemy_low_guard":
			if enemy.guard < float(rule.get("threshold", 20.0)):
				return "guard_break_combo"
		"gap_close":
			if distance > float(rule.get("threshold", 140.0)):
				return "gap_closer"
		"low_hp":
			if player.hp / player.max_hp * 100.0 < float(rule.get("threshold", 40.0)):
				return "defensive"
		"default":
			return "default_combo"
	return ""

func _build_action(action: String, combos: Dictionary, moves: Dictionary) -> Dictionary:
	match action:
		"recover":
			return {"type":"wait", "label":"Recover"}
		"dodge_or_block":
			return {"type":"reaction", "label":"Defensive React"}
		"defensive":
			return {"type":"block", "label":"Safe Guard"}
		"gap_closer":
			return {"type":"combo", "combo":"default", "prefer_tag":"gap_closer"}
		"punish_combo":
			return {"type":"combo", "combo":"punish"}
		"guard_break_combo":
			return {"type":"combo", "combo":"guard_break"}
		_:
			return {"type":"combo", "combo":"default"}
