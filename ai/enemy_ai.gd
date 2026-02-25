extends RefCounted
class_name EnemyAI

func pick_move(enemy: Fighter, player: Fighter, enemy_data: Dictionary, moves: Dictionary, distance: float) -> String:
	if enemy.stamina < 20.0:
		return ""
	var style = String(enemy_data.get("style", "bruiser"))
	var pool: Array = enemy_data.get("move_pool", [])
	if pool.is_empty():
		return ""
	if player.state == Fighter.State.RECOVERY and enemy.stamina > 30.0 and enemy_data.has("signature"):
		return String(enemy_data.get("signature"))
	if style == "bruiser" and distance > 130:
		for m in pool:
			if moves.get(m, {}).get("tags", []).has("gap_closer"):
				return m
	if style == "duelist" and player.state in [Fighter.State.STARTUP, Fighter.State.ACTIVE]:
		for m in pool:
			if moves.get(m, {}).get("tags", []).has("punish"):
				return m
	if style == "tank" and player.guard < 25.0:
		for m in pool:
			if moves.get(m, {}).get("guard_damage", 0) > 18:
				return m
	return String(pool[randi() % pool.size()])
